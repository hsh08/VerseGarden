import FirebaseAuth
import FirebaseFirestore
import Foundation

struct FirestoreLikedVerseService {
    private var database: Firestore { Firestore.firestore() }

    func fetchLikedVerses(for userID: String) async throws -> [LikedVerseRecord] {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            database
                .collection("users")
                .document(userID)
                .collection("likedVerses")
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

        return snapshot.documents.map { document in
            let data = document.data()
            return LikedVerseRecord(
                verseId: (data["verseId"] as? String) ?? document.documentID,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            )
        }
    }

    func like(verseId: String, createdAt: Date = Date(), for userID: String) async throws {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              !verseId.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let document = database
            .collection("users")
            .document(userID)
            .collection("likedVerses")
            .document(verseId)

        let data: [String: Any] = [
            "verseId": verseId,
            "createdAt": Timestamp(date: createdAt)
        ]

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

    func unlike(verseId: String, for userID: String) async throws {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              !verseId.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let document = database
            .collection("users")
            .document(userID)
            .collection("likedVerses")
            .document(verseId)

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
