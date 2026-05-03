import Foundation

enum BibleProgressCalculator {
    static func completedVerseSet(
        records: [WritingRecord],
        book: String,
        chapter: Int? = nil
    ) -> Set<Int> {
        Set(
            records
                .filter { record in
                    guard record.book == book else { return false }
                    if let chapter {
                        return record.chapter == chapter
                    }
                    return true
                }
                .map(\.verse)
        )
    }

    static func startedChapterSet(records: [WritingRecord], book: String) -> Set<Int> {
        Set(records.filter { $0.book == book }.map(\.chapter))
    }

    static func completedVerseCount(
        records: [WritingRecord],
        book: String,
        chapter: Int
    ) -> Int {
        completedVerseSet(records: records, book: book, chapter: chapter).count
    }

    static func isChapterFullyCompleted(
        records: [WritingRecord],
        book: String,
        chapter: Int,
        totalVerseCount: Int
    ) -> Bool {
        totalVerseCount > 0 && completedVerseCount(records: records, book: book, chapter: chapter) == totalVerseCount
    }

    static func isBookFullyCompleted(
        records: [WritingRecord],
        book: String,
        chapters: [Int],
        totalVerseCountProvider: (Int) -> Int
    ) -> Bool {
        guard !chapters.isEmpty else { return false }

        return chapters.allSatisfy { chapter in
            isChapterFullyCompleted(
                records: records,
                book: book,
                chapter: chapter,
                totalVerseCount: totalVerseCountProvider(chapter)
            )
        }
    }
}
