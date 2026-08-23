import FirebaseAuth
import SwiftData
import SwiftUI

struct MyPlansView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Query(sort: \ScriptureWritingPlan.updatedAt, order: .reverse) private var plans: [ScriptureWritingPlan]
    @Query(sort: \PlanDayAssignment.date, order: .forward) private var assignments: [PlanDayAssignment]

    @State private var showingCreatePlan = false

    private var userID: String? { authViewModel.currentUser?.uid }

    private var grouped: ScriptureWritingPlanService.PlanStatusSections {
        ScriptureWritingPlanService.groupedPlans(from: plans, userID: userID)
    }

    private var currentAssignments: [PlanDayAssignment] {
        assignments.assignments(for: userID)
    }

    private var hasAnyPlans: Bool {
        !grouped.active.isEmpty || !grouped.paused.isEmpty || !grouped.completed.isEmpty || !grouped.cancelled.isEmpty
    }

    private var canCreatePlan: Bool {
        authViewModel.currentUser != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                introCard

                if !hasAnyPlans {
                    ContentUnavailableView(
                        "아직 필사 플랜이 없습니다",
                        systemImage: "calendar.badge.plus",
                        description: Text("책과 장 범위를 정해 매일 이어가는 필사 루틴을 만들어보세요.")
                    )
                    .padding(.top, 40)
                } else {
                    planSection("진행 중", plans: grouped.active, tint: GardenTheme.primary)
                    planSection("일시정지", plans: grouped.paused, tint: .orange)
                    planSection("완료", plans: grouped.completed, tint: GardenTheme.secondary)
                    planSection("취소됨", plans: grouped.cancelled, tint: .gray)
                }
            }
            .padding(20)
        }
        .navigationTitle("플랜 관리")
        .background(GardenTheme.background)
        .toolbar {
            if canCreatePlan {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreatePlan = true
                    } label: {
                        Label("새 플랜", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreatePlan) {
            NavigationStack {
                CreateWritingPlanView()
            }
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
                Text("필사 플랜 관리")
                    .font(.title3.bold())
                Text("진행 중인 플랜, 쉬고 있는 플랜, 완료한 플랜을 한곳에서 확인하고 이어갈 수 있습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func planSection(_ title: String, plans: [ScriptureWritingPlan], tint: Color) -> some View {
        if !plans.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                GardenSectionHeader(title)

                LazyVStack(spacing: 12) {
                    ForEach(plans) { plan in
                        NavigationLink {
                            PlanDetailView(plan: plan)
                        } label: {
                            planCard(plan, tint: tint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func planCard(_ plan: ScriptureWritingPlan, tint: Color) -> some View {
        let dayIndex = ScriptureWritingPlanService.displayDayIndex(
            for: plan,
            assignments: currentAssignments,
            userID: userID
        )
        let counts = ScriptureWritingPlanService.assignmentCounts(
            for: plan,
            assignments: currentAssignments,
            userID: userID
        )
        let nextText = ScriptureWritingPlanService.nextAssignmentDisplayText(
            for: plan,
            assignments: currentAssignments,
            userID: userID
        ) ?? "남은 할당이 없습니다."

        return GardenCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(plan.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(ScriptureWritingPlanService.planRangeText(for: plan))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    statusBadge(plan.status, tint: tint)
                }

                HStack(spacing: 10) {
                    compactStat(title: "진행", value: "Day \(dayIndex) / \(plan.totalDays)")
                    compactStat(title: "완료", value: "\(Int(plan.progress * 100))%")
                }

                Text(nextText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    Text("\(plan.remainingDays)일 남음")
                    if counts.missed > 0 {
                        Text("놓친 필사 \(counts.missed)개")
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
        }
    }

    private func compactStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(GardenTheme.softFill)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statusBadge(_ status: ScriptureWritingPlanStatus, tint: Color) -> some View {
        Text(status.badgeTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
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
