import Foundation
import SwiftData

enum ScriptureWritingPlanStatus: String, CaseIterable {
    case active
    case paused
    case completed
    case cancelled

    var isTerminal: Bool {
        self == .completed || self == .cancelled
    }
}

@Model
final class ScriptureWritingPlan {
    @Attribute(.unique) var id: UUID
    var ownerUserId: String
    var remoteDocumentId: String?
    var lastSyncedAt: Date?
    var title: String
    var book: String
    var startChapter: Int
    var endChapter: Int
    var startVerse: Int?
    var endVerse: Int?
    var startDate: Date
    var endDate: Date
    var totalDays: Int
    var totalVerses: Int
    var completedDays: Int
    var folderColorRaw: String?
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        ownerUserId: String = "",
        remoteDocumentId: String? = nil,
        lastSyncedAt: Date? = nil,
        title: String,
        book: String,
        startChapter: Int,
        endChapter: Int,
        startVerse: Int? = nil,
        endVerse: Int? = nil,
        startDate: Date,
        endDate: Date,
        totalDays: Int,
        totalVerses: Int,
        completedDays: Int = 0,
        folderColorRaw: String? = nil,
        status: ScriptureWritingPlanStatus = .active,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ownerUserId = ownerUserId
        self.remoteDocumentId = remoteDocumentId
        self.lastSyncedAt = lastSyncedAt
        self.title = title
        self.book = book
        self.startChapter = startChapter
        self.endChapter = endChapter
        self.startVerse = startVerse
        self.endVerse = endVerse
        self.startDate = startDate
        self.endDate = endDate
        self.totalDays = totalDays
        self.totalVerses = totalVerses
        self.completedDays = completedDays
        self.folderColorRaw = folderColorRaw
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var status: ScriptureWritingPlanStatus {
        get { ScriptureWritingPlanStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var progress: Double {
        guard totalDays > 0 else { return 0 }
        return Double(completedDays) / Double(totalDays)
    }

    var remainingDays: Int {
        max(totalDays - completedDays, 0)
    }
}

extension Array where Element == ScriptureWritingPlan {
    func plans(for userID: String?) -> [ScriptureWritingPlan] {
        guard let userID else { return [] }
        return filter { $0.ownerUserId == userID }
    }
}
