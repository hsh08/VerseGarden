import Foundation
import SwiftData

@Model
final class PrayerWritingRecord {
    @Attribute(.unique) var id: UUID
    var ownerUserId: String
    var remoteDocumentId: String?
    var lastSyncedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var date: Date
    var completedAt: Date
    var sourceType: String
    var templateLocalId: UUID?
    var templateRemoteId: String?
    var titleSnapshot: String
    var originalText: String
    var userText: String

    init(
        id: UUID = UUID(),
        ownerUserId: String = "",
        remoteDocumentId: String? = nil,
        lastSyncedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        date: Date,
        completedAt: Date,
        sourceType: String,
        templateLocalId: UUID? = nil,
        templateRemoteId: String? = nil,
        titleSnapshot: String,
        originalText: String,
        userText: String
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.remoteDocumentId = remoteDocumentId
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.date = date
        self.completedAt = completedAt
        self.sourceType = sourceType
        self.templateLocalId = templateLocalId
        self.templateRemoteId = templateRemoteId
        self.titleSnapshot = titleSnapshot
        self.originalText = originalText
        self.userText = userText
    }
}

enum PrayerSourceType: String {
    case userPrayer
    case defaultPrayer
    case freeformPrayer
}

extension Array where Element == PrayerWritingRecord {
    func records(for userID: String?) -> [PrayerWritingRecord] {
        guard let userID, !userID.isEmpty else { return [] }
        return filter { $0.ownerUserId == userID }
    }
}
