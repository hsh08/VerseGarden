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
            profile = try await service.ensureProfile(for: user)
        } catch {
            errorMessage = "프로필 정보를 불러오지 못했습니다."
            profile = UserProfile(
                id: user.uid,
                email: user.email ?? "",
                nickname: "",
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

    func clear() {
        profile = nil
        isLoadingProfile = false
        isSaving = false
        errorMessage = nil
        loadedUserID = nil
    }
}
