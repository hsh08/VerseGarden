import SwiftUI

struct BibleChapterReadView: View {
    @EnvironmentObject private var likedVerseStore: LikedVerseStore
    let initialBook: String
    let initialChapter: Int

    private let service = BibleDataService.shared
    @State private var book: String
    @State private var chapter: Int

    init(book: String, chapter: Int) {
        self.initialBook = book
        self.initialChapter = chapter
        _book = State(initialValue: book)
        _chapter = State(initialValue: chapter)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                headerCard
                chapterSelector
                verseList
                navigationButtons
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("\(book) \(chapter)장")
        .navigationBarTitleDisplayMode(.inline)
        .background(GardenTheme.background)
    }

    private var headerCard: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.18), AppColors.cardTint.opacity(0.58)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(book) \(chapter)장")
                    .font(.title2.bold())
                    .foregroundStyle(AppColors.primaryText)
                Text("\(verses.count)개 절 · 절을 누르면 말씀 상세로 이동합니다.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }

    private var chapterSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            GardenSectionHeader("장 선택", subtitle: "같은 책 안에서 빠르게 이동할 수 있습니다.")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(service.getChapters(book: book), id: \.self) { item in
                        Button {
                            chapter = item
                        } label: {
                            Text("\(item)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(item == chapter ? .white : GardenTheme.primary)
                                .frame(width: 44, height: 40)
                                .background(item == chapter ? GardenTheme.primary : GardenTheme.softFill)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                                        .stroke(item == chapter ? Color.clear : GardenTheme.softStroke, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var verseList: some View {
        VStack(alignment: .leading, spacing: 10) {
            GardenSectionHeader("본문")

            ForEach(verses) { verse in
                NavigationLink {
                    VerseDetailView(verse: verse)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(verse.verse)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(GardenTheme.primary)
                            .frame(width: 28, height: 28)
                            .background(GardenTheme.softFill)
                            .clipShape(Circle())

                        Text(verse.text)
                            .font(.body)
                            .foregroundStyle(AppColors.primaryText)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)

                        Image(systemName: likedVerseStore.isLiked(verse) ? "heart.fill" : "heart")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(likedVerseStore.isLiked(verse) ? GardenTheme.tertiary : AppColors.subtleText)
                    }
                    .padding(16)
                    .gardenCardSurface(
                        background: GardenTheme.cardBackground,
                        border: AppColors.border.opacity(0.64),
                        cornerRadius: AppRadius.medium,
                        shadowRadius: 6,
                        shadowY: 3
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 10) {
            chapterMoveButton(title: "이전 장", icon: "chevron.left", offset: -1)
            chapterMoveButton(title: "다음 장", icon: "chevron.right", offset: 1)
        }
    }

    private func chapterMoveButton(title: String, icon: String, offset: Int) -> some View {
        let target = service.adjacentChapter(book: book, chapter: chapter, offset: offset)
        return Button {
            if let target {
                book = target.book
                chapter = target.chapter
            }
        } label: {
            HStack {
                if offset < 0 {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.subheadline.weight(.bold))
                if offset > 0 {
                    Image(systemName: icon)
                }
            }
            .foregroundStyle(target == nil ? AppColors.subtleText : GardenTheme.primary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
            .background(target == nil ? AppColors.grassInactive.opacity(0.45) : GardenTheme.softFill)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                    .stroke(AppColors.border.opacity(0.68), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(target == nil)
    }

    private var verses: [LocalBibleVerse] {
        service.getVerses(book: book, chapter: chapter)
    }
}
