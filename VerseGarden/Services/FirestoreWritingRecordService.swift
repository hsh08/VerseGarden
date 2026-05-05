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
                sourceType: data["sourceType"] as? String
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

        let collection = database
            .collection("users")
            .document(userID)
            .collection("writingRecords")

        let reference = collection.document()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.setData(data) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        return reference.documentID
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
}

enum FirestoreSyncError: Error {
    case notAuthenticated
    case invalidSnapshot
}
