import FirebaseAuth
import SwiftData
import SwiftUI

struct PrayerComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var prayerSyncCoordinator: PrayerSyncCoordinator
    @EnvironmentObject private var gardenActivityStore: GardenActivityStore

    private let template: PrayerTemplate?
    private let record: PrayerWritingRecord?

    @State private var title: String
    @State private var originalText: String
    @State private var userText: String
    @State private var deletingRecord = false
    @State private var isSaving = false
    @State private var hasSavedCurrentSession = false
    @State private var typingAnalysis: TypingAnalysis = .empty

    init(template: PrayerTemplate? = nil, record: PrayerWritingRecord? = nil) {
        self.template = template
        self.record = record
        _title = State(initialValue: record?.titleSnapshot ?? template?.title ?? "")
        _originalText = State(initialValue: record?.originalText ?? template?.bodyText ?? "")
        _userText = State(initialValue: record?.userText ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                GardenCard(
                    accentGradient: LinearGradient(
                        colors: [GardenTheme.primary.opacity(0.9), GardenTheme.secondary.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(editorTitle)
                            .font(.title3.bold())
                        Text(editorSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if usesGuidedTyping {
                    guidedTemplateSection
                } else {
                    freeWritingSection
                }

                GardenPrimaryButton(
                    title: record == nil ? "기도 저장" : "수정 완료",
                    icon: "checkmark.circle.fill",
                    disabled: saveDisabled
                ) {
                    save()
                }
                .disabled(saveDisabled)

                if record != nil {
                    Button(role: .destructive) {
                        deletingRecord = true
                    } label: {
                        Text("기록 삭제")
                            .font(.headline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .navigationTitle("기도 쓰기")
        .background(GardenTheme.background)
        .alert("기록을 삭제할까요?", isPresented: $deletingRecord) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                deleteRecord()
            }
        } message: {
            Text("기도 기록이 삭제됩니다.")
        }
        .onAppear {
            refreshTypingAnalysis()
        }
        .onChange(of: userText) { _, _ in
            refreshTypingAnalysis()
        }
    }

    private var editorTitle: String {
        if record != nil { return "기도 기록 수정" }
        if template != nil { return "기도문으로 필사" }
        return "새 기도 작성"
    }

    private var editorSubtitle: String {
        if template?.isDefaultTemplate == true {
            return "앱 제공 기도문을 따라 적으며 오늘의 마음을 정리해보세요."
        }
        if template != nil {
            return "저장한 기도문을 바탕으로 다시 기도할 수 있습니다."
        }
        return "자유롭게 기도를 적고 오늘의 마음을 남겨보세요."
    }

    private var showOriginalTextSection: Bool {
        !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var usesGuidedTyping: Bool {
        record == nil && template?.isDefaultTemplate == true && showOriginalTextSection
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedUserText: String { userText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var targetText: String { originalText }

    private var saveDisabled: Bool {
        if usesGuidedTyping {
            return !typingAnalysis.isComplete || isSaving || hasSavedCurrentSession
        }
        return trimmedTitle.count < 2 || trimmedUserText.count < 2 || isSaving || hasSavedCurrentSession
    }

    private var guidedTemplateSection: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(title)
                        .font(.headline)
                    if let category = template?.category, !category.isEmpty {
                        Text(category)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(originalText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(6)
                        .padding(14)
                        .background(GardenTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("기도문 따라 쓰기")
                        .font(.headline)

                    GuidedTypingTextView(
                        targetText: targetText,
                        inputText: $userText,
                        analysis: typingAnalysis
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("진행률")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(typingAnalysis.progress * 100))%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(typingAnalysis.progress == 1 ? GardenTheme.primary : .secondary)
                        }

                        ProgressView(value: typingAnalysis.progress)
                            .tint(typingAnalysis.progress == 1 ? GardenTheme.primary : GardenTheme.secondary)

                        if typingAnalysis.hasWhitespaceMismatch && !userText.isEmpty {
                            Text("띄어쓰기를 다시 확인해보세요.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if typingAnalysis.hasWrongCharacter && !userText.isEmpty {
                            Text("조금만 수정하면 완성돼요.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if typingAnalysis.isComplete {
                            Text("필사가 완료되었습니다.")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(GardenTheme.primary)
                        } else {
                            Text("천천히 기도문을 따라 적어보세요.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var freeWritingSection: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("기도 제목")
                    .font(.headline)
                TextField("오늘의 기도 제목", text: $title)
                    .textFieldStyle(.roundedBorder)

                if showOriginalTextSection {
                    Text("원문")
                        .font(.headline)
                    Text(originalText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineSpacing(6)
                        .padding(14)
                        .background(GardenTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                Text("직접 기록")
                    .font(.headline)
                TextEditor(text: $userText)
                    .frame(minHeight: 240)
                    .padding(10)
                    .background(GardenTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    private func save() {
        guard !isSaving, !hasSavedCurrentSession else { return }
        if usesGuidedTyping {
            guard typingAnalysis.isComplete else { return }
        } else {
            guard trimmedTitle.count >= 2, trimmedUserText.count >= 2 else { return }
        }
        let now = Date()
        isSaving = true

        if let record {
            record.titleSnapshot = trimmedTitle
            record.originalText = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
            record.userText = trimmedUserText
            record.updatedAt = now
            do {
                try modelContext.save()
            } catch {
                isSaving = false
                return
            }

            if let userID = authViewModel.currentUser?.uid {
                Task {
                    await prayerSyncCoordinator.updateRecordIfNeeded(
                        localRecordID: record.id,
                        userID: userID,
                        modelContext: modelContext
                    )
                }
            }
        } else {
            let sourceType: PrayerSourceType
            var templateLocalId: UUID?
            var templateRemoteId: String?
            if let template {
                sourceType = template.isDefaultTemplate ? .defaultPrayer : .userPrayer
                templateLocalId = template.id
                templateRemoteId = template.remoteDocumentId
            } else {
                sourceType = .freeformPrayer

                let newTemplate = PrayerTemplate(
                    ownerUserId: authViewModel.currentUser?.uid ?? "",
                    title: trimmedTitle,
                    bodyText: trimmedUserText
                )
                modelContext.insert(newTemplate)
                templateLocalId = newTemplate.id
            }

            let newRecord = PrayerWritingRecord(
                ownerUserId: authViewModel.currentUser?.uid ?? "",
                createdAt: now,
                updatedAt: now,
                date: Calendar.current.startOfDay(for: now),
                completedAt: now,
                sourceType: sourceType.rawValue,
                templateLocalId: templateLocalId,
                templateRemoteId: templateRemoteId,
                titleSnapshot: trimmedTitle,
                originalText: originalText.trimmingCharacters(in: .whitespacesAndNewlines),
                userText: trimmedUserText
            )
            modelContext.insert(newRecord)
            do {
                try modelContext.save()
            } catch {
                isSaving = false
                return
            }

            gardenActivityStore.addActivity(
                type: .prayer,
                title: GardenActivityType.prayer.displayTitle,
                contentPreview: trimmedTitle,
                sourceId: newRecord.id.uuidString,
                createdAt: newRecord.completedAt
            )

            if let userID = authViewModel.currentUser?.uid {
                Task {
                    if let templateLocalId {
                        await prayerSyncCoordinator.uploadTemplateIfNeeded(
                            localTemplateID: templateLocalId,
                            userID: userID,
                            modelContext: modelContext
                        )
                    }
                    await prayerSyncCoordinator.uploadRecordIfNeeded(
                        localRecordID: newRecord.id,
                        userID: userID,
                        modelContext: modelContext
                    )
                }
            }
        }

        hasSavedCurrentSession = true
        isSaving = false
        dismiss()
    }

    private func deleteRecord() {
        guard let record else { return }
        Task {
            await prayerSyncCoordinator.deleteRecordIfNeeded(
                localRecordID: record.id,
                userID: authViewModel.currentUser?.uid,
                modelContext: modelContext
            )
            dismiss()
        }
    }

    private func refreshTypingAnalysis() {
        guard usesGuidedTyping else {
            typingAnalysis = .empty
            return
        }
        typingAnalysis = GuidedTypingValidator.analyze(userText, targetText: targetText)
    }
}
