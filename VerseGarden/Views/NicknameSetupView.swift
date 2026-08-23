import SwiftUI

struct NicknameSetupView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var userProfileStore: UserProfileStore

    @State private var nickname = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                Text("닉네임 설정")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("앱을 시작하기 전에 사용할 닉네임을 설정해주세요.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("닉네임")
                    .font(.subheadline.weight(.semibold))

                TextField("2자 이상 입력해주세요", text: $nickname)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(AppColors.cardTint)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text("공백만 입력할 수 없으며, 2자 이상이어야 합니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = userProfileStore.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                Task {
                    await userProfileStore.updateNickname(nickname, for: authViewModel.currentUser)
                }
            } label: {
                HStack {
                    Spacer()
                    if userProfileStore.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("저장하고 시작하기")
                            .font(.headline)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(GardenTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(userProfileStore.isSaving || trimmedNickname.count < 2)
            .opacity(userProfileStore.isSaving || trimmedNickname.count < 2 ? 0.6 : 1)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(GardenTheme.background)
    }

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
