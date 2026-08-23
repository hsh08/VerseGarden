import FirebaseAuth
import SwiftData
import SwiftUI

struct CreateWritingPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var writingPlanSyncCoordinator: WritingPlanSyncCoordinator
    @Query(sort: \ScriptureWritingPlan.createdAt, order: .reverse) private var plans: [ScriptureWritingPlan]

    private let service = BibleDataService.shared
    private let calendar = Calendar.current

    @State private var selectedTestament: BibleTestament = .new
    @State private var selectedBook = ""
    @State private var startChapter = 1
    @State private var endChapter = 1
    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var totalDays = 7
    @State private var selectedFolderColor: WritingPlanFolderColor = .sage
    @State private var preview: ScriptureWritingPlanPreview?
    @State private var alertMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                introCard
                rangeCard
                scheduleCard
                folderColorCard
                previewCard
            }
            .padding(20)
        }
        .navigationTitle("필사 플랜 만들기")
        .background(GardenTheme.background)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") { savePlan() }
                    .disabled(preview == nil || authViewModel.currentUser == nil)
            }
        }
        .alert("안내", isPresented: alertBinding) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear {
            initializeSelectionsIfNeeded()
            refreshPreview()
        }
        .onChange(of: selectedTestament) { _, _ in
            resetBookSelection()
            refreshPreview()
        }
        .onChange(of: selectedBook) { _, _ in
            resetChapterSelection()
            refreshPreview()
        }
        .onChange(of: startChapter) { _, _ in
            if endChapter < startChapter { endChapter = startChapter }
            adjustTotalDaysIfNeeded()
            refreshPreview()
        }
        .onChange(of: endChapter) { _, _ in
            if endChapter < startChapter { endChapter = startChapter }
            adjustTotalDaysIfNeeded()
            refreshPreview()
        }
        .onChange(of: startDate) { _, _ in
            refreshPreview()
        }
        .onChange(of: totalDays) { _, _ in
            adjustTotalDaysIfNeeded()
            refreshPreview()
        }
    }

    private var introCard: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.82), GardenTheme.secondary.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("하루 분량이 정해진 필사 루틴")
                    .font(.title3.bold())
                Text("책과 장 범위, 시작일, 기간을 고르면 매일 이어 쓸 말씀 범위를 자동으로 나눠드립니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var rangeCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                GardenSectionHeader("말씀 범위", subtitle: "같은 책 안에서 시작 장과 끝 장을 선택합니다.")

                Picker("구약/신약", selection: $selectedTestament) {
                    ForEach(BibleTestament.allCases) { testament in
                        Text(testament.title).tag(testament)
                    }
                }
                .pickerStyle(.segmented)

                Picker("책", selection: $selectedBook) {
                    ForEach(availableBooks, id: \.self) { book in
                        Text(book).tag(book)
                    }
                }
                .pickerStyle(.menu)

                HStack(spacing: 12) {
                    Picker("시작 장", selection: $startChapter) {
                        ForEach(availableChapters, id: \.self) { chapter in
                            Text("\(chapter)장").tag(chapter)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("끝 장", selection: $endChapter) {
                        ForEach(availableEndChapters, id: \.self) { chapter in
                            Text("\(chapter)장").tag(chapter)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private var scheduleCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                GardenSectionHeader("일정", subtitle: "시작일과 전체 일수를 정하면 종료일은 자동으로 계산됩니다.")

                DatePicker("시작일", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)

                Stepper(value: $totalDays, in: 1...max(1, totalVerseCount)) {
                    HStack {
                        Text("총 기간")
                        Spacer()
                        Text("\(totalDays)일")
                            .fontWeight(.semibold)
                            .foregroundStyle(GardenTheme.primary)
                    }
                }
            }
        }
    }

    private var folderColorCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                GardenSectionHeader("파일 색상", subtitle: "Home에서 보일 필사 플랜 파일 색을 고릅니다.")

                HStack(spacing: 12) {
                    WritingPlanFolderIcon(color: selectedFolderColor.color, isSelected: true)
                        .frame(width: 64, height: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedFolderColor.title)
                            .font(.headline)
                            .foregroundStyle(AppColors.primaryText)
                        Text("선택한 색은 Home의 필사 플랜 파일에 적용됩니다.")
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }

                    Spacer()
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(WritingPlanFolderColor.allCases) { folderColor in
                        Button {
                            selectedFolderColor = folderColor
                        } label: {
                            VStack(spacing: 7) {
                                Circle()
                                    .fill(folderColor.color)
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        Circle()
                                            .stroke(selectedFolderColor == folderColor ? AppColors.primaryText : Color.white.opacity(0.78), lineWidth: selectedFolderColor == folderColor ? 2 : 1)
                                    }
                                    .overlay {
                                        if selectedFolderColor == folderColor {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(folderColor.checkmarkColor)
                                        }
                                    }

                                Text(folderColor.title)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(selectedFolderColor == folderColor ? GardenTheme.primary : AppColors.secondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(selectedFolderColor == folderColor ? GardenTheme.softFill : AppColors.cardTint.opacity(0.46))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var previewCard: some View {
        if let preview {
            GardenCard {
                VStack(alignment: .leading, spacing: 14) {
                    GardenSectionHeader("미리 보기", subtitle: preview.title)

                    HStack(spacing: 12) {
                        GardenStatCard(title: "총 구절", value: "\(preview.totalVerses)절", subtitle: nil)
                        GardenStatCard(title: "전체 기간", value: "\(preview.totalDays)일", subtitle: nil)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("하루 분량")
                            .font(.headline)
                        Text(preview.dailyCounts.map(String.init).joined(separator: " / "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let warningMessage = preview.warningMessage {
                            Text(warningMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let first = preview.verseSlices.first, let last = preview.verseSlices.last {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("첫날과 마지막 날")
                                .font(.headline)
                            Text("Day 1 · \(ScriptureWritingPlanService.rangeText(for: temporaryAssignment(from: first, book: preview.book)))")
                                .font(.subheadline)
                            Text("Day \(last.dayIndex) · \(ScriptureWritingPlanService.rangeText(for: temporaryAssignment(from: last, book: preview.book)))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } else {
            GardenCard {
                Text("선택한 범위를 바탕으로 플랜을 미리 계산할 수 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var availableBooks: [String] {
        service.books(in: selectedTestament)
    }

    private var availableChapters: [Int] {
        guard !selectedBook.isEmpty else { return [] }
        return service.chapters(in: selectedBook)
    }

    private var availableEndChapters: [Int] {
        availableChapters.filter { $0 >= startChapter }
    }

    private var totalVerseCount: Int {
        guard !selectedBook.isEmpty, startChapter <= endChapter else { return 1 }
        return (startChapter...endChapter)
            .flatMap { service.getVerses(book: selectedBook, chapter: $0) }
            .count
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { isPresented in
                if !isPresented { alertMessage = nil }
            }
        )
    }

    private func initializeSelectionsIfNeeded() {
        guard selectedBook.isEmpty else { return }
        selectedBook = availableBooks.first ?? ""
        resetChapterSelection()
    }

    private func resetBookSelection() {
        selectedBook = availableBooks.first ?? ""
        resetChapterSelection()
    }

    private func resetChapterSelection() {
        let chapters = availableChapters
        startChapter = chapters.first ?? 1
        endChapter = startChapter
        adjustTotalDaysIfNeeded()
    }

    private func adjustTotalDaysIfNeeded() {
        totalDays = max(1, min(totalDays, max(totalVerseCount, 1)))
    }

    private func refreshPreview() {
        guard !selectedBook.isEmpty else {
            preview = nil
            return
        }

        preview = try? ScriptureWritingPlanBuilder.buildPreview(
            book: selectedBook,
            startChapter: startChapter,
            endChapter: endChapter,
            startDate: calendar.startOfDay(for: startDate),
            totalDays: totalDays
        )
    }

    private func savePlan() {
        guard let userID = authViewModel.currentUser?.uid, let preview else { return }

        do {
            let planID = try ScriptureWritingPlanService.createPlan(
                preview: preview,
                userID: userID,
                existingPlans: plans,
                modelContext: modelContext,
                folderColorRaw: selectedFolderColor.rawValue
            )
            Task {
                await writingPlanSyncCoordinator.uploadPlanIfNeeded(
                    localPlanID: planID,
                    userID: userID,
                    modelContext: modelContext
                )
            }
            dismiss()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func temporaryAssignment(from slice: ScriptureWritingPlanSlice, book: String) -> PlanDayAssignment {
        PlanDayAssignment(
            planLocalId: UUID(),
            ownerUserId: "",
            dayIndex: slice.dayIndex,
            date: slice.date,
            book: book,
            startChapter: slice.startChapter,
            startVerse: slice.startVerse,
            endChapter: slice.endChapter,
            endVerse: slice.endVerse,
            verseCount: slice.verseCount
        )
    }
}
