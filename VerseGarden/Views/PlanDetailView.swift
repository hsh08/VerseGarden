import FirebaseAuth
import SwiftData
import SwiftUI

struct PlanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var writingPlanSyncCoordinator: WritingPlanSyncCoordinator
    @EnvironmentObject private var writingPlanSelectionStore: WritingPlanSelectionStore
    @Query(sort: \PlanDayAssignment.dayIndex, order: .forward) private var allAssignments: [PlanDayAssignment]

    let plan: ScriptureWritingPlan

    @State private var showingEdit = false
    @State private var destructiveAction: PlanDestructiveAction?
    @State private var alertMessage: String?

    private var userID: String? { authViewModel.currentUser?.uid }

    private var assignments: [PlanDayAssignment] {
        ScriptureWritingPlanService.assignments(for: plan, from: allAssignments, userID: userID)
    }

    private var counts: (completed: Int, missed: Int, pending: Int) {
        ScriptureWritingPlanService.assignmentCounts(for: plan, assignments: allAssignments, userID: userID)
    }

    private var hasWritingHistory: Bool {
        ScriptureWritingPlanService.hasWritingHistory(for: plan, assignments: allAssignments, userID: userID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                summaryCard
                assignmentSection
            }
            .padding(20)
        }
        .navigationTitle("플랜 상세")
        .background(GardenTheme.background)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !plan.status.isTerminal {
                    Button {
                        showingEdit = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(GardenTheme.primary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("플랜 수정")
                }

                Menu {
                    if plan.status == .active {
                        Button {
                            pausePlan()
                        } label: {
                            Label("일시정지", systemImage: "pause.circle")
                        }
                    } else if plan.status == .paused {
                        Button {
                            resumePlan()
                        } label: {
                            Label("재개", systemImage: "play.circle")
                        }
                    }

                    if !plan.status.isTerminal && hasWritingHistory {
                        Button(role: .destructive) {
                            destructiveAction = .end
                        } label: {
                            Label("플랜 종료", systemImage: "stop.circle")
                        }
                    } else {
                        Button(role: .destructive) {
                            destructiveAction = .delete
                        } label: {
                            Label("플랜 삭제", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
        }
        .task(id: detailSignature) {
            PlanAssignmentStateEvaluator.refreshStates(userID: userID, modelContext: modelContext)
        }
        .sheet(isPresented: $showingEdit) {
            NavigationStack {
                EditWritingPlanView(plan: plan)
            }
        }
        .alert(destructiveAction?.title ?? "", isPresented: destructiveAlertBinding) {
            Button("취소", role: .cancel) {}
            Button(destructiveAction?.confirmTitle ?? "확인", role: .destructive) {
                performDestructiveAction()
            }
        } message: {
            Text(destructiveAction?.message ?? "")
        }
        .alert("안내", isPresented: alertBinding) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var summaryCard: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.8), GardenTheme.secondary.opacity(0.68)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(plan.title)
                            .font(.title3.bold())
                        Text(ScriptureWritingPlanService.planRangeText(for: plan))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(plan.status.badgeTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusTint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusTint.opacity(0.12))
                        .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(plan.startDate.formatted(.dateTime.year().month().day())) 시작")
                        .font(.subheadline)
                    Text("\(plan.endDate.formatted(.dateTime.year().month().day())) 종료")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    statCard(title: "진행", value: "\(plan.completedDays)/\(plan.totalDays)일")
                    statCard(title: "진행률", value: "\(Int(plan.progress * 100))%")
                }

                HStack(spacing: 12) {
                    statCard(title: "놓친 필사", value: "\(counts.missed)개")
                    statCard(title: "남은 일수", value: "\(plan.remainingDays)일")
                }
            }
        }
    }

    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GardenSectionHeader("일별 할당", subtitle: "완료한 날과 남은 분량을 순서대로 확인할 수 있습니다.")

            LazyVStack(spacing: 10) {
                ForEach(assignments) { assignment in
                    assignmentRow(assignment)
                }
            }
        }
    }

    @ViewBuilder
    private func assignmentRow(_ assignment: PlanDayAssignment) -> some View {
        let canStart = ScriptureWritingPlanService.canStartAssignment(assignment, in: plan)
        let launch = ScriptureWritingPlanService.launchContext(for: assignment, plan: plan)

        if canStart, let launch {
            NavigationLink {
                WriteView(localVerse: launch.verse, sourceType: .plan, writingContext: launch.context)
            } label: {
                assignmentCard(assignment, interactive: true)
            }
            .buttonStyle(.plain)
        } else {
            assignmentCard(assignment, interactive: false)
        }
    }

    private func assignmentCard(_ assignment: PlanDayAssignment, interactive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            assignmentHeader(assignment, interactive: interactive)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(ScriptureWritingPlanService.rangeText(for: assignment))
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                Text("\(assignment.verseCount)절")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppColors.cardTint)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func assignmentHeader(_ assignment: PlanDayAssignment, interactive: Bool) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                assignmentIdentity(assignment)
                    .layoutPriority(1)
                Spacer(minLength: 8)
                Text(assignmentDateText(assignment.date))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                assignmentChevron(isInteractive: interactive)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    assignmentIdentity(assignment)
                        .layoutPriority(1)
                    Spacer(minLength: 8)
                    assignmentChevron(isInteractive: interactive)
                }
                Text(assignmentDateText(assignment.date))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func assignmentIdentity(_ assignment: PlanDayAssignment) -> some View {
        HStack(spacing: 8) {
            Text("Day \(assignment.dayIndex)")
                .font(.headline)
            stateBadge(for: assignment.state)
        }
    }

    @ViewBuilder
    private func assignmentChevron(isInteractive: Bool) -> some View {
        if isInteractive {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func assignmentDateText(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().locale(Locale(identifier: "ko_KR")))
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func stateBadge(for state: PlanAssignmentState) -> some View {
        Text(state.badgeTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(state.badgeTint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(state.badgeTint.opacity(0.12))
            .clipShape(Capsule())
    }

    private var statusTint: Color {
        switch plan.status {
        case .active: return GardenTheme.primary
        case .paused: return .orange
        case .completed: return GardenTheme.secondary
        case .cancelled: return .gray
        }
    }

    private var detailSignature: String {
        let planPart = "\(plan.id.uuidString)-\(plan.statusRaw)-\(plan.completedDays)-\(plan.updatedAt.timeIntervalSince1970)"
        let assignmentPart = assignments
            .map { "\($0.id.uuidString)-\($0.stateRaw)-\($0.completedAt?.timeIntervalSince1970 ?? 0)-\($0.updatedAt.timeIntervalSince1970)" }
            .joined(separator: "|")
        return "\(planPart)#\(assignmentPart)"
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    alertMessage = nil
                }
            }
        )
    }

    private var destructiveAlertBinding: Binding<Bool> {
        Binding(
            get: { destructiveAction != nil },
            set: { isPresented in
                if !isPresented { destructiveAction = nil }
            }
        )
    }

    private func pausePlan() {
        do {
            try ScriptureWritingPlanService.pausePlan(plan, modelContext: modelContext)
            if let userID {
                Task {
                    let didSync = await writingPlanSyncCoordinator.updatePlanIfNeeded(
                        localPlanID: plan.id,
                        userID: userID,
                        modelContext: modelContext
                    )
                    if !didSync {
                        alertMessage = "변경 내용은 기기에 저장됐지만 동기화하지 못했어요. 잠시 후 다시 시도해주세요."
                    }
                }
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func resumePlan() {
        do {
            try ScriptureWritingPlanService.resumePlan(
                plan,
                userID: userID,
                modelContext: modelContext
            )
            if let userID {
                Task {
                    let didSync = await writingPlanSyncCoordinator.updatePlanIfNeeded(
                        localPlanID: plan.id,
                        userID: userID,
                        modelContext: modelContext
                    )
                    if !didSync {
                        alertMessage = "변경 내용은 기기에 저장됐지만 동기화하지 못했어요. 잠시 후 다시 시도해주세요."
                    }
                }
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func performDestructiveAction() {
        guard let destructiveAction else { return }
        switch destructiveAction {
        case .end:
            endPlan()
        case .delete:
            deletePlan()
        }
    }

    private func endPlan() {
        do {
            try ScriptureWritingPlanService.endPlan(plan, modelContext: modelContext)
            writingPlanSelectionStore.selectPlan(nil)
            if let userID {
                Task {
                    let didSync = await writingPlanSyncCoordinator.updatePlanIfNeeded(
                        localPlanID: plan.id,
                        userID: userID,
                        modelContext: modelContext
                    )
                    if !didSync {
                        alertMessage = "플랜은 종료됐지만 동기화하지 못했어요. 잠시 후 다시 시도해주세요."
                    }
                }
            }
        } catch {
            alertMessage = "플랜을 종료하지 못했어요. 잠시 후 다시 시도해주세요."
        }
    }

    private func deletePlan() {
        guard let userID else { return }
        Task {
            let didDelete = await writingPlanSyncCoordinator.deletePlanIfNeeded(
                localPlanID: plan.id,
                userID: userID,
                modelContext: modelContext
            )
            if didDelete {
                writingPlanSelectionStore.selectPlan(nil)
                dismiss()
            } else {
                alertMessage = "플랜을 삭제하지 못했어요. 잠시 후 다시 시도해주세요."
            }
        }
    }
}

private enum PlanDestructiveAction {
    case end
    case delete

    var title: String {
        switch self {
        case .end: return "이 플랜을 종료할까요?"
        case .delete: return "필사 플랜을 삭제할까요?"
        }
    }

    var confirmTitle: String {
        switch self {
        case .end: return "종료"
        case .delete: return "삭제"
        }
    }

    var message: String {
        switch self {
        case .end: return "이미 완료한 필사 기록은 유지되며, 남은 일정은 종료됩니다."
        case .delete: return "플랜 일정은 삭제되지만, 이미 작성한 말씀 기록은 그대로 남습니다."
        }
    }
}

private extension PlanAssignmentState {
    var badgeTitle: String {
        switch self {
        case .pending: return "대기"
        case .completed: return "완료"
        case .missed: return "놓침"
        }
    }

    var badgeTint: Color {
        switch self {
        case .pending: return GardenTheme.primary
        case .completed: return GardenTheme.secondary
        case .missed: return .orange
        }
    }
}

private extension ScriptureWritingPlanStatus {
    var badgeTitle: String {
        switch self {
        case .active: return "진행 중"
        case .paused: return "일시정지"
        case .completed: return "완료"
        case .cancelled: return "취소됨"
        }
    }
}
