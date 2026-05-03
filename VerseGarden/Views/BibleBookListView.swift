import FirebaseAuth
import SwiftData
import SwiftUI

struct BibleBookListView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    let testament: String
    let onSelectVerses: (([LocalBibleVerse]) -> Void)?

    private let service = BibleDataService.shared
    @Query(sort: \WritingRecord.completedAt, order: .reverse) private var records: [WritingRecord]
    private var currentUserRecords: [WritingRecord] {
        records.records(for: authViewModel.currentUser?.uid)
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 2)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(service.getBooks(testament: testament), id: \.self) { book in
                        NavigationLink {
                            BibleChapterSelectView(book: book, onSelectVerses: onSelectVerses)
                        } label: {
                            BibleBookCard(
                                title: book,
                                chapterCount: service.getChapters(book: book).count,
                                startedChapterCount: startedChapterCount(for: book),
                                isFullyCompleted: isBookFullyCompleted(book)
                            )
                        }
                        .buttonStyle(PressableCardStyle())
                    }
                }
            }
            .padding()
        }
        .navigationTitle(testament == BibleTestament.old.rawValue ? "구약" : "신약")
        .background(Color(.systemGroupedBackground))
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("필사할 성경을 선택하세요.")
                .font(.title3.bold())
            Text("권별 진행도를 보면서 이어 쓰고 싶은 본문을 골라보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
    }

    private func startedChapterCount(for book: String) -> Int {
        BibleProgressCalculator.startedChapterSet(records: currentUserRecords, book: book).count
    }

    private func isBookFullyCompleted(_ book: String) -> Bool {
        let chapters = service.getChapters(book: book)
        return BibleProgressCalculator.isBookFullyCompleted(
            records: currentUserRecords,
            book: book,
            chapters: chapters,
            totalVerseCountProvider: { chapter in
                service.getVerses(book: book, chapter: chapter).count
            }
        )
    }
}
