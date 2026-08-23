import Foundation

final class BibleDataService {
    static let shared = BibleDataService()
    static let translationSourceTitle = "성경전서 개역한글"
    private let bibleFileName = "bible_krv_full"

    private lazy var verses: [LocalBibleVerse] = loadVerses()

    private init() {}

    func loadAllVerses() -> [LocalBibleVerse] {
        verses
    }

    func allBooks() -> [String] {
        let ordered = verses.reduce(into: [String]()) { result, verse in
            if !result.contains(verse.book) {
                result.append(verse.book)
            }
        }
        return ordered
    }

    func getBooks(testament: String) -> [String] {
        verses.reduce(into: [String]()) { result, verse in
            guard verse.testament == testament else { return }
            if !result.contains(verse.book) {
                result.append(verse.book)
            }
        }
    }

    func getChapters(book: String) -> [Int] {
        let chapterSet = Set(verses.filter { $0.book == book }.map(\.chapter))
        return chapterSet.sorted()
    }

    func getVerses(book: String, chapter: Int) -> [LocalBibleVerse] {
        verses
            .filter { $0.book == book && $0.chapter == chapter }
            .sorted { $0.verse < $1.verse }
    }

    func getVerse(book: String, chapter: Int, verse: Int) -> LocalBibleVerse? {
        verses.first { item in
            item.book == book && item.chapter == chapter && item.verse == verse
        }
    }

    func getVerse(id: String) -> LocalBibleVerse? {
        verses.first { $0.id == id }
    }

    func getVerse(reference: String) -> LocalBibleVerse? {
        let compactReference = reference.compactedBibleReference
        guard !compactReference.isEmpty else { return nil }

        return verses.first { verse in
            verse.referenceText.compactedBibleReference == compactReference
        }
    }

    func getVerses(ids: [String]) -> [LocalBibleVerse] {
        let versesById = Dictionary(uniqueKeysWithValues: verses.map { ($0.id, $0) })
        return ids.compactMap { versesById[$0] }
    }

    func getVerseRange(startId: String, endId: String) -> [LocalBibleVerse] {
        guard let startVerse = getVerse(id: startId),
              let endVerse = getVerse(id: endId),
              startVerse.book == endVerse.book,
              startVerse.chapter == endVerse.chapter,
              startVerse.verse <= endVerse.verse else {
            return []
        }

        return verses
            .filter { verse in
                verse.book == startVerse.book
                    && verse.chapter == startVerse.chapter
                    && verse.verse >= startVerse.verse
                    && verse.verse <= endVerse.verse
            }
            .sorted { $0.verse < $1.verse }
    }

    func adjacentVerse(from verse: LocalBibleVerse, offset: Int) -> LocalBibleVerse? {
        guard offset != 0 else { return verse }
        guard let currentIndex = verses.firstIndex(where: { $0.id == verse.id }) else {
            return nil
        }

        let targetIndex = currentIndex + offset
        guard verses.indices.contains(targetIndex) else {
            return nil
        }

        return verses[targetIndex]
    }

    func firstVerse(book: String, chapter: Int? = nil) -> LocalBibleVerse? {
        if let chapter {
            return getVerses(book: book, chapter: chapter).first
        }
        return verses.first { $0.book == book }
    }

    func searchVerses(query: String, limit: Int = 40) -> [LocalBibleVerse] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return [] }
        let compactQuery = normalizedQuery
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "장", with: ":")
            .replacingOccurrences(of: "절", with: "")

        return verses
            .lazy
            .filter { verse in
                let compactReference = verse.referenceText.replacingOccurrences(of: " ", with: "")
                let compactShortReference = "\(String(verse.book.prefix(1)))\(verse.chapter):\(verse.verse)"
                return verse.text.localizedCaseInsensitiveContains(normalizedQuery)
                    || verse.book.localizedCaseInsensitiveContains(normalizedQuery)
                    || verse.referenceText.localizedCaseInsensitiveContains(normalizedQuery)
                    || compactReference.localizedCaseInsensitiveContains(compactQuery)
                    || compactShortReference.localizedCaseInsensitiveContains(compactQuery)
            }
            .prefix(limit)
            .map { $0 }
    }

    func adjacentChapter(book: String, chapter: Int, offset: Int) -> (book: String, chapter: Int)? {
        guard offset != 0 else { return (book, chapter) }
        let books = allBooks()
        guard let bookIndex = books.firstIndex(of: book) else { return nil }
        let chapters = getChapters(book: book)

        if let chapterIndex = chapters.firstIndex(of: chapter) {
            let nextChapterIndex = chapterIndex + offset
            if chapters.indices.contains(nextChapterIndex) {
                return (book, chapters[nextChapterIndex])
            }
        }

        let nextBookIndex = bookIndex + (offset > 0 ? 1 : -1)
        guard books.indices.contains(nextBookIndex) else { return nil }
        let nextBook = books[nextBookIndex]
        let nextBookChapters = getChapters(book: nextBook)
        guard let nextChapter = offset > 0 ? nextBookChapters.first : nextBookChapters.last else {
            return nil
        }
        return (nextBook, nextChapter)
    }

    func books(in testament: BibleTestament) -> [String] {
        getBooks(testament: testament.rawValue)
    }

    func chapters(in book: String) -> [Int] {
        getChapters(book: book)
    }

    func verses(in book: String, chapter: Int) -> [LocalBibleVerse] {
        getVerses(book: book, chapter: chapter)
    }

    func verse(book: String, chapter: Int, verse: Int) -> LocalBibleVerse? {
        getVerse(book: book, chapter: chapter, verse: verse)
    }

    private func loadVerses() -> [LocalBibleVerse] {
        guard let url = Bundle.main.url(forResource: bibleFileName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([BundleBibleVerse].self, from: data) else {
            return []
        }

        return decoded.map { item in
            return LocalBibleVerse(
                book: item.book,
                chapter: item.chapter,
                verse: item.verse,
                testament: item.testament,
                text: item.text
            )
        }
    }
}

private struct BundleBibleVerse: Decodable {
    let book: String
    let chapter: Int
    let verse: Int
    let testament: String
    let text: String
}

private extension String {
    var compactedBibleReference: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "장", with: ":")
            .replacingOccurrences(of: "절", with: "")
    }
}
