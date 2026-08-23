import FirebaseAuth
import SwiftData
import SwiftUI

struct PrayerHomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var prayerSyncCoordinator: PrayerSyncCoordinator
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PrayerTemplate.updatedAt, order: .reverse) private var templates: [PrayerTemplate]

    private var currentUserTemplates: [PrayerTemplate] {
        templates.userTemplates(for: authViewModel.currentUser?.uid)
    }

    private var defaultTemplates: [PrayerTemplate] {
        templates.defaultTemplates
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                GardenCard(
                    accentGradient: LinearGradient(
                        colors: [GardenTheme.tertiary.opacity(0.34), GardenTheme.primary.opacity(0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "hands.sparkles.fill")
                            .font(.title3)
                            .foregroundStyle(GardenTheme.tertiary)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.62))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 8) {
                            Text("기도 루틴")
                                .font(.title2.bold())
                                .foregroundStyle(AppColors.primaryText)
                            Text("오늘의 마음을 기도로 정리해보세요.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppColors.secondaryText)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    GardenSectionHeader("바로 시작", subtitle: "오늘의 마음에 맞는 기도 쓰기를 선택하세요.")

                    NavigationLink {
                        PrayerTemplateEditorView()
                    } label: {
                        GardenPrimaryButtonLabel(title: "내 기도문 만들기", icon: "square.and.pencil")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        PrayerTemplateListView()
                    } label: {
                        secondaryPrayerActionLabel(title: "기도문으로 필사", subtitle: "저장한 기도문을 따라 쓰기", icon: "text.book.closed")
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 12) {
                    GardenSectionHeader("내 기도문", subtitle: currentUserTemplates.isEmpty ? "기도문을 심으면 이곳에 모입니다." : "저장한 기도문으로 다시 기도할 수 있습니다.")

                    if currentUserTemplates.isEmpty {
                        prayerEmptyState
                    } else {
                        ForEach(currentUserTemplates.prefix(3)) { template in
                            NavigationLink {
                                PrayerComposerView(template: template)
                            } label: {
                                prayerTemplateCard(template)
                            }
                            .buttonStyle(.plain)
                        }

                        NavigationLink("전체 기도문 보기") {
                            PrayerTemplateListView()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(GardenTheme.primary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    GardenSectionHeader("앱 제공 기도문", subtitle: "차분하게 따라 적을 수 있는 짧은 기본 기도문입니다.")
                    ForEach(defaultTemplates.prefix(3)) { template in
                        NavigationLink {
                            PrayerComposerView(template: template)
                        } label: {
                            prayerTemplateCard(template)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("기도")
        .background(GardenTheme.background)
        .task(id: authViewModel.currentUser?.uid) {
            prayerSyncCoordinator.seedDefaultTemplatesIfNeeded(modelContext: modelContext)
        }
    }

    private func secondaryPrayerActionLabel(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(GardenTheme.primary)
                .frame(width: 40, height: 40)
                .background(GardenTheme.softFill)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColors.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(minHeight: 54)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .gardenCardSurface(
            background: GardenTheme.cardBackground,
            border: AppColors.border.opacity(0.72),
            cornerRadius: AppRadius.button,
            shadowRadius: 8,
            shadowY: 3
        )
    }

    private var prayerEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "leaf.fill")
                .font(.title2)
                .foregroundStyle(GardenTheme.primary)
                .frame(width: 48, height: 48)
                .background(GardenTheme.softFill)
                .clipShape(Circle())

            VStack(spacing: 6) {
                Text("아직 심은 기도문이 없어요")
                    .font(.headline)
                    .foregroundStyle(AppColors.primaryText)
                Text("기도문을 저장하면 다시 꺼내어 필사할 수 있어요.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .gardenCardSurface(
            background: GardenTheme.cardBackground,
            border: AppColors.border.opacity(0.72),
            cornerRadius: AppRadius.card,
            shadowRadius: 8,
            shadowY: 4
        )
    }

    private func prayerTemplateCard(_ template: PrayerTemplate) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .fill((template.isDefaultTemplate ? GardenTheme.tertiary : GardenTheme.primary).opacity(0.13))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: template.isDefaultTemplate ? "sparkles" : "bookmark.fill")
                        .font(.headline)
                        .foregroundStyle(template.isDefaultTemplate ? GardenTheme.tertiary : GardenTheme.primary)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(template.title)
                    .font(.headline)
                    .foregroundStyle(AppColors.primaryText)
                    .lineLimit(1)
                Text(template.bodyText)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(2)
                if let category = template.category, !category.isEmpty {
                    Text(category)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(template.isDefaultTemplate ? GardenTheme.tertiary : GardenTheme.primary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.secondaryText)
        }
        .padding(16)
        .gardenCardSurface(
            background: GardenTheme.cardBackground,
            border: AppColors.border.opacity(0.72),
            cornerRadius: AppRadius.card,
            shadowRadius: 8,
            shadowY: 4
        )
    }
}
