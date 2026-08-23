import FirebaseAuth
import FirebaseFirestore
import Foundation

struct FirestorePrayerService {
    private var database: Firestore { Firestore.firestore() }

    func fetchPrayerTemplates(for userID: String) async throws -> [PrayerTemplate] {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            database.collection("users")
                .document(userID)
                .collection("prayers")
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

        return snapshot.documents.compactMap { makePrayerTemplate(from: $0, userID: userID) }
    }

    func createPrayerTemplate(from template: PrayerTemplate, for userID: String) async throws -> String {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let collection = database.collection("users").document(userID).collection("prayers")
        let reference = collection.document()
        let data: [String: Any] = [
            "title": template.title,
            "bodyText": template.bodyText,
            "category": template.category as Any,
            "ownerUserId": userID,
            "localId": template.id.uuidString,
            "remoteId": reference.documentID,
            "createdAt": Timestamp(date: template.createdAt),
            "updatedAt": Timestamp(date: template.updatedAt),
            "lastSyncedAt": FieldValue.serverTimestamp(),
            "isArchived": template.isArchived
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

    func updatePrayerTemplate(_ template: PrayerTemplate, for userID: String) async throws {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              currentUID == userID,
              let remoteDocumentId = template.remoteDocumentId,
              !remoteDocumentId.isEmpty else {
            throw FirestoreSyncError.notAuthenticated
        }

        let data: [String: Any] = [
            "title": template.title,
            "bodyText": template.bodyText,
            "category": template.category as Any,
            "updatedAt": FieldValue.serverTimestamp(),
            "lastSyncedAt": FieldValue.serverTimestamp(),
            "isArchived": template.isArchived
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.collection("users").document(userID).collection("prayers").document(remoteDocumentId)
                .setData(data, merge: true) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
        }
    }

    func deletePrayerTemplate(remoteDocumentId: String, for userID: String) async throws {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              !remoteDocumentId.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.collection("users").document(userID).collection("prayers").document(remoteDocumentId)
                .delete { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
        }
    }

    func fetchPrayerWritingRecords(for userID: String) async throws -> [PrayerWritingRecord] {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            database.collection("users")
                .document(userID)
                .collection("prayerWritingRecords")
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

        return snapshot.documents.compactMap { makePrayerRecord(from: $0, userID: userID) }
    }

    func createPrayerWritingRecord(from record: PrayerWritingRecord, for userID: String) async throws -> String {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let collection = database.collection("users").document(userID).collection("prayerWritingRecords")
        let reference = collection.document()
        let data: [String: Any] = [
            "ownerUserId": userID,
            "localId": record.id.uuidString,
            "remoteId": reference.documentID,
            "templateLocalId": record.templateLocalId?.uuidString as Any,
            "templateRemoteId": record.templateRemoteId as Any,
            "sourceType": record.sourceType,
            "titleSnapshot": record.titleSnapshot,
            "originalText": record.originalText,
            "userText": record.userText,
            "date": Timestamp(date: record.date),
            "completedAt": Timestamp(date: record.completedAt),
            "createdAt": Timestamp(date: record.createdAt),
            "updatedAt": Timestamp(date: record.updatedAt),
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

    func updatePrayerWritingRecord(_ record: PrayerWritingRecord, for userID: String) async throws {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              currentUID == userID,
              let remoteDocumentId = record.remoteDocumentId,
              !remoteDocumentId.isEmpty else {
            throw FirestoreSyncError.notAuthenticated
        }

        let data: [String: Any] = [
            "titleSnapshot": record.titleSnapshot,
            "originalText": record.originalText,
            "userText": record.userText,
            "updatedAt": FieldValue.serverTimestamp(),
            "lastSyncedAt": FieldValue.serverTimestamp()
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.collection("users").document(userID).collection("prayerWritingRecords").document(remoteDocumentId)
                .setData(data, merge: true) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
        }
    }

    func deletePrayerWritingRecord(remoteDocumentId: String, for userID: String) async throws {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              !remoteDocumentId.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.collection("users").document(userID).collection("prayerWritingRecords").document(remoteDocumentId)
                .delete { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
        }
    }

    private func makePrayerTemplate(from document: QueryDocumentSnapshot, userID: String) -> PrayerTemplate? {
        let data = document.data()
        guard let title = data["title"] as? String,
              let bodyText = data["bodyText"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else {
            return nil
        }

        return PrayerTemplate(
            id: (data["localId"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID(),
            ownerUserId: (data["ownerUserId"] as? String) ?? userID,
            remoteDocumentId: document.documentID,
            lastSyncedAt: Date(),
            createdAt: createdAt,
            updatedAt: updatedAt,
            title: title,
            bodyText: bodyText,
            category: data["category"] as? String,
            isDefaultTemplate: false,
            defaultTemplateID: nil,
            isArchived: data["isArchived"] as? Bool ?? false
        )
    }

    private func makePrayerRecord(from document: QueryDocumentSnapshot, userID: String) -> PrayerWritingRecord? {
        let data = document.data()
        guard let sourceType = data["sourceType"] as? String,
              let titleSnapshot = data["titleSnapshot"] as? String,
              let originalText = data["originalText"] as? String,
              let userText = data["userText"] as? String,
              let date = (data["date"] as? Timestamp)?.dateValue(),
              let completedAt = (data["completedAt"] as? Timestamp)?.dateValue(),
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else {
            return nil
        }

        return PrayerWritingRecord(
            id: (data["localId"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID(),
            ownerUserId: (data["ownerUserId"] as? String) ?? userID,
            remoteDocumentId: document.documentID,
            lastSyncedAt: Date(),
            createdAt: createdAt,
            updatedAt: updatedAt,
            date: date,
            completedAt: completedAt,
            sourceType: sourceType,
            templateLocalId: (data["templateLocalId"] as? String).flatMap(UUID.init(uuidString:)),
            templateRemoteId: data["templateRemoteId"] as? String,
            titleSnapshot: titleSnapshot,
            originalText: originalText,
            userText: userText
        )
    }
}
