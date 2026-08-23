import SwiftUI

struct PasswordResetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var email: String

    init(initialEmail: String = "") {
        _email = State(initialValue: initialEmail.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSend: Bool {
        authViewModel.isFirebaseConfigured
            && !authViewModel.isSubmitting
            && AuthValidation.isValidEmail(trimmedEmail)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("비밀번호 재설정")
                        .font(.title3.bold())
                        .foregroundStyle(AppColors.primaryText)
                    Text("가입한 이메일을 입력하면 비밀번호 재설정 메일을 보내드립니다.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                        .lineSpacing(4)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.secondaryText)
                        .frame(width: 34, height: 34)
                        .background(GardenTheme.softFill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("이메일")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.primaryText)

                TextField("example@email.com", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .padding()
                    .background(GardenTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            }

            if !trimmedEmail.isEmpty && !AuthValidation.isValidEmail(trimmedEmail) {
                Text("이메일 형식이 올바르지 않습니다.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red.opacity(0.78))
            }

            if let message = authViewModel.passwordResetMessage {
                Text(message)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(authViewModel.passwordResetSucceeded ? GardenTheme.primary : .red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background((authViewModel.passwordResetSucceeded ? GardenTheme.primary : Color.red).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                            .stroke((authViewModel.passwordResetSucceeded ? GardenTheme.primary : Color.red).opacity(0.12), lineWidth: 1)
                    }
            }

            Button {
                authViewModel.sendPasswordReset(email: email)
            } label: {
                Text("재설정 메일 보내기")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(canSend ? GardenTheme.primary : AppColors.border.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .opacity(canSend ? 1 : 0.72)

            Button {
                dismiss()
            } label: {
                Text("닫기")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GardenTheme.primary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(GardenTheme.background)
        .onDisappear {
            authViewModel.clearPasswordResetStatus()
        }
    }
}
