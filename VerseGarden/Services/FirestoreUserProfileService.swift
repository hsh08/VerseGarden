import FirebaseAuth
import FirebaseFirestore
import Foundation

struct FirestoreUserProfileService {
    private var database: Firestore { Firestore.firestore() }

    func ensureProfile(for user: User) async throws -> UserProfile {
        let userID = user.uid
        guard !userID.isEmpty, Auth.auth().currentUser?.uid == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let document = database.collection("users").document(userID)
        let snapshot = try await getDocument(document)

        if snapshot.exists, let profile = profile(from: snapshot, fallbackUser: user) {
            return profile
        }

        let nickname = defaultNickname(for: user)
        let data: [String: Any] = [
            "email": user.email ?? "",
            "nickname": nickname,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await setData(document, data: data, merge: true)
        try await syncDisplayNameIfNeeded(nickname: nickname, for: user)

        let createdSnapshot = try await getDocument(document)
        return profile(from: createdSnapshot, fallbackUser: user)
            ?? UserProfile(id: userID, email: user.email ?? "", nickname: nickname, createdAt: Date(), updatedAt: Date())
    }

    func updateNickname(_ nickname: String, for user: User) async throws -> UserProfile {
        let userID = user.uid
        guard !userID.isEmpty, Auth.auth().currentUser?.uid == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = database.collection("users").document(userID)
        let data: [String: Any] = [
            "email": user.email ?? "",
            "nickname": trimmedNickname,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await setData(document, data: data, merge: true)
        try await syncDisplayNameIfNeeded(nickname: trimmedNickname, for: user)

        let snapshot = try await getDocument(document)
        return profile(from: snapshot, fallbackUser: user)
            ?? UserProfile(id: userID, email: user.email ?? "", nickname: trimmedNickname, createdAt: Date(), updatedAt: Date())
    }

    private func defaultNickname(for user: User) -> String {
        if let displayName = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !displayName.isEmpty {
            return displayName
        }

        if let localPart = user.email?.split(separator: "@").first, !localPart.isEmpty {
            return String(localPart)
        }

        return "VerseGarden 사용자"
    }

    private func profile(from snapshot: DocumentSnapshot, fallbackUser: User) -> UserProfile? {
        guard let data = snapshot.data() else { return nil }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
        let nickname = (data["nickname"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = (data["email"] as? String) ?? fallbackUser.email ?? ""

        return UserProfile(
            id: snapshot.documentID,
            email: email,
            nickname: (nickname?.isEmpty == false ? nickname! : defaultNickname(for: fallbackUser)),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func getDocument(_ document: DocumentReference) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentSnapshot, Error>) in
            document.getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: FirestoreSyncError.invalidSnapshot)
                }
            }
        }
    }

    private func setData(_ document: DocumentReference, data: [String: Any], merge: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.setData(data, merge: merge) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func syncDisplayNameIfNeeded(nickname: String, for user: User) async throws {
        guard user.displayName != nickname else { return }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let request = user.createProfileChangeRequest()
            request.displayName = nickname
            request.commitChanges { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
