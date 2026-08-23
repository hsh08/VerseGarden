import Combine
import FirebaseAuth
import Foundation

@MainActor
final class UserProfileStore: ObservableObject {
    @Published private(set) var profile: UserProfile?
    @Published private(set) var isLoadingProfile = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?
    @Published private(set) var loadedUserID: String?

    private let service = FirestoreUserProfileService()
    private let defaults = UserDefaults.standard

    var requiresNicknameSetup: Bool {
        guard let profile else { return false }
        return profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines).count < 2
    }

    func hasResolvedProfile(for userID: String?) -> Bool {
        guard let userID, !userID.isEmpty else { return false }
        return loadedUserID == userID
    }

    func syncProfile(for user: User?) async {
        guard let user else {
            clear()
            return
        }

        if loadedUserID != user.uid {
            profile = nil
        }

        loadedUserID = nil
        isLoadingProfile = true
        errorMessage = nil

        do {
            var resolvedProfile = try await service.ensureProfile(for: user)
            if !resolvedProfile.onboardingCompleted, OnboardingState.hasCompleted(userID: user.uid) {
                resolvedProfile = try await service.completeOnboarding(
                    selectedTopics: resolvedProfile.selectedTopics,
                    favoriteVerse: resolvedProfile.favoriteVerse,
                    for: user
                )
            }
            resolvedProfile = try await reconcileFavoriteVerseId(in: resolvedProfile, for: user)
            profile = resolvedProfile
        } catch {
            errorMessage = "프로필 정보를 불러오지 못했습니다."
            profile = UserProfile(
                id: user.uid,
                email: user.email ?? "",
                nickname: "",
                onboardingCompleted: OnboardingState.hasCompleted(userID: user.uid),
                createdAt: Date(),
                updatedAt: Date()
            )
        }

        loadedUserID = user.uid
        isLoadingProfile = false
    }

    func updateNickname(_ nickname: String, for user: User?) async {
        guard let user else { return }

        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else {
            errorMessage = "닉네임을 입력해주세요."
            return
        }

        guard trimmedNickname.count >= 2 else {
            errorMessage = "닉네임은 2자 이상이어야 합니다."
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            profile = try await service.updateNickname(trimmedNickname, for: user)
        } catch {
            errorMessage = "닉네임을 저장하지 못했습니다."
        }

        isSaving = false
    }

    func completeOnboarding(selectedTopics: [String], favoriteVerse: String, for user: User?) async {
        guard let user else { return }

        isSaving = true
        errorMessage = nil

        do {
            let updatedProfile = try await service.completeOnboarding(
                selectedTopics: selectedTopics,
                favoriteVerse: favoriteVerse,
                for: user
            )
            profile = updatedProfile
            OnboardingState.complete(userID: user.uid)
        } catch {
            errorMessage = "온보딩 설정을 저장하지 못했습니다."
        }

        isSaving = false
    }

    func updateFavoriteVerseId(_ verseId: String?, for user: User?) async {
        guard let user else { return }

        let normalizedVerseId = normalizedOptionalString(verseId)
        persistFavoriteVerseId(normalizedVerseId, userID: user.uid)
        errorMessage = nil

        do {
            profile = try await service.updateFavoriteVerseId(normalizedVerseId, for: user)
        } catch {
            errorMessage = "대표 말씀을 동기화하지 못했습니다."
        }
    }

    func syncSelectedWritingPlanPreference(
        selectionStore: WritingPlanSelectionStore,
        for user: User?
    ) async {
        guard let user else { return }

        if let remotePlanId = normalizedOptionalString(profile?.selectedWritingPlanId) {
            selectionStore.applyRemoteSelection(remotePlanId)
            return
        }

        if let localPlanId = normalizedOptionalString(selectionStore.selectedPlanId) {
            await updateSelectedWritingPlanId(localPlanId, for: user)
        }
    }

    func updateSelectedWritingPlanId(_ planId: String?, for user: User?) async {
        guard let user else { return }

        let normalizedPlanId = normalizedOptionalString(planId)
        errorMessage = nil

        do {
            profile = try await service.updateSelectedWritingPlanId(normalizedPlanId, for: user)
        } catch {
            errorMessage = "선택한 필사 플랜을 동기화하지 못했습니다."
        }
    }

    func clear() {
        profile = nil
        isLoadingProfile = false
        isSaving = false
        errorMessage = nil
        loadedUserID = nil
    }

    private func reconcileFavoriteVerseId(in remoteProfile: UserProfile, for user: User) async throws -> UserProfile {
        let remoteVerseId = normalizedOptionalString(remoteProfile.favoriteVerseId)
        let localVerseId = defaults.string(forKey: favoriteVerseStorageKey(userID: user.uid))
            .flatMap(normalizedOptionalString)

        if let remoteVerseId {
            persistFavoriteVerseId(remoteVerseId, userID: user.uid)
            return remoteProfile
        }

        if let localVerseId {
            let updatedProfile = try await service.updateFavoriteVerseId(localVerseId, for: user)
            persistFavoriteVerseId(localVerseId, userID: user.uid)
            return updatedProfile
        }

        return remoteProfile
    }

    private func persistFavoriteVerseId(_ verseId: String?, userID: String) {
        let key = favoriteVerseStorageKey(userID: userID)
        if let verseId = normalizedOptionalString(verseId) {
            defaults.set(verseId, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    private func favoriteVerseStorageKey(userID: String) -> String {
        "favoriteVerseId_\(userID)"
    }

    private func normalizedOptionalString(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
