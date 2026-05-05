import Combine
import FirebaseAuth
import SwiftData
import SwiftUI

@MainActor
final class WritingRecordSyncCoordinator: ObservableObject {
    @Published private(set) var isSyncing = false

    private let service = FirestoreWritingRecordService()
    private var activeUserId: String?

    func syncForAuthenticatedUser(userID: String?, modelContext: ModelContext) async {
        guard let userID, !userID.isEmpty else {
            return
        }

        guard let userID = validatedCurrentUserID(for: userID) else {
            stopSync()  
            return
        }

        activeUserId = userID
        isSyncing = true

        do {
            try assignLegacyRecords(to: userID, modelContext: modelContext)
            let remoteRecords: [WritingRecord] = try await service.fetchRecords(for: userID)
            try reconcile(remoteRecords: remoteRecords, userID: userID, modelContext: modelContext)
            try await uploadPendingRecords(for: userID, modelContext: modelContext)
        } catch {}

        isSyncing = false
    }

    func uploadRecordIfNeeded(localRecordID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }
        guard activeUserId == userID else { return }

        do {
            guard let record = try fetchAllRecords(modelContext: modelContext).first(where: { $0.id == localRecordID }) else {
                return
            }
            guard record.ownerUserId == userID, record.remoteDocumentId == nil else { return }
            try await upload(record: record, userID: userID, modelContext: modelContext)
        } catch {}
    }

    func deleteRecordIfNeeded(remoteDocumentId: String?, ownerUserId: String, userID: String?) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }
        guard activeUserId == userID else { return }
        guard ownerUserId == userID, let remoteDocumentId, !remoteDocumentId.isEmpty else { return }

        do {
            try await service.deleteRecord(recordId: remoteDocumentId, for: userID)
        } catch {}
    }

    func stopSync() {
        activeUserId = nil
        isSyncing = false
    }

    private func validatedCurrentUserID(for userID: String?) -> String? {
        guard let currentUID = Auth.auth().currentUser?.uid,
              let userID,
              !userID.isEmpty,
              currentUID == userID else {
            return nil
        }

        return userID
    }

    private func assignLegacyRecords(to userID: String, modelContext: ModelContext) throws {
        let records = try fetchAllRecords(modelContext: modelContext)
        let legacyRecords = records.filter { $0.ownerUserId.isEmpty }

        guard !legacyRecords.isEmpty else { return }

        for record in legacyRecords {
            record.ownerUserId = userID
        }

        try modelContext.save()
    }

    private func reconcile(
        remoteRecords: [WritingRecord],
        userID: String,
        modelContext: ModelContext
    ) throws {
        let localRecords = try fetchAllRecords(modelContext: modelContext).filter { $0.ownerUserId == userID }
        var localByRemoteDocumentId: [String: WritingRecord] = [:]
        var localByDuplicateKey: [String: WritingRecord] = [:]

        for record in localRecords {
            if let remoteDocumentId = record.remoteDocumentId {
                localByRemoteDocumentId[remoteDocumentId] = record
            }
            localByDuplicateKey[duplicateKey(for: record)] = record
        }

        var didChange = false

        for remoteRecord in remoteRecords {
            guard let remoteDocumentID = remoteRecord.remoteDocumentId else { continue }

            if let existing = localByRemoteDocumentId[remoteDocumentID] {
                if existing.lastSyncedAt == nil {
                    existing.lastSyncedAt = Date()
                    didChange = true
                }
                continue
            }

            let remoteKey = duplicateKey(for: remoteRecord)
            if let matchingLocal = localByDuplicateKey[remoteKey] {
                if matchingLocal.remoteDocumentId == nil {
                    matchingLocal.remoteDocumentId = remoteDocumentID
                    matchingLocal.lastSyncedAt = Date()
                    didChange = true
                }
                continue
            }

            let newRecord = WritingRecord(
                id: remoteRecord.id,
                ownerUserId: userID,
                remoteDocumentId: remoteDocumentID,
                lastSyncedAt: Date(),
                date: remoteRecord.date,
                verseId: remoteRecord.verseId,
                book: remoteRecord.book,
                chapter: remoteRecord.chapter,
                verse: remoteRecord.verse,
                originalText: remoteRecord.originalText,
                userText: remoteRecord.userText,
                completedAt: remoteRecord.completedAt,
                sourceType: remoteRecord.sourceType
            )
            modelContext.insert(newRecord)
            localByRemoteDocumentId[remoteDocumentID] = newRecord
            localByDuplicateKey[remoteKey] = newRecord
            didChange = true
        }

        if didChange {
            try modelContext.save()
        }
    }

    private func uploadPendingRecords(for userID: String, modelContext: ModelContext) async throws {
        let pendingRecords = try fetchAllRecords(modelContext: modelContext).filter {
            $0.ownerUserId == userID && $0.remoteDocumentId == nil
        }

        for record in pendingRecords {
            try await upload(record: record, userID: userID, modelContext: modelContext)
        }
    }

    private func upload(record: WritingRecord, userID: String, modelContext: ModelContext) async throws {
        guard record.remoteDocumentId == nil else { return }

        let remoteDocumentId = try await service.createRecord(from: record, for: userID)
        record.remoteDocumentId = remoteDocumentId
        record.lastSyncedAt = Date()
        try modelContext.save()
    }

    private func fetchAllRecords(modelContext: ModelContext) throws -> [WritingRecord] {
        try modelContext.fetch(FetchDescriptor<WritingRecord>())
    }

    private func duplicateKey(for record: WritingRecord) -> String {
        "\(record.ownerUserId)|\(record.book)|\(record.chapter)|\(record.verse)|\(record.completedAt.timeIntervalSince1970)|\(record.sourceType ?? "")"
    }
}

extension Array where Element == WritingRecord {
    func records(for userID: String?) -> [WritingRecord] {
        guard let userID, !userID.isEmpty else { return [] }
        return filter { $0.ownerUserId == userID }
    }
}
