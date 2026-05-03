import Foundation

enum BibleTestament: String, CaseIterable, Identifiable {
    case old = "old"
    case new = "new"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .old:
            return "구약"
        case .new:
            return "신약"
        }
    }
}

struct LocalBibleVerse: Identifiable, Hashable {
    let id: String
    let book: String
    let chapter: Int
    let verse: Int
    let testament: String
    let text: String

    init(book: String, chapter: Int, verse: Int, testament: String, text: String) {
        self.id = "\(book)-\(chapter)-\(verse)"
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.testament = testament
        self.text = text
    }
}
