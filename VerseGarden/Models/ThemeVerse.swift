import Foundation

struct ThemeVerse: Identifiable, Hashable {
    let id: String
    let theme: String
    let book: String
    let chapter: Int
    let verse: Int
    let reason: String

    init(theme: String, book: String, chapter: Int, verse: Int, reason: String) {
        self.id = "\(theme)-\(book)-\(chapter)-\(verse)"
        self.theme = theme
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.reason = reason
    }
}

struct ThemeItem: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let accentName: String
    let verses: [ThemeVerse]

    init(title: String, description: String, icon: String, accentName: String, verses: [ThemeVerse]) {
        self.id = title
        self.title = title
        self.description = description
        self.icon = icon
        self.accentName = accentName
        self.verses = verses
    }
}
