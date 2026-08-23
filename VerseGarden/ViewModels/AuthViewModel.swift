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
    @Published private(set) var passwordResetMessage: String?
    @Published private(set) var passwordResetSucceeded = false
    @Published private(set) var passwordChangeMessage: String?
    @Published private(set) var passwordChangeSucceeded = false
    @Published var errorMessage: String?

    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?

    var isLoggedIn: Bool {
        currentUser != nil
    }

    var canChangePassword: Bool {
        guard let user = currentUser else { return false }
        let providerIDs = user.providerData.map(\.providerID)
        return providerIDs.isEmpty || providerIDs.contains("password")
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
        let passwordValidation = AuthValidation.validatePassword(password, confirmation: confirmPassword)
        guard passwordValidation.meetsContentRequirements else {
            errorMessage = AuthValidation.passwordPolicyMessage
            return
        }
        guard passwordValidation.matchesConfirmation else {
            errorMessage = "비밀번호가 일치하지 않습니다."
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

    func sendPasswordReset(email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        guard validateFirebaseReady() else { return }
        guard !trimmedEmail.isEmpty else {
            passwordResetSucceeded = false
            passwordResetMessage = "가입한 이메일을 입력해주세요."
            return
        }
        guard validateEmailFormat(trimmedEmail) else {
            passwordResetSucceeded = false
            passwordResetMessage = "이메일 형식이 올바르지 않습니다."
            return
        }

        isSubmitting = true
        passwordResetMessage = nil
        passwordResetSucceeded = false
        errorMessage = nil

        Auth.auth().sendPasswordReset(withEmail: trimmedEmail) { [weak self] error in
            guard let self else { return }
            Task { @MainActor in
                self.isSubmitting = false
                if error != nil {
                    self.passwordResetSucceeded = false
                    self.passwordResetMessage = "비밀번호 재설정 메일을 보내지 못했습니다. 이메일 주소를 확인한 뒤 다시 시도해주세요."
                } else {
                    self.passwordResetSucceeded = true
                    self.passwordResetMessage = "입력한 이메일로 비밀번호 재설정 메일을 보냈습니다. 메일함을 확인해주세요."
                }
            }
        }
    }

    func changePassword(currentPassword: String, newPassword: String, confirmPassword: String) {
        guard validateFirebaseReady() else { return }
        guard canChangePassword else {
            passwordChangeSucceeded = false
            passwordChangeMessage = "이 계정은 비밀번호 변경을 지원하지 않습니다."
            return
        }
        guard let user = currentUser ?? Auth.auth().currentUser else {
            passwordChangeSucceeded = false
            passwordChangeMessage = "다시 로그인한 뒤 시도해주세요."
            return
        }
        guard let email = user.email, !email.isEmpty else {
            passwordChangeSucceeded = false
            passwordChangeMessage = "계정 이메일을 확인할 수 없습니다. 다시 로그인한 뒤 시도해주세요."
            return
        }
        guard !currentPassword.isEmpty else {
            passwordChangeSucceeded = false
            passwordChangeMessage = "현재 비밀번호를 입력해주세요."
            return
        }
        guard currentPassword != newPassword else {
            passwordChangeSucceeded = false
            passwordChangeMessage = "새 비밀번호는 현재 비밀번호와 달라야 합니다."
            return
        }

        let passwordValidation = AuthValidation.validatePassword(newPassword, confirmation: confirmPassword)
        guard passwordValidation.meetsContentRequirements else {
            passwordChangeSucceeded = false
            passwordChangeMessage = AuthValidation.passwordPolicyMessage
            return
        }
        guard passwordValidation.matchesConfirmation else {
            passwordChangeSucceeded = false
            passwordChangeMessage = "비밀번호가 일치하지 않습니다."
            return
        }

        isSubmitting = true
        passwordChangeMessage = nil
        passwordChangeSucceeded = false
        errorMessage = nil

        let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
        user.reauthenticate(with: credential) { [weak self] _, reauthError in
            guard let self else { return }
            if let reauthError {
                Task { @MainActor in
                    self.isSubmitting = false
                    self.passwordChangeSucceeded = false
                    self.passwordChangeMessage = self.passwordChangeErrorMessage(for: reauthError)
                }
                return
            }

            user.updatePassword(to: newPassword) { [weak self] updateError in
                guard let self else { return }
                Task { @MainActor in
                    self.isSubmitting = false
                    if let updateError {
                        self.passwordChangeSucceeded = false
                        self.passwordChangeMessage = self.passwordChangeErrorMessage(for: updateError)
                    } else {
                        self.passwordChangeSucceeded = true
                        self.passwordChangeMessage = "비밀번호가 변경되었습니다."
                    }
                }
            }
        }
    }

    func clearErrorMessage() {
        errorMessage = nil
    }

    func clearPasswordResetStatus() {
        passwordResetMessage = nil
        passwordResetSucceeded = false
    }

    func clearPasswordChangeStatus() {
        passwordChangeMessage = nil
        passwordChangeSucceeded = false
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
        AuthValidation.isValidEmail(email)
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
            return AuthValidation.passwordPolicyMessage
        case .networkError:
            return "네트워크 연결을 확인해주세요."
        default:
            return "로그인 중 문제가 발생했습니다."
        }
    }

    private func passwordChangeErrorMessage(for error: Error) -> String {
        let nsError = error as NSError
        guard let authErrorCode = AuthErrorCode(rawValue: nsError.code) else {
            return "비밀번호 변경에 실패했습니다. 잠시 후 다시 시도해주세요."
        }

        switch authErrorCode {
        case .wrongPassword, .invalidCredential:
            return "현재 비밀번호가 올바르지 않습니다."
        case .weakPassword:
            return AuthValidation.passwordPolicyMessage
        case .requiresRecentLogin:
            return "다시 로그인한 뒤 시도해주세요."
        case .networkError:
            return "네트워크 연결을 확인해주세요."
        default:
            return "비밀번호 변경에 실패했습니다. 잠시 후 다시 시도해주세요."
        }
    }
}
