import FirebaseAuth
import SwiftData
import SwiftUI

struct BibleChapterSelectView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    let book: String
    let onSelectVerses: (([LocalBibleVerse]) -> Void)?

    private let service = BibleDataService.shared
    @Query(sort: \WritingRecord.completedAt, order: .reverse) private var records: [WritingRecord]
    private var currentUserRecords: [WritingRecord] {
        records.records(for: authViewModel.currentUser?.uid)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(service.getChapters(book: book), id: \.self) { chapter in
                        VStack(spacing: 8) {
                            NavigationLink {
                                BibleVerseSelectView(book: book, chapter: chapter, onSelectVerses: onSelectVerses)
                            } label: {
                                BibleChapterCard(
                                    chapter: chapter,
                                    verseCount: service.getVerses(book: book, chapter: chapter).count,
                                    completedVerseCount: completedVerseCount(for: chapter)
                                )
                            }
                            .buttonStyle(PressableCardStyle())

                            if onSelectVerses != nil {
                                Button {
                                    addEntireChapter(chapter)
                                } label: {
                                    Text("이 장 전체 추가")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.green)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.green.opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("장 선택")
        .background(Color(.systemGroupedBackground))
    }

    private var startedChapters: Set<Int> {
        BibleProgressCalculator.startedChapterSet(records: currentUserRecords, book: book)
    }

    private var totalChapters: Int {
        service.getChapters(book: book).count
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(book)
                .font(.title2.bold())
            Text("\(totalChapters)장 중 \(startedChapters.count)장 필사")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
    }

    private func completedVerseCount(for chapter: Int) -> Int {
        BibleProgressCalculator.completedVerseCount(records: currentUserRecords, book: book, chapter: chapter)
    }

    private func addEntireChapter(_ chapter: Int) {
        guard let onSelectVerses else { return }
        let verses = service.getVerses(book: book, chapter: chapter)
        guard !verses.isEmpty else { return }
        onSelectVerses(verses)
    }
}
