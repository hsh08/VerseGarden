import SwiftData
import SwiftUI

struct WritingPlanSelectorView: View {
    @Environment(\.dismiss) private var dismiss

    let plans: [ScriptureWritingPlan]
    let selectedPlan: ScriptureWritingPlan?
    let assignments: [PlanDayAssignment]
    let userID: String?
    let onSelect: (ScriptureWritingPlan) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    GardenSectionHeader("필사 플랜 선택", subtitle: "Home에 보여줄 오늘의 필사 플랜을 고르세요.")

                    if plans.isEmpty {
                        EmptyStateView(
                            icon: "folder",
                            title: "진행 중인 필사 플랜이 없어요",
                            message: "필사 플랜을 만들면 Home에서 오늘 분량을 바로 확인할 수 있어요."
                        )
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                                Button {
                                    onSelect(plan)
                                    dismiss()
                                } label: {
                                    planRow(plan, index: index)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("플랜 선택")
            .navigationBarTitleDisplayMode(.inline)
            .background(GardenTheme.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func planRow(_ plan: ScriptureWritingPlan, index: Int) -> some View {
        let todayAssignment = ScriptureWritingPlanService.todayAssignment(
            for: plan,
            assignments: assignments,
            userID: userID
        )
        let completedCount = todayAssignment?.completionRecordIds.count ?? 0
        let verseCount = todayAssignment?.verseCount ?? 0
        let progress = verseCount > 0 ? min(Double(completedCount) / Double(verseCount), 1) : 0
        let isSelected = selectedPlan?.id == plan.id

        return HStack(spacing: 14) {
            WritingPlanFolderIcon(
                color: folderColor(for: plan, index: index),
                isSelected: isSelected
            )
            .frame(width: 54, height: 42)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundStyle(AppColors.primaryText)
                        .lineLimit(1)

                    if isSelected {
                        Text("선택됨")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(GardenTheme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(GardenTheme.primary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(todayAssignment.map { "오늘 \(ScriptureWritingPlanService.rangeText(for: $0))" }
                    ?? "오늘 할당이 없어요")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(1)

                ProgressView(value: progress)
                    .tint(GardenTheme.primary)
                    .scaleEffect(x: 1, y: 0.7, anchor: .center)
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isSelected ? GardenTheme.primary : AppColors.secondaryText)
        }
        .padding(16)
        .gardenCardSurface(
            background: GardenTheme.cardBackground,
            border: isSelected ? GardenTheme.primary.opacity(0.28) : AppColors.border.opacity(0.72),
            cornerRadius: AppRadius.card,
            shadowRadius: 8,
            shadowY: 4
        )
    }
}
