import SwiftUI

struct CommunityDetailView: View {
    @EnvironmentObject private var communityStore: CommunityStore
    @EnvironmentObject private var todayQuietTimeContentStore: TodayQuietTimeContentStore

    private let calendar = Calendar.current

    private var membership: CommunityMembership? {
        communityStore.currentMembership
    }

    private var community: Community? {
        communityStore.currentCommunity
    }

    private var localContent: QTContent {
        QTContent(
            date: Date(),
            calendar: calendar,
            todayVerse: TodayVerseService.todayVerse(date: Date(), calendar: calendar)
        )
    }

    private var resolvedContent: QTContent {
        todayQuietTimeContentStore.content(fallback: localContent)
    }

    private var isCommunityContent: Bool {
        resolvedContent.source == .community
            && resolvedContent.communityId == community?.id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                identityCard
                todayQuietTimeSection
                membershipSection
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.large)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("나의 공동체")
        .navigationBarTitleDisplayMode(.inline)
        .background(GardenTheme.background)
        .task(id: community?.id) {
            await todayQuietTimeContentStore.loadTodayIfNeeded(
                community: community,
                force: true
            )
        }
    }

    private var identityCard: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.28), GardenTheme.tertiary.opacity(0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(GardenTheme.secondary)
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.68))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    Text(community?.name ?? membership?.communityName ?? "나의 공동체")
                        .font(.title3.bold())
                        .foregroundStyle(AppColors.primaryText)
                    if let description = community?.description,
                       !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                            .lineSpacing(4)
                    }
                }
            }
        }
    }

    private var todayQuietTimeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GardenSectionHeader("오늘의 QT", subtitle: "공동체와 같은 말씀으로 하루를 시작해요.")

            GardenCard {
                if isCommunityContent {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(resolvedContent.date.formatted(.dateTime.month().day().weekday(.wide)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryText)
                        Text(resolvedContent.title)
                            .font(.title3.bold())
                            .foregroundStyle(AppColors.primaryText)
                        Text(resolvedContent.reference)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GardenTheme.primary)

                        quietTimeLink(title: "QT 시작하기")
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("오늘은 공동체에서 등록한 QT가 없습니다.", systemImage: "leaf")
                            .font(.headline)
                            .foregroundStyle(AppColors.primaryText)
                        Text("VerseGarden 오늘의 QT를 이용할 수 있습니다.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                        quietTimeLink(title: "오늘의 QT 보기")
                    }
                }
            }
        }
    }

    private var membershipSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GardenSectionHeader("나의 참여 정보")

            GardenCard {
                VStack(spacing: 14) {
                    detailRow(title: "역할", value: membership?.role.displayName ?? "멤버")
                    Divider().overlay(AppColors.border)
                    detailRow(
                        title: "참여일",
                        value: membership?.joinedAt.formatted(date: .abbreviated, time: .omitted) ?? "-"
                    )
                    if let memberCount = community?.memberCount ?? membership?.memberCount {
                        Divider().overlay(AppColors.border)
                        detailRow(title: "함께하는 인원", value: "\(memberCount)명")
                    }
                }
            }
        }
    }

    private func quietTimeLink(title: String) -> some View {
        NavigationLink {
            TodayQuietTimeView(
                todayVerse: TodayVerseService.todayVerse(date: Date(), calendar: calendar),
                planLaunchVerse: nil,
                planLaunchContext: nil,
                isPlanPaused: false,
                isWritingCompleted: false,
                qtContentOverride: resolvedContent
            )
        } label: {
            GardenPrimaryButtonLabel(title: title, icon: "leaf.fill")
        }
        .buttonStyle(.plain)
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.primaryText)
        }
    }
}
