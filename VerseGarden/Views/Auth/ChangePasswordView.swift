import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var didScheduleDismiss = false

    private var passwordValidation: PasswordValidationResult {
        AuthValidation.validatePassword(newPassword, confirmation: confirmPassword)
    }

    private var isSameAsCurrentPassword: Bool {
        !currentPassword.isEmpty && currentPassword == newPassword
    }

    private var canSubmit: Bool {
        authViewModel.isFirebaseConfigured
            && authViewModel.canChangePassword
            && !authViewModel.isSubmitting
            && !currentPassword.isEmpty
            && passwordValidation.isValid
            && !isSameAsCurrentPassword
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                headerSection
                formSection
                submitButton
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("비밀번호 변경")
        .navigationBarTitleDisplayMode(.inline)
        .background(GardenTheme.background)
        .onAppear {
            authViewModel.clearPasswordChangeStatus()
        }
        .onChange(of: authViewModel.passwordChangeSucceeded) { _, succeeded in
            guard succeeded, !didScheduleDismiss else { return }
            didScheduleDismiss = true
            Task {
                try? await Task.sleep(for: .milliseconds(800))
                await MainActor.run {
                    dismiss()
                }
            }
        }
    }

    private var headerSection: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("계정 보호를 위해 현재 비밀번호를 확인한 뒤 새 비밀번호로 변경합니다.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineSpacing(4)
            }
        }
    }

    private var formSection: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 16) {
                secureInputField(title: "현재 비밀번호", text: $currentPassword)
                secureInputField(title: "새 비밀번호", text: $newPassword)
                secureInputField(title: "새 비밀번호 확인", text: $confirmPassword)
                passwordChecklist

                if isSameAsCurrentPassword {
                    messageText("새 비밀번호는 현재 비밀번호와 달라야 합니다.", isSuccess: false)
                }

                if let message = authViewModel.passwordChangeMessage {
                    messageText(message, isSuccess: authViewModel.passwordChangeSucceeded)
                }
            }
        }
    }

    private var submitButton: some View {
        Button {
            authViewModel.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword,
                confirmPassword: confirmPassword
            )
        } label: {
            Text(authViewModel.isSubmitting ? "변경 중..." : "비밀번호 변경하기")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 54)
                .background(canSubmit ? GardenTheme.primary : AppColors.border.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : 0.72)
    }

    private func secureInputField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.primaryText)

            SecureField(title, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
                .background(GardenTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        }
    }

    private var passwordChecklist: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("새 비밀번호 조건")
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

            if !newPassword.isEmpty && !passwordValidation.meetsContentRequirements {
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

    private func messageText(_ message: String, isSuccess: Bool) -> some View {
        Text(message)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isSuccess ? GardenTheme.primary : .red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background((isSuccess ? GardenTheme.primary : Color.red).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .stroke((isSuccess ? GardenTheme.primary : Color.red).opacity(0.12), lineWidth: 1)
            }
    }
}
