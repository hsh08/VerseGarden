import FirebaseAuth
import SwiftData
import SwiftUI

/// Historical plans stay separate from the daily writing workspace while
/// preserving their route to the existing detail and writing-history views.
struct WritingPlanArchiveView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Query(sort: \ScriptureWritingPlan.updatedAt, order: .reverse) private var plans: [ScriptureWritingPlan]

    private var userID: String? { authViewModel.currentUser?.uid }
    private var grouped: ScriptureWritingPlanService.PlanStatusSections {
        ScriptureWritingPlanService.groupedPlans(from: plans, userID: userID)
    }
    private var archivedPlans: [ScriptureWritingPlan] { grouped.completed + grouped.cancelled }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                archiveIntro

                if !grouped.completed.isEmpty {
                    archiveSection(title: "완료", plans: grouped.completed, status: .completed)
                }

                if !grouped.cancelled.isEmpty {
                    archiveSection(title: "종료", plans: grouped.cancelled, status: .cancelled)
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.vertical, AppSpacing.large)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("지난 필사 플랜")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppColors.scripturePaper.ignoresSafeArea())
    }

    private var archiveIntro: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
            Text("지난 필사 플랜")
                .font(AppTypography.sectionTitle)
                .foregroundStyle(AppColors.textPrimary)
            Text("완료하거나 종료한 플랜과 기록을 다시 확인할 수 있어요.")
                .font(AppTypography.description)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private func archiveSection(
        title: String,
        plans: [ScriptureWritingPlan],
        status: ScriptureWritingPlanStatus
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            VGSectionHeader(title)
            ForEach(plans) { plan in
                NavigationLink { PlanDetailView(plan: plan) } label: {
                    archivePlanRow(plan, status: status)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func archivePlanRow(_ plan: ScriptureWritingPlan, status: ScriptureWritingPlanStatus) -> some View {
        HStack(spacing: AppSpacing.medium) {
            WritingPlanFolderIcon(
                color: folderColor(for: plan, index: archivedPlans.firstIndex(where: { $0.id == plan.id }) ?? 0),
                isSelected: false
            )
            .frame(width: 56, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: AppSpacing.small) {
                    Text(plan.title)
                        .font(AppTypography.description.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Text(status == .completed ? "완료" : "종료")
                        .font(AppTypography.caption)
                        .foregroundStyle(status == .completed ? AppColors.gardenDeep : AppColors.textSecondary)
                        .padding(.horizontal, AppSpacing.small)
                        .padding(.vertical, 4)
                        .background(status == .completed ? AppColors.surfaceSecondary : AppColors.scripturePaperEdge.opacity(0.5))
                        .clipShape(Capsule())
                }
                Text(ScriptureWritingPlanService.planRangeText(for: plan))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text("\(plan.completedDays) / \(plan.totalDays)일 기록")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 68)
        .padding(.horizontal, AppSpacing.medium)
        .background(AppColors.surface.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(AppColors.divider.opacity(0.7), lineWidth: 0.8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plan.title), \(status == .completed ? "완료" : "종료"), \(plan.completedDays) / \(plan.totalDays)일 기록")
    }
}
