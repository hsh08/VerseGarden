import Foundation
import SwiftData

@Model
final class MyVerseListItem {
    @Attribute(.unique) var id: UUID
    var listId: UUID
    var book: String
    var chapter: Int
    var verse: Int
    var ownerUserId: String
    var remoteDocumentId: String?
    var updatedAt: Date
    var lastSyncedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        listId: UUID,
        book: String,
        chapter: Int,
        verse: Int,
        ownerUserId: String = "",
        remoteDocumentId: String? = nil,
        updatedAt: Date = Date(),
        lastSyncedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.listId = listId
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.ownerUserId = ownerUserId
        self.remoteDocumentId = remoteDocumentId
        self.updatedAt = updatedAt
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
    }
}
