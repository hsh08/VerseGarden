import Foundation
import SwiftData

@Model
final class PrayerTemplate {
    @Attribute(.unique) var id: UUID
    var ownerUserId: String
    var remoteDocumentId: String?
    var lastSyncedAt: Date?
    var createdAt: Date
    var updatedAt: Date
    var title: String
    var bodyText: String
    var category: String?
    var isDefaultTemplate: Bool
    var defaultTemplateID: String?
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        ownerUserId: String = "",
        remoteDocumentId: String? = nil,
        lastSyncedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        title: String,
        bodyText: String,
        category: String? = nil,
        isDefaultTemplate: Bool = false,
        defaultTemplateID: String? = nil,
        isArchived: Bool = false
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.remoteDocumentId = remoteDocumentId
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.title = title
        self.bodyText = bodyText
        self.category = category
        self.isDefaultTemplate = isDefaultTemplate
        self.defaultTemplateID = defaultTemplateID
        self.isArchived = isArchived
    }
}

extension Array where Element == PrayerTemplate {
    func userTemplates(for userID: String?) -> [PrayerTemplate] {
        guard let userID, !userID.isEmpty else { return [] }
        return filter { !$0.isDefaultTemplate && $0.ownerUserId == userID && !$0.isArchived }
    }

    var defaultTemplates: [PrayerTemplate] {
        filter { $0.isDefaultTemplate && !$0.isArchived }
    }
}
