import Foundation
import SwiftData

@Model
final class MyVerseList {
    @Attribute(.unique) var id: UUID
    var title: String
    var memo: String
    var ownerUserId: String
    var remoteDocumentId: String?
    var updatedAt: Date
    var lastSyncedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        memo: String,
        ownerUserId: String = "",
        remoteDocumentId: String? = nil,
        updatedAt: Date = Date(),
        lastSyncedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.memo = memo
        self.ownerUserId = ownerUserId
        self.remoteDocumentId = remoteDocumentId
        self.updatedAt = updatedAt
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
    }
}
