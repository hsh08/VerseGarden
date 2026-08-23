import SwiftUI

struct SignupView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    let switchToLogin: () -> Void
    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var passwordValidation: PasswordValidationResult {
        AuthValidation.validatePassword(password, confirmation: confirmPassword)
    }

    private var canSubmit: Bool {
        authViewModel.isFirebaseConfigured
            && !authViewModel.isSubmitting
            && AuthValidation.isValidEmail(trimmedEmail)
            && passwordValidation.isValid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("회원가입")
                .font(.title3.bold())

            inputField(title: "이메일", text: $email, isSecure: false)
            inputField(title: "비밀번호", text: $password, isSecure: true)
            inputField(title: "비밀번호 확인", text: $confirmPassword, isSecure: true)
            passwordChecklist

            if let errorMessage = authViewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.orange.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.orange.opacity(0.16), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                authViewModel.signUp(email: email, password: password, confirmPassword: confirmPassword)
            } label: {
                Text("이메일로 회원가입")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 54)
                    .padding(.horizontal, 18)
                    .background(canSubmit ? GardenTheme.primary : AppColors.border.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.72)

            Button {
                authViewModel.clearErrorMessage()
                switchToLogin()
            } label: {
                Text("이미 계정이 있나요? 로그인")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GardenTheme.primary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(authViewModel.isSubmitting)
        }
        .padding(20)
        .gardenCardSurface(background: AppColors.cardTint)
    }

    @ViewBuilder
    private func inputField(title: String, text: Binding<String>, isSecure: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            Group {
                if isSecure {
                    SecureField(title, text: text)
                } else {
                    TextField(title, text: text)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
            }
            .padding()
            .background(GardenTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        }
    }

    private var passwordChecklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("비밀번호 조건")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.secondaryText)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 2),
                alignment: .leading,
                spacing: 8
            ) {
                passwordRequirementRow("8자 이상", isSatisfied: passwordValidation.hasMinimumLength)
                passwordRequirementRow("영문 포함", isSatisfied: passwordValidation.containsLetter)
                passwordRequirementRow("숫자 포함", isSatisfied: passwordValidation.containsNumber)
                passwordRequirementRow("특수문자 포함", isSatisfied: passwordValidation.containsSpecialCharacter)
                passwordRequirementRow("비밀번호 일치", isSatisfied: passwordValidation.matchesConfirmation)
            }

            if !password.isEmpty && !passwordValidation.meetsContentRequirements {
                Text(AuthValidation.passwordPolicyMessage)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineSpacing(3)
            } else if !confirmPassword.isEmpty && !passwordValidation.matchesConfirmation {
                Text("비밀번호가 일치하지 않습니다.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red.opacity(0.78))
            }
        }
        .padding(14)
        .background(GardenTheme.softFill)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(GardenTheme.softStroke, lineWidth: 1)
        }
    }

    private func passwordRequirementRow(_ title: String, isSatisfied: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isSatisfied ? "checkmark.circle.fill" : "circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSatisfied ? GardenTheme.primary : AppColors.subtleText)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSatisfied ? GardenTheme.primary : AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("\(title) \(isSatisfied ? "충족" : "미충족")")
    }
}
