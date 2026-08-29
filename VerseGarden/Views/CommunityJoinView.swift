import SwiftUI

struct CommunityJoinView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var communityStore: CommunityStore

    @State private var inviteCode = ""
    @State private var isSubmitting = false
    @State private var alertState: JoinAlert?

    private var normalizedCode: String {
        inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("공동체 참여")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.primaryText)
                    Text("교회나 공동체에서 받은 초대 코드를 입력해주세요.")
                        .font(.body)
                        .foregroundStyle(AppColors.secondaryText)
                        .lineSpacing(4)
                }

                GardenCard(
                    accentGradient: LinearGradient(
                        colors: [GardenTheme.primary.opacity(0.24), GardenTheme.softFill.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                ) {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("초대 코드", systemImage: "ticket.fill")
                            .font(.headline)
                            .foregroundStyle(GardenTheme.secondary)

                        TextField("VG-XXXXXXXX-XXXXXXXX", text: $inviteCode)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.body.monospaced().weight(.semibold))
                            .padding(.horizontal, 16)
                            .frame(minHeight: 56)
                            .background(Color.white.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                                    .stroke(GardenTheme.softStroke, lineWidth: 1)
                            }
                            .onChange(of: inviteCode) { _, value in
                                let normalized = value.uppercased()
                                if normalized != value {
                                    inviteCode = normalized
                                }
                            }

                        Text("초대 코드는 공동체 관리자에게 받을 수 있습니다.")
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryText)

                        Button {
                            submit()
                        } label: {
                            GardenPrimaryButtonLabel(
                                title: isSubmitting ? "참여하는 중..." : "공동체 참여하기",
                                icon: "person.2.fill"
                            )
                            .opacity(canSubmit ? 1 : 0.58)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSubmit)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.large)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("공동체 참여")
        .navigationBarTitleDisplayMode(.inline)
        .background(GardenTheme.background)
        .alert(item: $alertState) { state in
            Alert(
                title: Text(state.title),
                message: Text(state.message),
                dismissButton: .default(Text("확인")) {
                    if state.shouldDismiss {
                        dismiss()
                    }
                }
            )
        }
    }

    private var canSubmit: Bool {
        !normalizedCode.isEmpty && !isSubmitting
    }

    private func submit() {
        guard canSubmit else { return }
        isSubmitting = true

        Task { @MainActor in
            defer { isSubmitting = false }
            do {
                let result = try await communityStore.redeemInvite(code: normalizedCode)
                alertState = JoinAlert(
                    title: "공동체에 참여했어요",
                    message: "\(result.communityName)에 참여했습니다.",
                    shouldDismiss: true
                )
            } catch {
                alertState = JoinAlert(
                    title: "공동체에 참여할 수 없습니다",
                    message: (error as? LocalizedError)?.errorDescription
                        ?? "잠시 후 다시 시도해주세요.",
                    shouldDismiss: false
                )
            }
        }
    }
}

private struct JoinAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let shouldDismiss: Bool
}
