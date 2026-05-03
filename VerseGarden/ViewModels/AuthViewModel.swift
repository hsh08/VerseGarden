import Combine
import FirebaseAuth
import FirebaseCore
import Foundation

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var isFirebaseConfigured = false
    @Published var errorMessage: String?

    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?

    var isLoggedIn: Bool {
        currentUser != nil
    }

    var setupMessage: String? {
        guard !isFirebaseConfigured else { return nil }
        return "Firebase 설정이 아직 완료되지 않았습니다. Firebase 프로젝트를 만들고 GoogleService-Info.plist를 앱 타깃에 추가한 뒤 다시 실행해주세요."
    }

    deinit {
        guard FirebaseApp.app() != nil else { return }
        authStateListenerHandle.map { Auth.auth().removeStateDidChangeListener($0) }
    }

    func startAuthStateListener() {
        guard authStateListenerHandle == nil else { return }
        isFirebaseConfigured = FirebaseApp.app() != nil
        guard isFirebaseConfigured else {
            isLoading = false
            currentUser = nil
            return
        }

        isLoading = true
        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.currentUser = user
                if user != nil {
                    self.errorMessage = nil
                }
                self.isLoading = false
                self.isSubmitting = false
            }
        }
    }

    func stopAuthStateListener() {
        guard let authStateListenerHandle else { return }
        Auth.auth().removeStateDidChangeListener(authStateListenerHandle)
        self.authStateListenerHandle = nil
    }

    func signIn(email: String, password: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard validateFirebaseReady() else { return }
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "이메일과 비밀번호를 모두 입력해주세요."
            return
        }
        guard validateEmailFormat(trimmedEmail) else {
            errorMessage = "이메일 형식이 올바르지 않습니다."
            return
        }
        guard validateGmailTypo(for: trimmedEmail) else { return }

        isSubmitting = true
        errorMessage = nil

        Auth.auth().signIn(withEmail: trimmedEmail, password: password) { [weak self] _, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.currentUser = nil
                    self.isSubmitting = false
                    self.errorMessage = self.message(for: error)
                }
            }
        }
    }

    func signUp(email: String, password: String, confirmPassword: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard validateFirebaseReady() else { return }
        guard !trimmedEmail.isEmpty, !password.isEmpty, !confirmPassword.isEmpty else {
            errorMessage = "이메일, 비밀번호, 비밀번호 확인을 모두 입력해주세요."
            return
        }
        guard validateEmailFormat(trimmedEmail) else {
            errorMessage = "이메일 형식이 올바르지 않습니다."
            return
        }
        guard validateGmailTypo(for: trimmedEmail) else { return }
        guard password == confirmPassword else {
            errorMessage = "비밀번호가 일치하지 않습니다."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "비밀번호는 6자 이상이어야 합니다."
            return
        }

        isSubmitting = true
        errorMessage = nil

        Auth.auth().createUser(withEmail: trimmedEmail, password: password) { [weak self] _, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.currentUser = nil
                    self.isSubmitting = false
                    self.errorMessage = self.message(for: error)
                }
            }
        }
    }

    func signOut() {
        guard validateFirebaseReady() else { return }

        do {
            try Auth.auth().signOut()
            currentUser = nil
            errorMessage = nil
        } catch {
            errorMessage = message(for: error)
        }
    }

    func clearErrorMessage() {
        errorMessage = nil
    }

    private func validateFirebaseReady() -> Bool {
        isFirebaseConfigured = FirebaseApp.app() != nil

        guard isFirebaseConfigured else {
            isLoading = false
            isSubmitting = false
            errorMessage = setupMessage
            return false
        }

        return true
    }

    private func validateEmailFormat(_ email: String) -> Bool {
        let parts = email.split(separator: "@")
        guard parts.count == 2,
              !parts[0].isEmpty,
              !parts[1].isEmpty,
              parts[1].contains(".") else {
            return false
        }

        return true
    }

    private func validateGmailTypo(for email: String) -> Bool {
        let domain = email.lowercased().split(separator: "@").last.map(String.init) ?? ""
        let typoDomains: Set<String> = ["gmial.com", "gmil.com", "gamil.com", "gmaill.com"]

        guard typoDomains.contains(domain) else { return true }
        errorMessage = "gmail.com을 입력하려던 건가요?"
        return false
    }

    private func message(for error: Error) -> String {
        let nsError = error as NSError
        guard let authErrorCode = AuthErrorCode(rawValue: nsError.code) else {
            return "로그인 중 문제가 발생했습니다."
        }

        switch authErrorCode {
        case .invalidEmail:
            return "이메일 형식이 올바르지 않습니다."
        case .userNotFound:
            return "가입되지 않은 이메일입니다."
        case .wrongPassword:
            return "비밀번호가 올바르지 않습니다."
        case .invalidCredential:
            return "이메일 또는 비밀번호가 올바르지 않습니다."
        case .emailAlreadyInUse:
            return "이미 가입된 이메일입니다."
        case .weakPassword:
            return "비밀번호는 6자 이상이어야 합니다."
        case .networkError:
            return "네트워크 연결을 확인해주세요."
        default:
            return "로그인 중 문제가 발생했습니다."
        }
    }
}
