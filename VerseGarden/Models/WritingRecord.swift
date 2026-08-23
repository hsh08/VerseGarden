import Foundation
import SwiftData

@Model
final class WritingRecord {
    @Attribute(.unique) var id: UUID
    var ownerUserId: String
    var remoteDocumentId: String?
    var lastSyncedAt: Date?
    var date: Date
    var verseId: String
    var book: String
    var chapter: Int
    var verse: Int
    var originalText: String
    var userText: String
    var completedAt: Date
    var sourceType: String?
    var planId: String?
    var assignmentId: String?
    var planDayIndex: Int?

    init(
        id: UUID = UUID(),
        ownerUserId: String = "",
        remoteDocumentId: String? = nil,
        lastSyncedAt: Date? = nil,
        date: Date,
        verseId: String,
        book: String,
        chapter: Int,
        verse: Int,
        originalText: String,
        userText: String,
        completedAt: Date,
        sourceType: String? = nil,
        planId: String? = nil,
        assignmentId: String? = nil,
        planDayIndex: Int? = nil
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.remoteDocumentId = remoteDocumentId
        self.lastSyncedAt = lastSyncedAt
        self.date = date
        self.verseId = verseId
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.originalText = originalText
        self.userText = userText
        self.completedAt = completedAt
        self.sourceType = sourceType
        self.planId = planId
        self.assignmentId = assignmentId
        self.planDayIndex = planDayIndex
    }
}
