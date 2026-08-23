import FirebaseAuth
import SwiftData
import SwiftUI

struct PlanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var writingPlanSyncCoordinator: WritingPlanSyncCoordinator
    @Query(sort: \PlanDayAssignment.dayIndex, order: .forward) private var allAssignments: [PlanDayAssignment]

    let plan: ScriptureWritingPlan

    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    @State private var alertMessage: String?

    private var userID: String? { authViewModel.currentUser?.uid }

    private var assignments: [PlanDayAssignment] {
        ScriptureWritingPlanService.assignments(for: plan, from: allAssignments, userID: userID)
    }

    private var counts: (completed: Int, missed: Int, pending: Int) {
        ScriptureWritingPlanService.assignmentCounts(for: plan, assignments: allAssignments, userID: userID)
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
            ToolbarItem(placement: .topBarTrailing) {
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
                            Label("재개하기", systemImage: "play.circle")
                        }
                    }

                    if plan.status != .cancelled {
                        Button {
                            showingEdit = true
                        } label: {
                            Label("플랜 수정", systemImage: "square.and.pencil")
                        }
                    }

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("플랜 삭제", systemImage: "trash")
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
        .alert("플랜을 삭제할까요?", isPresented: $showingDeleteAlert) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                deletePlan()
            }
        } message: {
            Text("플랜과 일별 할당은 삭제되지만, 이미 작성한 말씀 기록은 그대로 남습니다.")
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
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Day \(assignment.dayIndex)")
                        .font(.headline)
                    stateBadge(for: assignment.state)
                }

                Text(assignment.date.formatted(.dateTime.month().day().weekday(.abbreviated)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(ScriptureWritingPlanService.rangeText(for: assignment))
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Text("\(assignment.verseCount)절")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if interactive {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.cardTint)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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

    private func pausePlan() {
        do {
            try ScriptureWritingPlanService.pausePlan(plan, modelContext: modelContext)
            if let userID {
                Task {
                    await writingPlanSyncCoordinator.updatePlanIfNeeded(
                        localPlanID: plan.id,
                        userID: userID,
                        modelContext: modelContext
                    )
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
                    await writingPlanSyncCoordinator.updatePlanIfNeeded(
                        localPlanID: plan.id,
                        userID: userID,
                        modelContext: modelContext
                    )
                }
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func deletePlan() {
        guard let userID else { return }
        Task {
            await writingPlanSyncCoordinator.deletePlanIfNeeded(
                localPlanID: plan.id,
                userID: userID,
                modelContext: modelContext
            )
            dismiss()
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
