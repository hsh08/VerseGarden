import FirebaseAuth
import SwiftData
import SwiftUI

struct EditWritingPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var writingPlanSyncCoordinator: WritingPlanSyncCoordinator
    @Query(sort: \PlanDayAssignment.dayIndex, order: .forward) private var allAssignments: [PlanDayAssignment]

    let plan: ScriptureWritingPlan

    private let service = BibleDataService.shared
    private let calendar = Calendar.current

    @State private var selectedTestament: BibleTestament = .new
    @State private var selectedBook = ""
    @State private var startChapter = 1
    @State private var endChapter = 1
    @State private var startDate = Calendar.current.startOfDay(for: Date())
    @State private var totalDays = 1
    @State private var title = ""
    @State private var selectedFolderColor: WritingPlanFolderColor = .sage
    @State private var alertMessage: String?
    @State private var isSaving = false
    @State private var isApplyingInitialValues = false
    @State private var didInitializeForm = false

    private var userID: String? { authViewModel.currentUser?.uid }

    private var assignments: [PlanDayAssignment] {
        ScriptureWritingPlanService.assignments(for: plan, from: allAssignments, userID: userID)
    }

    private var minimumDuration: Int {
        ScriptureWritingPlanService.minimumAllowedDuration(
            for: plan,
            assignments: allAssignments,
            userID: userID,
            calendar: calendar
        )
    }

    private var hasWritingHistory: Bool {
        ScriptureWritingPlanService.hasWritingHistory(for: plan, assignments: allAssignments, userID: userID)
    }

    private var canModifyRangeOrStartDate: Bool {
        !plan.status.isTerminal && ScriptureWritingPlanService.canModifyRangeOrStartDate(
            for: plan,
            assignments: allAssignments,
            userID: userID
        )
    }

    private var canModifyDuration: Bool {
        !plan.status.isTerminal && ScriptureWritingPlanService.canExtendDuration(
            for: plan,
            assignments: allAssignments,
            userID: userID
        )
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

    private var maximumDuration: Int {
        max(minimumDuration, totalVerseCount)
    }

    private var lockMessage: String? {
        if plan.status.isTerminal {
            return "완료되었거나 취소된 플랜은 제목만 수정할 수 있습니다."
        }
        if hasWritingHistory {
            return "이미 필사한 기록을 보호하기 위해 범위와 일정은 수정할 수 없습니다."
        }
        return nil
    }

    private var durationHelperText: String? {
        guard minimumDuration > 1 else { return nil }
        return "이미 진행된 분량보다 짧게 줄일 수 없습니다."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                introCard
                titleCard
                folderColorCard
                rangeCard
                scheduleCard
            }
            .padding(20)
        }
        .navigationTitle("플랜 수정")
        .background(GardenTheme.background)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(isSaving ? "저장 중" : "저장") { saveChanges() }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .disabled(isSaving)
            }
        }
        .alert("안내", isPresented: alertBinding) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear {
            initializeForm()
        }
        .onChange(of: selectedTestament) { _, _ in
            guard didInitializeForm, !isApplyingInitialValues else { return }
            guard canModifyRangeOrStartDate else { return }
            selectedBook = availableBooks.first ?? selectedBook
            resetChaptersIfNeeded()
            clampDuration()
        }
        .onChange(of: selectedBook) { _, _ in
            guard didInitializeForm, !isApplyingInitialValues else { return }
            guard canModifyRangeOrStartDate else { return }
            resetChaptersIfNeeded()
            clampDuration()
        }
        .onChange(of: startChapter) { _, _ in
            guard didInitializeForm, !isApplyingInitialValues else { return }
            guard canModifyRangeOrStartDate else { return }
            if endChapter < startChapter { endChapter = startChapter }
            clampDuration()
        }
        .onChange(of: endChapter) { _, _ in
            guard didInitializeForm, !isApplyingInitialValues else { return }
            guard canModifyRangeOrStartDate else { return }
            if endChapter < startChapter { endChapter = startChapter }
            clampDuration()
        }
        .onChange(of: totalDays) { _, _ in
            guard didInitializeForm, !isApplyingInitialValues else { return }
            clampDuration()
        }
    }

    private var introCard: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.78), GardenTheme.secondary.opacity(0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("필사 플랜 수정")
                    .font(.title3.bold())
                Text(lockMessage ?? "제목과 폴더 색상은 언제든 수정할 수 있고, 기록 전에는 범위와 일정도 바꿀 수 있습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("현재 플랜 기준으로 수정됩니다.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(GardenTheme.primary)
            }
        }
    }

    private var titleCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 12) {
                GardenSectionHeader("플랜 제목")
                AppInputField(title: "제목", placeholder: "플랜 제목", text: $title)
            }
        }
    }

    private var folderColorCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 12) {
                GardenSectionHeader("폴더 색상", subtitle: "플랜을 구분하기 쉬운 색을 고르세요.")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                    ForEach(WritingPlanFolderColor.allCases) { folderColor in
                        Button {
                            selectedFolderColor = folderColor
                        } label: {
                            Image(systemName: selectedFolderColor == folderColor ? "checkmark" : "folder.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(folderColor.checkmarkColor)
                                .frame(width: 42, height: 36)
                                .background(folderColor.color)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(selectedFolderColor == folderColor ? AppColors.textPrimary : .clear, lineWidth: 1.5)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(folderColor.title) 폴더 색상")
                        .accessibilityAddTraits(selectedFolderColor == folderColor ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var rangeCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                GardenSectionHeader("말씀 범위", subtitle: canModifyRangeOrStartDate ? "진행 전에는 책과 장 범위를 다시 정할 수 있습니다." : "이미 진행한 플랜은 범위를 바꿀 수 없습니다.")

                Picker("구약/신약", selection: $selectedTestament) {
                    ForEach(BibleTestament.allCases) { testament in
                        Text(testament.title).tag(testament)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!canModifyRangeOrStartDate)

                Picker("책", selection: $selectedBook) {
                    ForEach(availableBooks, id: \.self) { book in
                        Text(book).tag(book)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!canModifyRangeOrStartDate)

                HStack(spacing: 12) {
                    Picker("시작 장", selection: $startChapter) {
                        ForEach(availableChapters, id: \.self) { chapter in
                            Text("\(chapter)장").tag(chapter)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!canModifyRangeOrStartDate)

                    Picker("끝 장", selection: $endChapter) {
                        ForEach(availableEndChapters, id: \.self) { chapter in
                            Text("\(chapter)장").tag(chapter)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!canModifyRangeOrStartDate)
                }
            }
        }
    }

    private var scheduleCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                GardenSectionHeader("일정", subtitle: canModifyDuration ? "기록 전에는 시작일과 전체 기간을 다시 정할 수 있습니다." : "필사 기록을 보호하기 위해 일정은 수정할 수 없습니다.")

                DatePicker("시작일", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .disabled(!canModifyRangeOrStartDate)

                Stepper(value: $totalDays, in: minimumDuration...maximumDuration) {
                    HStack {
                        Text("총 기간")
                        Spacer()
                        Text("\(totalDays)일")
                            .fontWeight(.semibold)
                            .foregroundStyle(GardenTheme.primary)
                    }
                }
                .disabled(!canModifyDuration)

                if hasWritingHistory {
                    Text("기록이 있는 플랜은 제목과 폴더 색상만 수정할 수 있습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let durationHelperText {
                    Text(durationHelperText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { isPresented in
                if !isPresented { alertMessage = nil }
            }
        )
    }

    private func initializeForm() {
        isApplyingInitialValues = true
        selectedTestament = testament(for: plan.book)
        selectedBook = plan.book
        startChapter = plan.startChapter
        endChapter = plan.endChapter
        startDate = calendar.startOfDay(for: plan.startDate)
        totalDays = plan.totalDays
        title = plan.title
        selectedFolderColor = plan.folderColorRaw.flatMap(WritingPlanFolderColor.init(rawValue:)) ?? .sage
        clampDuration()
        didInitializeForm = true
        DispatchQueue.main.async {
            isApplyingInitialValues = false
        }
    }

    private func testament(for book: String) -> BibleTestament {
        if service.books(in: .old).contains(book) {
            return .old
        }
        return .new
    }

    private func resetChaptersIfNeeded() {
        let chapters = availableChapters
        if !chapters.contains(startChapter) {
            startChapter = chapters.first ?? 1
        }
        if endChapter < startChapter || !chapters.contains(endChapter) {
            endChapter = startChapter
        }
    }

    private func clampDuration() {
        let maximum = maximumDuration
        totalDays = min(max(totalDays, minimumDuration), maximum)
    }

    private func saveChanges() {
        if totalDays < minimumDuration {
            alertMessage = "이미 진행된 분량보다 짧게 줄일 수 없습니다."
            return
        }

        do {
            try ScriptureWritingPlanService.applyEdits(
                to: plan,
                userID: userID,
                newTitle: title.trimmingCharacters(in: .whitespacesAndNewlines),
                newStartDate: calendar.startOfDay(for: startDate),
                newBook: selectedBook,
                newStartChapter: startChapter,
                newEndChapter: endChapter,
                newTotalDays: totalDays,
                newFolderColorRaw: selectedFolderColor.rawValue,
                modelContext: modelContext,
                calendar: calendar
            )
            guard let userID else {
                dismiss()
                return
            }
            isSaving = true
            Task {
                let didSync = await writingPlanSyncCoordinator.syncPlanAndAssignments(
                    localPlanID: plan.id,
                    userID: userID,
                    modelContext: modelContext
                )
                isSaving = false
                if didSync {
                    dismiss()
                } else {
                    alertMessage = "변경 내용은 기기에 저장됐지만 동기화하지 못했어요. 잠시 후 다시 시도해주세요."
                }
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
