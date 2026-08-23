import FirebaseAuth
import FirebaseFirestore
import Foundation

struct FirestoreVerseListService {
    private var database: Firestore { Firestore.firestore() }

    func fetchLists(for userID: String) async throws -> [MyVerseList] {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let listSnapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            database
                .collection("users")
                .document(userID)
                .collection("verseLists")
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

        return listSnapshot.documents.compactMap { document in
            makeList(from: document, userID: userID)
        }
    }

    func createList(from list: MyVerseList, for userID: String) async throws -> String {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let collection = database
            .collection("users")
            .document(userID)
            .collection("verseLists")

        let reference = collection.document()
        let data: [String: Any] = [
            "title": list.title,
            "memo": list.memo,
            "createdAt": Timestamp(date: list.createdAt),
            "updatedAt": Timestamp(date: list.updatedAt),
            "ownerUserId": userID,
            "localId": list.id.uuidString,
            "remoteId": reference.documentID,
            "lastSyncedAt": FieldValue.serverTimestamp()
        ]

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

    func updateList(listRemoteId: String, title: String, memo: String, for userID: String) async throws {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              !listRemoteId.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let document = database
            .collection("users")
            .document(userID)
            .collection("verseLists")
            .document(listRemoteId)

        let data: [String: Any] = [
            "title": title,
            "memo": memo,
            "updatedAt": FieldValue.serverTimestamp(),
            "lastSyncedAt": FieldValue.serverTimestamp()
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

    func deleteList(listRemoteId: String, for userID: String) async throws {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              !listRemoteId.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let listDocument = database
            .collection("users")
            .document(userID)
            .collection("verseLists")
            .document(listRemoteId)

        let itemsSnapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            listDocument.collection("items").getDocuments { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: FirestoreSyncError.invalidSnapshot)
                }
            }
        }

        let batch = database.batch()
        for document in itemsSnapshot.documents {
            batch.deleteDocument(document.reference)
        }
        batch.deleteDocument(listDocument)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func createItem(
        from item: MyVerseListItem,
        for userID: String,
        listRemoteDocumentId: String,
        verseText: String?
    ) async throws -> String {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              !listRemoteDocumentId.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let collection = database
            .collection("users")
            .document(userID)
            .collection("verseLists")
            .document(listRemoteDocumentId)
            .collection("items")

        let reference = collection.document()
        var data: [String: Any] = [
            "ownerUserId": userID,
            "listLocalId": item.listId.uuidString,
            "localId": item.id.uuidString,
            "remoteDocumentId": reference.documentID,
            "book": item.book,
            "chapter": item.chapter,
            "verse": item.verse,
            "createdAt": Timestamp(date: item.createdAt),
            "updatedAt": Timestamp(date: item.updatedAt),
            "lastSyncedAt": FieldValue.serverTimestamp()
        ]

        if let verseText, !verseText.isEmpty {
            data["verseText"] = verseText
        }

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

    func deleteItem(listId: String, itemId: String, for userID: String) async throws {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              !listId.isEmpty,
              !itemId.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let document = database
            .collection("users")
            .document(userID)
            .collection("verseLists")
            .document(listId)
            .collection("items")
            .document(itemId)

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

    func fetchItems(userId: String, listRemoteId: String, localListId: UUID) async throws -> [MyVerseListItem] {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userId.isEmpty,
              !listRemoteId.isEmpty,
              currentUID == userId else {
            throw FirestoreSyncError.notAuthenticated
        }

        let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            database
                .collection("users")
                .document(userId)
                .collection("verseLists")
                .document(listRemoteId)
                .collection("items")
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

        let items: [MyVerseListItem] = snapshot.documents.compactMap { document in
            let data = document.data()

            guard let book = data["book"] as? String,
                  let chapter = data["chapter"] as? Int,
                  let verse = data["verse"] as? Int,
                  let createdAtTimestamp = data["createdAt"] as? Timestamp,
                  let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
                return nil
            }

            return MyVerseListItem(
                id: (data["localId"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID(),
                listId: localListId,
                book: book,
                chapter: chapter,
                verse: verse,
                ownerUserId: (data["ownerUserId"] as? String) ?? userId,
                remoteDocumentId: document.documentID,
                updatedAt: updatedAtTimestamp.dateValue(),
                lastSyncedAt: (data["lastSyncedAt"] as? Timestamp)?.dateValue() ?? Date(),
                createdAt: createdAtTimestamp.dateValue()
            )
        }

        return items
    }

    private func makeList(from document: QueryDocumentSnapshot, userID: String) -> MyVerseList? {
        let data = document.data()

        guard let title = data["title"] as? String,
              let ownerUserId = data["ownerUserId"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp,
              let updatedAtTimestamp = data["updatedAt"] as? Timestamp else {
            return nil
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, ownerUserId == userID else {
            return nil
        }

        return MyVerseList(
            id: (data["localId"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID(),
            title: trimmedTitle,
            memo: (data["memo"] as? String) ?? "",
            ownerUserId: ownerUserId,
            remoteDocumentId: document.documentID,
            updatedAt: updatedAtTimestamp.dateValue(),
            lastSyncedAt: (data["lastSyncedAt"] as? Timestamp)?.dateValue() ?? Date(),
            createdAt: createdAtTimestamp.dateValue()
        )
    }
}
