import Foundation
import SwiftData

@Model
final class BibleVerse {
    @Attribute(.unique) var id: String
    var book: String
    var chapter: Int
    var verse: Int
    var text: String

    init(id: String, book: String, chapter: Int, verse: Int, text: String) {
        self.id = id
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.text = text
    }
}
