import Foundation

final class BibleDataService {
    static let shared = BibleDataService()
    static let translationSourceTitle = "성경전서 개역한글"
    private let bibleFileName = "bible_krv_full"

    private lazy var verses: [LocalBibleVerse] = loadVerses()

    private init() {}

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
