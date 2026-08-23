import SwiftUI

struct VerseDetailView: View {
    @EnvironmentObject private var likedVerseStore: LikedVerseStore
    @EnvironmentObject private var gardenActivityStore: GardenActivityStore
    @State private var verse: LocalBibleVerse
    private let service = BibleDataService.shared

    init(verse: LocalBibleVerse) {
        _verse = State(initialValue: verse)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                verseCard
                actionSection
                sourceCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("말씀")
        .navigationBarTitleDisplayMode(.inline)
        .background(GardenTheme.background)
        .onAppear {
            recordVerseRead()
        }
        .onChange(of: verse.id) { _, _ in
            recordVerseRead()
        }
    }

    private var verseCard: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.22), AppColors.cardTint.opacity(0.62)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verse.referenceText)
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundStyle(Color(hex: 0x7C4A45))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(Color(hex: 0xF7EFEE))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(Color(hex: 0x8E5A55, opacity: 0.08), lineWidth: 0.8)
                        }

                    Rectangle()
                        .fill(Color(hex: 0x8E5A55, opacity: 0.14))
                        .frame(width: 44, height: 0.8)
                        .padding(.leading, 2)
                }

                Text(verse.text)
                    .font(.system(size: 24, weight: .regular, design: .serif))
                    .foregroundStyle(AppColors.primaryText)
                    .lineSpacing(10)
                    .fixedSize(horizontal: false, vertical: true)

                Text(BibleDataService.translationSourceTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText)

                verseNavigationControls
            }
        }
    }

    private var verseNavigationControls: some View {
        HStack(spacing: 10) {
            verseNavigationButton(
                title: "이전 구절",
                icon: "chevron.left",
                target: previousVerse
            )

            verseNavigationButton(
                title: "다음 구절",
                icon: "chevron.right",
                target: nextVerse,
                iconTrailing: true
            )
        }
    }

    private var actionSection: some View {
        VStack(spacing: 10) {
            Button {
                likedVerseStore.toggleLike(verse)
            } label: {
                detailActionLabel(
                    title: isCurrentVerseLiked ? "저장됨" : "좋아요",
                    subtitle: isCurrentVerseLiked ? "내가 저장한 말씀에 담겨 있습니다." : "마음에 남는 말씀을 보관합니다.",
                    icon: isCurrentVerseLiked ? "heart.fill" : "heart",
                    tint: isCurrentVerseLiked ? GardenTheme.tertiary : GardenTheme.primary
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                WriteView(localVerse: verse)
            } label: {
                detailActionLabel(
                    title: "필사하기",
                    subtitle: "이 말씀을 따라 쓰며 묵상합니다.",
                    icon: "pencil.line",
                    tint: GardenTheme.primary
                )
            }
            .buttonStyle(.plain)

            ShareLink(item: verse.shareText) {
                detailActionLabel(
                    title: "공유하기",
                    subtitle: "말씀 reference와 본문을 함께 공유합니다.",
                    icon: "square.and.arrow.up",
                    tint: GardenTheme.secondary
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var sourceCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 8) {
                GardenSectionHeader("본문 정보", subtitle: "좋아요는 verseId 기준으로 저장됩니다.")
                Text("verseId: \(verse.id)")
                    .font(.caption.monospaced())
                    .foregroundStyle(AppColors.secondaryText)
                    .textSelection(.enabled)
            }
        }
    }

    private var isCurrentVerseLiked: Bool {
        likedVerseStore.isLiked(verse)
    }

    private var previousVerse: LocalBibleVerse? {
        service.adjacentVerse(from: verse, offset: -1)
    }

    private var nextVerse: LocalBibleVerse? {
        service.adjacentVerse(from: verse, offset: 1)
    }

    private func recordVerseRead() {
        gardenActivityStore.addActivity(
            type: .verseRead,
            title: GardenActivityType.verseRead.displayTitle,
            verseId: verse.id,
            reference: verse.referenceText,
            contentPreview: verse.text
        )
    }

    private func verseNavigationButton(
        title: String,
        icon: String,
        target: LocalBibleVerse?,
        iconTrailing: Bool = false
    ) -> some View {
        Button {
            guard let target else { return }
            verse = target
        } label: {
            HStack(spacing: 8) {
                if !iconTrailing {
                    Image(systemName: icon)
                        .font(.caption.weight(.bold))
                }

                Text(title)
                    .font(.caption.weight(.bold))

                if iconTrailing {
                    Image(systemName: icon)
                        .font(.caption.weight(.bold))
                }
            }
            .foregroundStyle(target == nil ? AppColors.subtleText : GardenTheme.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 46)
            .background(target == nil ? AppColors.cardTint.opacity(0.62) : GardenTheme.softFill)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(target == nil ? AppColors.border.opacity(0.52) : GardenTheme.primary.opacity(0.16), lineWidth: 0.8)
            }
            .opacity(target == nil ? 0.68 : 1)
        }
        .buttonStyle(.plain)
        .disabled(target == nil)
    }

    private func detailActionLabel(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColors.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(2)
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
