import FirebaseAuth
import SwiftData
import SwiftUI

/// The Reader's focused plan-and-writing workspace. Existing plan persistence,
/// assignment identity, and writing launch behavior remain in their services.
struct WritingPlanHubView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var likedVerseStore: LikedVerseStore
    @Query(sort: \ScriptureWritingPlan.updatedAt, order: .reverse) private var plans: [ScriptureWritingPlan]
    @Query(sort: \PlanDayAssignment.date, order: .forward) private var assignments: [PlanDayAssignment]
    @Query(sort: \MyVerseList.createdAt, order: .reverse) private var verseLists: [MyVerseList]

    private var userID: String? { authViewModel.currentUser?.uid }
    private var grouped: ScriptureWritingPlanService.PlanStatusSections {
        ScriptureWritingPlanService.groupedPlans(from: plans, userID: userID)
    }
    private var userAssignments: [PlanDayAssignment] { assignments.assignments(for: userID) }
    private var currentPlans: [ScriptureWritingPlan] { grouped.active + grouped.paused }
    private var hasArchivedPlans: Bool { !grouped.completed.isEmpty || !grouped.cancelled.isEmpty }
    private var currentVerseLists: [MyVerseList] { verseLists.lists(for: userID) }
    private var folderPlans: [ScriptureWritingPlan] {
        grouped.active + grouped.paused + grouped.completed + grouped.cancelled
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                intro

                if currentPlans.isEmpty { emptyPlanContent } else { currentPlansSection }
                createPlanEntry

                if hasArchivedPlans { archiveEntry }

                myScripture
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.large)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("필사 플랜")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppColors.scripturePaper.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    CreateWritingPlanView()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("새 필사 플랜 만들기")
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            HStack(alignment: .center, spacing: AppSpacing.medium) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(AppColors.gardenDeep)
                    .frame(width: 54, height: 54)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                            .stroke(AppColors.divider.opacity(0.7), lineWidth: 0.8)
                    }

                VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                    Text("필사 플랜")
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Text("말씀을 천천히 기록하며\n나만의 필사 습관을 만들어보세요.")
                        .font(AppTypography.description)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineSpacing(3)
                }
            }
            Rectangle()
                .fill(AppColors.scriptureAccent.opacity(0.3))
                .frame(height: 1)
        }
    }

    private var currentPlansSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            VGSectionHeader("나의 필사 플랜", subtitle: "지금 이어가고 있는 말씀 필사를 확인해보세요.")
            LazyVStack(spacing: AppSpacing.medium) {
                ForEach(currentPlans) { plan in
                    currentPlanCard(plan)
                }
            }
        }
    }

    @ViewBuilder
    private func currentPlanCard(_ plan: ScriptureWritingPlan) -> some View {
        let target = ScriptureWritingPlanService.todayAssignment(for: plan, assignments: userAssignments, userID: userID)
            ?? ScriptureWritingPlanService.nextIncompleteAssignment(for: plan, assignments: userAssignments, userID: userID)
        let day = ScriptureWritingPlanService.displayDayIndex(for: plan, assignments: userAssignments, userID: userID)

        VGCard(style: .standard) {
            VStack(alignment: .leading, spacing: AppSpacing.medium) {
                NavigationLink { PlanDetailView(plan: plan) } label: {
                    VStack(alignment: .leading, spacing: AppSpacing.medium) {
                        HStack(alignment: .top, spacing: AppSpacing.medium) {
                            WritingPlanFolderIcon(
                                color: folderColor(for: plan, index: folderIndex(for: plan)),
                                isSelected: true
                            )
                            .frame(width: 64, height: 52)
                            .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                                Text("필사 플랜")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.gardenDeep)
                                    .padding(.horizontal, AppSpacing.small)
                                    .padding(.vertical, 5)
                                    .background(AppColors.surfaceSecondary)
                                    .clipShape(Capsule())
                                Text(plan.title)
                                    .font(AppTypography.cardTitle)
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(ScriptureWritingPlanService.planRangeText(for: plan))
                                    .font(AppTypography.description)
                                    .foregroundStyle(AppColors.textSecondary)
                                if plan.status == .paused {
                                    Text("일시정지")
                                        .font(AppTypography.caption)
                                        .foregroundStyle(AppColors.scriptureAccent)
                                        .padding(.horizontal, AppSpacing.small)
                                        .padding(.vertical, 4)
                                        .background(AppColors.scripturePaperEdge.opacity(0.5))
                                        .clipShape(Capsule())
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textTertiary)
                                .padding(.top, AppSpacing.small)
                                .accessibilityHidden(true)
                        }

                        VStack(alignment: .leading, spacing: AppSpacing.small) {
                            HStack {
                                Text("오늘 필사 진행도")
                                    .font(AppTypography.description.weight(.semibold))
                                    .foregroundStyle(AppColors.gardenDeep)
                                Spacer()
                                Text("\(plan.completedDays) / \(plan.totalDays)일 · \(Int(plan.progress * 100))%")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                            ProgressView(value: plan.progress)
                                .tint(AppColors.gardenPrimary)
                                .scaleEffect(x: 1, y: 0.86, anchor: .center)
                            Text("Day \(day) · \(plan.remainingDays)일 남음")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .padding(AppSpacing.medium)
                        .background(AppColors.surfaceSecondary.opacity(0.56))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                                .stroke(AppColors.divider.opacity(0.58), lineWidth: 0.8)
                        }

                        if let target {
                            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                                Text("오늘")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColors.scriptureAccent)
                                Text(ScriptureWritingPlanService.rangeText(for: target))
                                    .font(AppTypography.description.weight(.semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(plan.title) 플랜 상세 및 관리")
                .accessibilityValue("\(day) / \(plan.totalDays)일, \(Int(plan.progress * 100))퍼센트 완료")

                if plan.status == .paused {
                    Label("필사를 재개하면 이어갈 수 있어요", systemImage: "pause.circle")
                        .font(AppTypography.description.weight(.semibold))
                        .foregroundStyle(AppColors.textTertiary)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(AppColors.surfaceSecondary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                .stroke(AppColors.divider.opacity(0.58), lineWidth: 0.8)
                        }
                        .accessibilityLabel("\(plan.title), 일시정지됨. 플랜 상세에서 재개할 수 있습니다")
                } else if let target,
                   let launch = ScriptureWritingPlanService.launchContext(for: target, plan: plan),
                   ScriptureWritingPlanService.canStartAssignment(target, in: plan) {
                    NavigationLink {
                        WriteView(localVerse: launch.verse, sourceType: .plan, writingContext: launch.context)
                    } label: {
                        Label(target.state == .completed ? "필사 완료" : "오늘 필사 이어가기", systemImage: "pencil")
                            .font(AppTypography.description.weight(.semibold))
                            .foregroundStyle(AppColors.gardenDeep)
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .background(AppColors.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                    .stroke(AppColors.divider, lineWidth: 0.8)
                            }
                    }
                    .buttonStyle(GardenAccentButtonStyle())
                    .accessibilityLabel("\(plan.title) 오늘 필사 이어가기")
                }
            }
        }
    }

    private func folderIndex(for plan: ScriptureWritingPlan) -> Int {
        folderPlans.firstIndex(where: { $0.id == plan.id }) ?? 0
    }

    private var emptyPlanContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.medium) {
            Text("진행 중인 필사 플랜이 없어요.")
                .font(AppTypography.cardTitle)
                .foregroundStyle(AppColors.textPrimary)
            Text("책과 장 범위, 시작일, 기간을 정하면 매일의 말씀 분량이 준비됩니다.")
                .font(AppTypography.description)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(3)
        }
        .padding(.vertical, AppSpacing.large)
    }

    private var createPlanEntry: some View {
        NavigationLink { CreateWritingPlanView() } label: {
            Label("새 필사 플랜 만들기", systemImage: "plus")
                .font(AppTypography.description.weight(.semibold))
                .foregroundStyle(currentPlans.isEmpty ? .white : AppColors.gardenDeep)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(currentPlans.isEmpty ? AppColors.gardenDeep : AppColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                        .stroke(currentPlans.isEmpty ? Color.clear : AppColors.divider, lineWidth: 0.8)
                }
        }
        .buttonStyle(GardenAccentButtonStyle())
    }

    private var archiveEntry: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            VGSectionHeader("지난 필사 플랜")
            NavigationLink { WritingPlanArchiveView() } label: {
                HStack(spacing: AppSpacing.medium) {
                    Image(systemName: "archivebox")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.scriptureAccent)
                        .frame(width: 34, height: 34)
                        .background(AppColors.scripturePaperEdge.opacity(0.48))
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("지난 필사 플랜")
                            .font(AppTypography.description.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        Text("완료하거나 종료한 필사 플랜을 확인해보세요.")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 62)
                .padding(.horizontal, AppSpacing.medium)
                .background(AppColors.surface.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                        .stroke(AppColors.divider.opacity(0.72), lineWidth: 0.8)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var myScripture: some View {
        VStack(alignment: .leading, spacing: AppSpacing.small) {
            VGSectionHeader("내 말씀", subtitle: "간직한 말씀과 주제별 목록을 다시 봅니다.")
            NavigationLink { VerseListView() } label: {
                libraryRow(title: "저장한 말씀", detail: "\(likedVerseStore.likedCount)개 저장됨", icon: "heart.fill")
            }
            .buttonStyle(.plain)
            NavigationLink { MyVerseListView() } label: {
                libraryRow(title: "나만의 말씀 목록", detail: "\(currentVerseLists.count)개 목록", icon: "bookmark")
            }
            .buttonStyle(.plain)
        }
    }

    private func planSummaryRow(_ plan: ScriptureWritingPlan, subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title).font(AppTypography.description.weight(.semibold)).foregroundStyle(AppColors.textPrimary)
                Text("\(ScriptureWritingPlanService.planRangeText(for: plan)) · \(subtitle)")
                    .font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .overlay(alignment: .bottom) { Rectangle().fill(AppColors.divider.opacity(0.7)).frame(height: 1) }
    }

    private func libraryRow(title: String, detail: String, icon: String) -> some View {
        HStack(spacing: AppSpacing.medium) {
            Image(systemName: icon).font(.subheadline.weight(.semibold)).foregroundStyle(AppColors.scriptureAccent)
                .frame(width: 32, height: 32).background(AppColors.scriptureAccent.opacity(0.1)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(AppTypography.description.weight(.semibold)).foregroundStyle(AppColors.textPrimary)
                Text(detail).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .overlay(alignment: .bottom) { Rectangle().fill(AppColors.divider.opacity(0.7)).frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
}
