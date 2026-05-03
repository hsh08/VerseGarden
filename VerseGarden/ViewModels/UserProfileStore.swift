import Combine
import FirebaseAuth
import Foundation

@MainActor
final class UserProfileStore: ObservableObject {
    @Published private(set) var profile: UserProfile?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let service = FirestoreUserProfileService()

    func syncProfile(for user: User?) async {
        guard let user else {
            clear()
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            profile = try await service.ensureProfile(for: user)
        } catch {
            errorMessage = "프로필 정보를 불러오지 못했습니다."
        }

        isLoading = false
    }

    func updateNickname(_ nickname: String, for user: User?) async {
        guard let user else { return }

        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNickname.isEmpty else {
            errorMessage = "닉네임을 입력해주세요."
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
        isLoading = false
        isSaving = false
        errorMessage = nil
    }
}
