import FirebaseAuth
import SwiftData
import SwiftUI

struct WriteView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var syncCoordinator: WritingRecordSyncCoordinator
    @EnvironmentObject private var writingPlanSyncCoordinator: WritingPlanSyncCoordinator
    @EnvironmentObject private var gardenActivityStore: GardenActivityStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let service = BibleDataService.shared
    private let sourceType: WritingSourceType
    private let showsFullScreenCloseButton: Bool

    @State private var currentVerse: VersePayload?
    @State private var writingContext: WritingContext
    @State private var userText = ""
    @State private var isSaving = false
    @State private var flowMessage: String?
    @State private var lastSavedVerseID: String?
    @State private var typingAnalysis: TypingAnalysis = .empty

    init(verse: BibleVerse?, sourceType: WritingSourceType = .direct, showsFullScreenCloseButton: Bool = false) {
        _currentVerse = State(initialValue: verse.map { VersePayload(id: $0.id, book: $0.book, chapter: $0.chapter, verse: $0.verse, text: $0.text) })
        _writingContext = State(initialValue: .bible)
        self.sourceType = sourceType
        self.showsFullScreenCloseButton = showsFullScreenCloseButton
    }

    init(localVerse: LocalBibleVerse, sourceType: WritingSourceType = .direct, writingContext: WritingContext = .bible, showsFullScreenCloseButton: Bool = false) {
        _currentVerse = State(initialValue: VersePayload(
            id: "local-\(localVerse.id)",
            book: localVerse.book,
            chapter: localVerse.chapter,
            verse: localVerse.verse,
            text: localVerse.text
        ))
        _writingContext = State(initialValue: writingContext)
        self.sourceType = sourceType
        self.showsFullScreenCloseButton = showsFullScreenCloseButton
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                verseSection
                inputSection
                actionButtons
            }
            .padding(20)
        }
        .navigationTitle("필사하기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsFullScreenCloseButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                        .accessibilityLabel("필사 화면 닫기")
                }
            }
        }
        .background(GardenTheme.background)
        .onAppear {
            refreshTypingAnalysis()
        }
        .onChange(of: userText) { _, _ in
            refreshTypingAnalysis()
        }
        .onChange(of: currentVerse?.id) { _, _ in
            refreshTypingAnalysis()
        }
    }

    private var verseSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 18) {
                if let currentVerse {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(currentVerse.book) \(currentVerse.chapter):\(currentVerse.verse)")
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundStyle(Color(hex: 0x7C4A45))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color(hex: 0xF7EFEE))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(Color(hex: 0x8E5A55, opacity: 0.08), lineWidth: 0.8)
                            }

                        Rectangle()
                            .fill(Color(hex: 0x8E5A55, opacity: 0.14))
                            .frame(width: 44, height: 0.8)
                            .padding(.leading, 2)
                    }

                    Text(currentVerse.text)
                        .font(.system(size: 24, weight: .regular, design: .serif))
                        .foregroundStyle(AppColors.primaryText)
                        .lineSpacing(10)
                        .frame(maxWidth: 520, alignment: .leading)

                    Text("천천히 따라 써보세요")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppColors.subtleText)
                } else {
                    Text("표시할 구절이 없습니다.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var inputSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("말씀 따라 쓰기")
                        .font(.system(size: 17, weight: .medium, design: .default))
                        .foregroundStyle(AppColors.primaryText)

                    Text("한 글자씩 차분히 따라 적어보세요.")
                        .font(.footnote)
                        .foregroundStyle(AppColors.secondaryText)
                }

                if let targetText = currentVerse?.text {
                    GuidedTypingTextView(targetText: targetText, inputText: $userText, analysis: typingAnalysis)
                        .id(currentVerse?.id)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .center) {
                            Text("진행률")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppColors.secondaryText)
                            Spacer()
                            Text("\(Int(typingAnalysis.progress * 100))%")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(typingAnalysis.progress == 1 ? GardenTheme.primary : AppColors.secondaryText)
                        }

                        ProgressView(value: typingAnalysis.progress)
                            .tint(typingAnalysis.progress == 1 ? GardenTheme.primary : GardenTheme.secondary)
                            .scaleEffect(x: 1, y: 0.86, anchor: .center)

                        if typingAnalysis.hasWhitespaceMismatch && !userText.isEmpty {
                            Text("띄어쓰기를 다시 확인해보세요.")
                                .font(.footnote)
                                .foregroundStyle(AppColors.secondaryText)
                        } else if typingAnalysis.hasWrongCharacter && !userText.isEmpty {
                            Text("천천히 다시 입력해보세요.")
                                .font(.footnote)
                                .foregroundStyle(AppColors.secondaryText)
                        } else if typingAnalysis.isComplete {
                            Text("필사가 완료되었습니다.")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(GardenTheme.primary)
                        } else {
                            Text("정확히 같은 순서와 띄어쓰기로 입력하면 완료됩니다.")
                                .font(.footnote)
                                .foregroundStyle(AppColors.secondaryText)
                        }

                        if let flowMessage {
                            Text(flowMessage)
                                .font(.footnote)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                    }
                }
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            GardenPrimaryButton(title: "완료", icon: "checkmark.circle.fill", disabled: !canSave || currentVerse == nil || isSaving) {
                Task { await saveAndDismiss() }
            }
            .disabled(!canSave || currentVerse == nil || isSaving)
            .shadow(color: GardenTheme.primary.opacity(0.08), radius: 8, y: 4)

            Button {
                Task { await saveAndMoveToNextVerse() }
            } label: {
                let isReadyForNext = canMoveToNextVerse && !isSaving
                HStack {
                    Image(systemName: isReadyForNext ? "arrow.right.circle.fill" : "arrow.right.circle")
                        .font(.title3.weight(.bold))
                    Text("다음 구절")
                        .font(.headline.weight(isReadyForNext ? .bold : .medium))
                    Spacer()
                }
                .foregroundStyle(isReadyForNext ? GardenTheme.primary : AppColors.secondaryText)
                .padding(.vertical, 15)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isReadyForNext ? GardenTheme.softFill : AppColors.cardTint.opacity(0.58))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isReadyForNext ? GardenTheme.primary.opacity(0.38) : AppColors.border.opacity(0.62), lineWidth: isReadyForNext ? 1.4 : 1)
                }
            }
            .buttonStyle(GardenAccentButtonStyle())
            .disabled(!canMoveToNextVerse || currentVerse == nil || isSaving)
            .shadow(color: GardenTheme.primary.opacity(0.05), radius: 6, y: 3)
        }
    }

    private var canSave: Bool {
        typingAnalysis.isComplete && !isSaving && currentVerse?.id != lastSavedVerseID
    }

    private var canMoveToNextVerse: Bool {
        canSave && nextVersePreview() != nil
    }

    private var targetText: String {
        currentVerse?.text ?? ""
    }

    private func buildRecord(from verse: VersePayload, planIdentity: PlanWritingRecordIdentity?) -> WritingRecord {
        let now = Date()
        return WritingRecord(
            ownerUserId: authViewModel.currentUser?.uid ?? "",
            date: Calendar.current.startOfDay(for: now),
            verseId: verse.id,
            book: verse.book,
            chapter: verse.chapter,
            verse: verse.verse,
            originalText: verse.text,
            userText: userText,
            completedAt: now,
            sourceType: sourceType.rawValue,
            planId: planIdentity?.planId.uuidString,
            assignmentId: planIdentity?.assignmentId.uuidString,
            planDayIndex: planIdentity?.planDayIndex
        )
    }

    private func persistCurrentRecord() async -> Bool {
        guard let currentVerse else { return false }
        guard typingAnalysis.isComplete else { return false }
        guard !isSaving else { return false }
        guard currentVerse.id != lastSavedVerseID else { return false }

        isSaving = true
        flowMessage = nil
        defer {
            isSaving = false
        }

        let planIdentity = currentPlanWritingRecordIdentity()
        let reusablePlanRecord: WritingRecord?
        if let planIdentity {
            reusablePlanRecord = existingPlanRecord(for: currentVerse, identity: planIdentity)
        } else {
            reusablePlanRecord = nil
        }
        let record = reusablePlanRecord ?? buildRecord(from: currentVerse, planIdentity: planIdentity)

        if reusablePlanRecord == nil {
            modelContext.insert(record)
        } else {
            record.date = Calendar.current.startOfDay(for: Date())
            record.originalText = currentVerse.text
            record.userText = userText
            record.completedAt = Date()
            record.book = currentVerse.book
            record.chapter = currentVerse.chapter
            record.verse = currentVerse.verse
            record.verseId = currentVerse.id
            record.sourceType = sourceType.rawValue
            record.planId = planIdentity?.planId.uuidString
            record.assignmentId = planIdentity?.assignmentId.uuidString
            record.planDayIndex = planIdentity?.planDayIndex
        }

        do {
            try modelContext.save()
        } catch {
            flowMessage = "저장에 실패했습니다. 다시 시도해보세요."
            return false
        }

        lastSavedVerseID = currentVerse.id
        if reusablePlanRecord == nil {
            gardenActivityStore.addActivity(
                type: .scriptureCopy,
                title: GardenActivityType.scriptureCopy.displayTitle,
                verseId: currentVerse.id,
                reference: "\(currentVerse.book) \(currentVerse.chapter):\(currentVerse.verse)",
                contentPreview: currentVerse.text,
                sourceId: record.id.uuidString,
                createdAt: record.completedAt
            )
        }

        if let userID = authViewModel.currentUser?.uid {
            Task {
                if record.remoteDocumentId == nil {
                    await syncCoordinator.uploadRecordIfNeeded(
                        localRecordID: record.id,
                        userID: userID,
                        modelContext: modelContext
                    )
                } else {
                    await syncCoordinator.updateRecordIfNeeded(
                        localRecordID: record.id,
                        userID: userID,
                        modelContext: modelContext
                    )
                }
            }
        }

        if case .plan(let planID, let assignmentID, let verses, let currentIndex) = writingContext {
            let isFinalVerse = currentIndex == verses.count - 1
            do {
                try ScriptureWritingPlanService.recordSavedVerse(
                    planID: planID,
                    assignmentID: assignmentID,
                    recordID: record.id,
                    isFinalVerse: isFinalVerse,
                    modelContext: modelContext
                )
                if let userID = authViewModel.currentUser?.uid {
                    Task {
                        await writingPlanSyncCoordinator.updatePlanAndAssignmentIfNeeded(
                            localPlanID: planID,
                            localAssignmentID: assignmentID,
                            userID: userID,
                            modelContext: modelContext
                        )
                    }
                }
            } catch {
                flowMessage = "플랜 진행 상태를 업데이트하지 못했습니다."
            }
        }

        return true
    }

    private func currentPlanWritingRecordIdentity() -> PlanWritingRecordIdentity? {
        guard sourceType == .plan,
              case .plan(let planID, let assignmentID, _, _) = writingContext else {
            return nil
        }

        let descriptor = FetchDescriptor<PlanDayAssignment>(
            predicate: #Predicate { $0.id == assignmentID }
        )
        let assignment = try? modelContext.fetch(descriptor).first

        return PlanWritingRecordIdentity(
            planId: planID,
            assignmentId: assignmentID,
            planDayIndex: assignment?.dayIndex,
            completionRecordIds: assignment?.completionRecordIds ?? []
        )
    }

    private func existingPlanRecord(
        for verse: VersePayload,
        identity: PlanWritingRecordIdentity
    ) -> WritingRecord? {
        let ownerUserId = authViewModel.currentUser?.uid ?? ""
        let planId = identity.planId.uuidString
        let assignmentId = identity.assignmentId.uuidString

        let descriptor = FetchDescriptor<WritingRecord>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )

        let records = (try? modelContext.fetch(descriptor)) ?? []

        if let planAwareRecord = records.first(where: { record in
            record.ownerUserId == ownerUserId
                && record.sourceType == WritingSourceType.plan.rawValue
                && record.planId == planId
                && record.assignmentId == assignmentId
                && record.verseId == verse.id
        }) {
            return planAwareRecord
        }

        let completionRecordIds = Set(identity.completionRecordIds)
        if !completionRecordIds.isEmpty,
           let linkedLegacyRecord = records.first(where: { record in
               record.ownerUserId == ownerUserId
                   && record.sourceType == WritingSourceType.plan.rawValue
                   && record.verseId == verse.id
                   && completionRecordIds.contains(record.id.uuidString)
           }) {
            return linkedLegacyRecord
        }

        return nil
    }

    private func saveAndDismiss() async {
        let saved = await persistCurrentRecord()
        guard saved else { return }
        dismiss()
    }

    private func saveAndMoveToNextVerse() async {
        let saved = await persistCurrentRecord()
        guard saved, let nextVerse = resolveNextVerse() else {
            if saved {
                flowMessage = endOfContextMessage
            }
            return
        }

        currentVerse = nextVerse
        userText = ""
        flowMessage = nil
        lastSavedVerseID = nil
        refreshTypingAnalysis()
    }

    private var endOfContextMessage: String {
        switch writingContext {
        case .bible:
            return "다음 구절이 없습니다."
        case .theme, .verseList:
            return "이 모음의 마지막 구절입니다."
        case .plan:
            return "오늘 분량을 모두 마쳤습니다."
        }
    }

    private func nextVersePreview() -> VersePayload? {
        switch writingContext {
        case .bible:
            guard let verse = currentVerse else { return nil }

            if let sameChapterNext = service.getVerse(book: verse.book, chapter: verse.chapter, verse: verse.verse + 1) {
                return VersePayload(localVerse: sameChapterNext)
            }

            let nextChapter = verse.chapter + 1
            if let firstOfNextChapter = service.getVerse(book: verse.book, chapter: nextChapter, verse: 1) {
                return VersePayload(localVerse: firstOfNextChapter)
            }

            return nil
        case .theme(_, let verses, let currentIndex):
            guard let next = verses[safe: currentIndex + 1] else { return nil }
            return VersePayload(localVerse: next)
        case .verseList(_, let verses, let currentIndex):
            guard let next = verses[safe: currentIndex + 1] else { return nil }
            return VersePayload(localVerse: next)
        case .plan(_, _, let verses, let currentIndex):
            guard let next = verses[safe: currentIndex + 1] else { return nil }
            return VersePayload(localVerse: next)
        }
    }

    private func resolveNextVerse() -> VersePayload? {
        switch writingContext {
        case .bible:
            return nextVersePreview()
        case .theme(let themeID, let verses, let currentIndex):
            guard let next = verses[safe: currentIndex + 1] else { return nil }
            writingContext = .theme(themeId: themeID, verses: verses, currentIndex: currentIndex + 1)
            return VersePayload(localVerse: next)
        case .verseList(let listID, let verses, let currentIndex):
            guard let next = verses[safe: currentIndex + 1] else { return nil }
            writingContext = .verseList(listId: listID, verses: verses, currentIndex: currentIndex + 1)
            return VersePayload(localVerse: next)
        case .plan(let planID, let assignmentID, let verses, let currentIndex):
            guard let next = verses[safe: currentIndex + 1] else { return nil }
            writingContext = .plan(planId: planID, assignmentId: assignmentID, verses: verses, currentIndex: currentIndex + 1)
            return VersePayload(localVerse: next)
        }
    }

    private func refreshTypingAnalysis() {
        typingAnalysis = GuidedTypingValidator.analyze(userText, targetText: targetText)
    }
}

enum WritingSourceType: String {
    case direct
    case theme
    case customList
    case plan
}

enum WritingContext {
    case bible
    case theme(themeId: String, verses: [LocalBibleVerse], currentIndex: Int)
    case verseList(listId: UUID, verses: [LocalBibleVerse], currentIndex: Int)
    case plan(planId: UUID, assignmentId: UUID, verses: [LocalBibleVerse], currentIndex: Int)
}

private struct PlanWritingRecordIdentity {
    let planId: UUID
    let assignmentId: UUID
    let planDayIndex: Int?
    let completionRecordIds: [String]
}

private struct VersePayload {
    let id: String
    let book: String
    let chapter: Int
    let verse: Int
    let text: String

    init(id: String, book: String, chapter: Int, verse: Int, text: String) {
        self.id = id
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.text = text
    }

    init(localVerse: LocalBibleVerse) {
        self.id = "local-\(localVerse.id)"
        self.book = localVerse.book
        self.chapter = localVerse.chapter
        self.verse = localVerse.verse
        self.text = localVerse.text
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
