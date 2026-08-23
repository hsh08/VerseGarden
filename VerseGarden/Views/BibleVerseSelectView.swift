import FirebaseAuth
import SwiftData
import SwiftUI

struct BibleVerseSelectView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    let book: String
    let chapter: Int
    let onSelectVerses: (([LocalBibleVerse]) -> Void)?

    private let service = BibleDataService.shared
    @Query(sort: \WritingRecord.completedAt, order: .reverse) private var records: [WritingRecord]
    @State private var selectedVerseIDs: Set<String> = []
    private var currentUserRecords: [WritingRecord] {
        records.records(for: authViewModel.currentUser?.uid)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                headerCard

                ForEach(versesInChapter) { verse in
                    if onSelectVerses != nil {
                        Button {
                            toggleSelection(for: verse)
                        } label: {
                            BibleVerseCard(
                                verseNumber: verse.verse,
                                previewText: versePreview(for: verse.text),
                                isCompleted: completedVerses.contains(verse.verse),
                                isSelected: selectedVerseIDs.contains(verse.id)
                            )
                        }
                        .buttonStyle(PressableCardStyle())
                    } else {
                        NavigationLink {
                            WriteView(localVerse: verse)
                        } label: {
                            BibleVerseCard(
                                verseNumber: verse.verse,
                                previewText: versePreview(for: verse.text),
                                isCompleted: completedVerses.contains(verse.verse),
                                isSelected: false
                            )
                        }
                        .buttonStyle(PressableCardStyle())
                    }
                }
            }
            .padding()
        }
        .navigationTitle("절 선택")
        .background(GardenTheme.background)
        .safeAreaInset(edge: .bottom) {
            if onSelectVerses != nil, !selectedVerseIDs.isEmpty {
                Button {
                    confirmSelection()
                } label: {
                    Text("\(selectedVerseIDs.count)개 추가하기")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 54)
                        .padding(.horizontal, 18)
                        .background(GardenTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(book) \(chapter)장")
                .font(.title3.bold())
            Text("\(completedVerses.count)개 절 필사 완료 · 필사할 절을 선택하면 바로 작성 화면으로 이동합니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .gardenCardSurface()
    }

    private func versePreview(for text: String) -> String {
        if text.count <= 52 {
            return text
        }
        return String(text.prefix(52)) + "..."
    }

    private var versesInChapter: [LocalBibleVerse] {
        service.getVerses(book: book, chapter: chapter)
    }

    private var completedVerses: Set<Int> {
        BibleProgressCalculator.completedVerseSet(records: currentUserRecords, book: book, chapter: chapter)
    }

    private func toggleSelection(for verse: LocalBibleVerse) {
        if selectedVerseIDs.contains(verse.id) {
            selectedVerseIDs.remove(verse.id)
        } else {
            selectedVerseIDs.insert(verse.id)
        }
    }

    private func confirmSelection() {
        guard let onSelectVerses else { return }
        let selectedVerses = versesInChapter.filter { selectedVerseIDs.contains($0.id) }
        guard !selectedVerses.isEmpty else { return }
        onSelectVerses(selectedVerses)
    }
}
