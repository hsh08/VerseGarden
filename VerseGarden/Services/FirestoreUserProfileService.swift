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

        let data: [String: Any] = [
            "uid": userID,
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",
            "nickname": "",
            "onboardingCompleted": false,
            "favoriteVerse": "",
            "favoriteVerseId": "",
            "selectedWritingPlanId": "",
            "selectedTopics": [],
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await setData(document, data: data, merge: true)

        let createdSnapshot = try await getDocument(document)
        return profile(from: createdSnapshot, fallbackUser: user)
            ?? UserProfile(id: userID, email: user.email ?? "", nickname: "", createdAt: Date(), updatedAt: Date())
    }

    func updateNickname(_ nickname: String, for user: User) async throws -> UserProfile {
        let userID = user.uid
        guard !userID.isEmpty, Auth.auth().currentUser?.uid == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = database.collection("users").document(userID)
        let data: [String: Any] = [
            "uid": userID,
            "email": user.email ?? "",
            "displayName": trimmedNickname,
            "nickname": trimmedNickname,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await setData(document, data: data, merge: true)
        try await syncDisplayNameIfNeeded(nickname: trimmedNickname, for: user)

        let snapshot = try await getDocument(document)
        return profile(from: snapshot, fallbackUser: user)
            ?? UserProfile(id: userID, email: user.email ?? "", nickname: trimmedNickname, createdAt: Date(), updatedAt: Date())
    }

    func completeOnboarding(
        selectedTopics: [String],
        favoriteVerse: String,
        for user: User
    ) async throws -> UserProfile {
        let userID = user.uid
        guard !userID.isEmpty, Auth.auth().currentUser?.uid == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let normalizedTopics = Array(Set(selectedTopics.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }))
            .filter { !$0.isEmpty }
            .sorted()
        let trimmedFavoriteVerse = favoriteVerse.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = database.collection("users").document(userID)
        let data: [String: Any] = [
            "uid": userID,
            "email": user.email ?? "",
            "displayName": user.displayName ?? "",
            "onboardingCompleted": true,
            "favoriteVerse": trimmedFavoriteVerse,
            "selectedTopics": normalizedTopics,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await setData(document, data: data, merge: true)

        let snapshot = try await getDocument(document)
        return profile(from: snapshot, fallbackUser: user)
            ?? UserProfile(
                id: userID,
                email: user.email ?? "",
                nickname: user.displayName ?? "",
                onboardingCompleted: true,
                favoriteVerse: trimmedFavoriteVerse,
                selectedTopics: normalizedTopics,
                createdAt: Date(),
                updatedAt: Date()
            )
    }

    func updateFavoriteVerseId(_ verseId: String?, for user: User) async throws -> UserProfile {
        let userID = user.uid
        guard !userID.isEmpty, Auth.auth().currentUser?.uid == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let normalizedVerseId = verseId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let document = database.collection("users").document(userID)
        let data: [String: Any] = [
            "uid": userID,
            "email": user.email ?? "",
            "favoriteVerseId": normalizedVerseId,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await setData(document, data: data, merge: true)

        let snapshot = try await getDocument(document)
        return profile(from: snapshot, fallbackUser: user)
            ?? UserProfile(id: userID, email: user.email ?? "", nickname: "", createdAt: Date(), updatedAt: Date())
    }

    func updateSelectedWritingPlanId(_ planId: String?, for user: User) async throws -> UserProfile {
        let userID = user.uid
        guard !userID.isEmpty, Auth.auth().currentUser?.uid == userID else {
            throw FirestoreSyncError.notAuthenticated
        }

        let normalizedPlanId = planId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let document = database.collection("users").document(userID)
        let data: [String: Any] = [
            "uid": userID,
            "email": user.email ?? "",
            "selectedWritingPlanId": normalizedPlanId,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await setData(document, data: data, merge: true)

        let snapshot = try await getDocument(document)
        return profile(from: snapshot, fallbackUser: user)
            ?? UserProfile(id: userID, email: user.email ?? "", nickname: "", createdAt: Date(), updatedAt: Date())
    }

    private func profile(from snapshot: DocumentSnapshot, fallbackUser: User) -> UserProfile? {
        guard let data = snapshot.data() else { return nil }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAt
        let nickname = ((data["nickname"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let email = (data["email"] as? String) ?? fallbackUser.email ?? ""
        let onboardingCompleted = (data["onboardingCompleted"] as? Bool) ?? false
        let favoriteVerse = ((data["favoriteVerse"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let favoriteVerseId = normalizedOptionalString(data["favoriteVerseId"] as? String)
        let selectedWritingPlanId = normalizedOptionalString(data["selectedWritingPlanId"] as? String)
        let selectedTopics = (data["selectedTopics"] as? [String]) ?? []

        return UserProfile(
            id: snapshot.documentID,
            email: email,
            nickname: nickname,
            onboardingCompleted: onboardingCompleted,
            favoriteVerse: favoriteVerse,
            favoriteVerseId: favoriteVerseId,
            selectedWritingPlanId: selectedWritingPlanId,
            selectedTopics: selectedTopics,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func normalizedOptionalString(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
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
