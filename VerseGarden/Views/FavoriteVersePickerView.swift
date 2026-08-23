import SwiftUI

struct FavoriteVersePickerView: View {
    let selectedVerseID: String?
    let onSelect: (LocalBibleVerse) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchQuery = ""
    @State private var selectedBook: String
    @State private var selectedChapter: Int

    private let service = BibleDataService.shared

    init(selectedVerseID: String?, onSelect: @escaping (LocalBibleVerse) -> Void) {
        self.selectedVerseID = selectedVerseID
        self.onSelect = onSelect

        let firstBook = BibleDataService.shared.allBooks().first ?? "창세기"
        _selectedBook = State(initialValue: firstBook)
        _selectedChapter = State(initialValue: BibleDataService.shared.getChapters(book: firstBook).first ?? 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                headerCard
                searchSection
                browseSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("대표 말씀 선택")
        .navigationBarTitleDisplayMode(.inline)
        .background(GardenTheme.background)
    }

    private var headerCard: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.20), AppColors.cardTint.opacity(0.62)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("삶의 기준이 되는 말씀")
                    .font(.title3.bold())
                    .foregroundStyle(AppColors.primaryText)
                Text("직접 입력하지 않고 실제 성경 데이터에서 선택합니다.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }

    private var searchSection: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                GardenSectionHeader("검색", subtitle: "말씀 내용이나 성경 위치로 검색하세요.")

                TextField("말씀 내용이나 성경 위치로 검색", text: $searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(GardenTheme.softFill)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                            .stroke(AppColors.border.opacity(0.8), lineWidth: 1)
                    }

                if trimmedSearchQuery.isEmpty {
                    Text("예: 요한복음 3:16, 요 3:16, 사랑, 평안")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                } else if searchResults.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "검색 결과가 없어요",
                        message: "다른 단어나 장절로 다시 검색해보세요."
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(searchResults) { verse in
                            selectableVerseCard(verse)
                        }
                    }
                }
            }
        }
    }

    private var browseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GardenSectionHeader("책과 장으로 찾기", subtitle: "성경 책과 장을 고른 뒤 대표 말씀을 선택합니다.")

            GardenCard {
                VStack(alignment: .leading, spacing: 14) {
                    Menu {
                        ForEach(service.allBooks(), id: \.self) { book in
                            Button(book) {
                                selectedBook = book
                                selectedChapter = service.getChapters(book: book).first ?? 1
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedBook)
                                .font(.headline)
                                .foregroundStyle(AppColors.primaryText)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        .padding(14)
                        .background(GardenTheme.softFill)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(service.getChapters(book: selectedBook), id: \.self) { chapter in
                                Button {
                                    selectedChapter = chapter
                                } label: {
                                    Text("\(chapter)")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(chapter == selectedChapter ? .white : GardenTheme.primary)
                                        .frame(width: 44, height: 40)
                                        .background(chapter == selectedChapter ? GardenTheme.primary : GardenTheme.softFill)
                                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous)
                                                .stroke(chapter == selectedChapter ? Color.clear : GardenTheme.softStroke, lineWidth: 1)
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            VStack(spacing: 10) {
                ForEach(browsedVerses) { verse in
                    selectableVerseCard(verse)
                }
            }
        }
    }

    private func selectableVerseCard(_ verse: LocalBibleVerse) -> some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verse.referenceText)
                            .font(.headline)
                            .foregroundStyle(GardenTheme.secondary)
                        Text(verse.text)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.primaryText)
                            .lineSpacing(4)
                            .lineLimit(4)
                    }

                    Spacer(minLength: 10)

                    if selectedVerseID == verse.id {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(GardenTheme.primary)
                    }
                }

                Button {
                    onSelect(verse)
                    dismiss()
                } label: {
                    HStack {
                        Text(selectedVerseID == verse.id ? "선택됨" : "대표 말씀으로 선택")
                            .font(.subheadline.weight(.bold))
                        Spacer()
                        Image(systemName: selectedVerseID == verse.id ? "checkmark" : "plus")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(selectedVerseID == verse.id ? AppColors.secondaryText : .white)
                    .frame(minHeight: 46)
                    .padding(.horizontal, 14)
                    .background(selectedVerseID == verse.id ? GardenTheme.softFill : GardenTheme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var trimmedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResults: [LocalBibleVerse] {
        service.searchVerses(query: trimmedSearchQuery, limit: 20)
    }

    private var browsedVerses: [LocalBibleVerse] {
        service.getVerses(book: selectedBook, chapter: selectedChapter)
    }
}
