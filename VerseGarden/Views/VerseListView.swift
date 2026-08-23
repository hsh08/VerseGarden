import SwiftUI

struct VerseListView: View {
    @EnvironmentObject private var likedVerseStore: LikedVerseStore
    private let bibleService = BibleDataService.shared

    private var likedVerses: [LocalBibleVerse] {
        bibleService.getVerses(ids: likedVerseStore.getLikedVerseIds())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                headerCard
                likedVerseSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("내가 저장한 말씀")
        .navigationBarTitleDisplayMode(.inline)
        .background(GardenTheme.background)
    }

    private var headerCard: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.22), AppColors.cardTint.opacity(0.64)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundStyle(GardenTheme.tertiary)
                    .frame(width: 46, height: 46)
                    .background(Color.white.opacity(0.66))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text("말씀 보관함")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(GardenTheme.secondary)
                    Text("마음에 남은 말씀을 다시 꺼내보세요.")
                        .font(.headline)
                        .foregroundStyle(AppColors.primaryText)
                    Text("\(likedVerseStore.likedCount)개 저장됨")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    @ViewBuilder
    private var likedVerseSection: some View {
        if likedVerses.isEmpty {
            EmptyStateView(
                icon: "heart",
                title: "아직 저장한 말씀이 없어요",
                message: "마음에 남는 말씀을 좋아요하면 이곳에 모여요."
            )
            .padding(.top, 12)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                GardenSectionHeader("저장한 말씀", subtitle: "최근 좋아요한 말씀부터 표시합니다.")

                VStack(spacing: 10) {
                    ForEach(likedVerses) { verse in
                        likedVerseCard(verse)
                    }
                }
            }
        }
    }

    private func likedVerseCard(_ verse: LocalBibleVerse) -> some View {
        GardenCard {
            HStack(alignment: .top, spacing: 12) {
                NavigationLink {
                    VerseDetailView(verse: verse)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verse.referenceText)
                            .font(.headline)
                            .foregroundStyle(GardenTheme.secondary)
                        Text(verse.text)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.primaryText)
                            .lineSpacing(4)
                            .lineLimit(4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)

                Button {
                    likedVerseStore.unlike(verse)
                } label: {
                    Image(systemName: "heart.fill")
                        .font(.headline)
                        .foregroundStyle(GardenTheme.tertiary)
                        .frame(width: 40, height: 40)
                        .background(GardenTheme.tertiary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("좋아요 취소")
            }
        }
    }
}
