import Foundation
import SwiftData

enum PlanAssignmentState: String, CaseIterable {
    case pending
    case completed
    case missed
}

@Model
final class PlanDayAssignment {
    @Attribute(.unique) var id: UUID
    var planLocalId: UUID
    var ownerUserId: String
    var remoteDocumentId: String?
    var lastSyncedAt: Date?
    var dayIndex: Int
    var date: Date
    var book: String
    var startChapter: Int
    var startVerse: Int
    var endChapter: Int
    var endVerse: Int
    var verseCount: Int
    var stateRaw: String
    var completedAt: Date?
    var completionRecordIdsRaw: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        planLocalId: UUID,
        ownerUserId: String = "",
        remoteDocumentId: String? = nil,
        lastSyncedAt: Date? = nil,
        dayIndex: Int,
        date: Date,
        book: String,
        startChapter: Int,
        startVerse: Int,
        endChapter: Int,
        endVerse: Int,
        verseCount: Int,
        state: PlanAssignmentState = .pending,
        completedAt: Date? = nil,
        completionRecordIds: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.planLocalId = planLocalId
        self.ownerUserId = ownerUserId
        self.remoteDocumentId = remoteDocumentId
        self.lastSyncedAt = lastSyncedAt
        self.dayIndex = dayIndex
        self.date = date
        self.book = book
        self.startChapter = startChapter
        self.startVerse = startVerse
        self.endChapter = endChapter
        self.endVerse = endVerse
        self.verseCount = verseCount
        self.stateRaw = state.rawValue
        self.completedAt = completedAt
        self.completionRecordIdsRaw = completionRecordIds.joined(separator: "|")
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var state: PlanAssignmentState {
        get { PlanAssignmentState(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }

    var completionRecordIds: [String] {
        get {
            guard !completionRecordIdsRaw.isEmpty else { return [] }
            return completionRecordIdsRaw.split(separator: "|").map(String.init)
        }
        set {
            completionRecordIdsRaw = newValue.joined(separator: "|")
        }
    }
}

extension Array where Element == PlanDayAssignment {
    func assignments(for userID: String?) -> [PlanDayAssignment] {
        guard let userID else { return [] }
        return filter { $0.ownerUserId == userID }
    }
}
