import SwiftUI

struct SignupView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    let switchToLogin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("회원가입")
                .font(.title3.bold())

            inputField(title: "이메일", text: $email, isSecure: false)
            inputField(title: "비밀번호", text: $password, isSecure: true)
            inputField(title: "비밀번호 확인", text: $confirmPassword, isSecure: true)

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
                    .padding()
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(authViewModel.isSubmitting || !authViewModel.isFirebaseConfigured)
            .opacity(authViewModel.isSubmitting || !authViewModel.isFirebaseConfigured ? 0.6 : 1)

            Button {
                authViewModel.clearErrorMessage()
                switchToLogin()
            } label: {
                Text("이미 계정이 있나요? 로그인")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .disabled(authViewModel.isSubmitting)
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}
