import FirebaseAuth
import FirebaseFirestore
import Foundation

struct FirestoreWritingRecordService {
    private var database: Firestore { Firestore.firestore() }

    func fetchRecords(for userID: String) async throws -> [WritingRecord] {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            database
                .collection("users")
                .document(userID)
                .collection("writingRecords")
                .getDocuments { snapshot, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let snapshot {
                        continuation.resume(returning: snapshot)
                    } else {
                        continuation.resume(throwing: FirestoreSyncError.invalidSnapshot)
                    }
                }
        }

        let records: [WritingRecord] = snapshot.documents.compactMap { document in
            let data = document.data()

            guard let dateTimestamp = data["date"] as? Timestamp,
                  let verseId = data["verseId"] as? String,
                  let book = data["book"] as? String,
                  let chapter = data["chapter"] as? Int,
                  let verse = data["verse"] as? Int,
                  let originalText = data["originalText"] as? String,
                  let userText = data["userText"] as? String,
                  let completedAtTimestamp = data["completedAt"] as? Timestamp else {
                return nil
            }

            return WritingRecord(
                id: (data["localId"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID(),
                ownerUserId: (data["ownerUserId"] as? String) ?? userID,
                remoteDocumentId: document.documentID,
                lastSyncedAt: Date(),
                date: dateTimestamp.dateValue(),
                verseId: verseId,
                book: book,
                chapter: chapter,
                verse: verse,
                originalText: originalText,
                userText: userText,
                completedAt: completedAtTimestamp.dateValue(),
                sourceType: data["sourceType"] as? String,
                planId: data["planId"] as? String,
                assignmentId: data["assignmentId"] as? String,
                planDayIndex: data["planDayIndex"] as? Int
            )
        }

        return records
    }

    func createRecord(from record: WritingRecord, for userID: String) async throws -> String {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        var data: [String: Any] = [
            "localId": record.id.uuidString,
            "ownerUserId": userID,
            "date": Timestamp(date: record.date),
            "verseId": record.verseId,
            "book": record.book,
            "chapter": record.chapter,
            "verse": record.verse,
            "originalText": record.originalText,
            "userText": record.userText,
            "completedAt": Timestamp(date: record.completedAt),
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let sourceType = record.sourceType {
            data["sourceType"] = sourceType
        }
        addPlanFields(from: record, to: &data)

        let collection = database
            .collection("users")
            .document(userID)
            .collection("writingRecords")

        let reference: DocumentReference
        if let planDocumentId = deterministicPlanDocumentId(for: record) {
            reference = collection.document(planDocumentId)
        } else {
            reference = collection.document()
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.setData(data, merge: true) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        return reference.documentID
    }

    func updateRecord(_ record: WritingRecord, for userID: String) async throws {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              currentUID == userID,
              let remoteDocumentId = record.remoteDocumentId,
              !remoteDocumentId.isEmpty else {
            throw FirestoreSyncError.notAuthenticated
        }

        var data: [String: Any] = [
            "localId": record.id.uuidString,
            "ownerUserId": userID,
            "date": Timestamp(date: record.date),
            "verseId": record.verseId,
            "book": record.book,
            "chapter": record.chapter,
            "verse": record.verse,
            "originalText": record.originalText,
            "userText": record.userText,
            "completedAt": Timestamp(date: record.completedAt),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let sourceType = record.sourceType {
            data["sourceType"] = sourceType
        }
        addPlanFields(from: record, to: &data)

        let document = database
            .collection("users")
            .document(userID)
            .collection("writingRecords")
            .document(remoteDocumentId)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.setData(data, merge: true) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func deleteRecord(recordId: String, for userID: String) async throws {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              !recordId.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let document = database
            .collection("users")
            .document(userID)
            .collection("writingRecords")
            .document(recordId)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func addPlanFields(from record: WritingRecord, to data: inout [String: Any]) {
        if let planId = normalized(record.planId) {
            data["planId"] = planId
        }
        if let assignmentId = normalized(record.assignmentId) {
            data["assignmentId"] = assignmentId
        }
        if let planDayIndex = record.planDayIndex {
            data["planDayIndex"] = planDayIndex
        }
    }

    private func deterministicPlanDocumentId(for record: WritingRecord) -> String? {
        guard record.sourceType == WritingSourceType.plan.rawValue,
              let planId = normalized(record.planId),
              let assignmentId = normalized(record.assignmentId),
              !record.verseId.isEmpty else {
            return nil
        }

        return [
            "plan",
            planId,
            "assignment",
            assignmentId,
            "verse",
            record.verseId
        ]
        .map(safeDocumentIdComponent)
        .joined(separator: "_")
    }

    private func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func safeDocumentIdComponent(_ value: String) -> String {
        value
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "#", with: "_")
            .replacingOccurrences(of: "?", with: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum FirestoreSyncError: Error {
    case notAuthenticated
    case invalidSnapshot
}
