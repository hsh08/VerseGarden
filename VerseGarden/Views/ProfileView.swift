import FirebaseAuth
import SwiftData
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var userProfileStore: UserProfileStore
    @Query(sort: \WritingRecord.completedAt, order: .reverse) private var records: [WritingRecord]

    @State private var draftNickname = ""
    @State private var isEditingNickname = false
    @State private var showingLogoutConfirmation = false
    private let calendar = Calendar.current

    private var currentUserRecords: [WritingRecord] {
        records.records(for: authViewModel.currentUser?.uid)
    }

    private var displayNickname: String {
        let nickname = userProfileStore.profile?.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if let nickname, !nickname.isEmpty {
            return nickname
        }

        if let email = userProfileStore.profile?.email ?? authViewModel.currentUser?.email,
           let first = email.first {
            return String(first).uppercased()
        }

        return "V"
    }

    private var avatarText: String {
        String(displayNickname.prefix(1)).uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                profileHeaderSection
                infoSection
                statsSection
                actionSection
            }
            .padding(20)
        }
        .navigationTitle("계정")
        .background(Color(.systemGroupedBackground))
        .alert("로그아웃", isPresented: $showingLogoutConfirmation) {
            Button("취소", role: .cancel) {}
            Button("로그아웃", role: .destructive) {
                authViewModel.signOut()
            }
        } message: {
            Text("정말 로그아웃하시겠습니까?")
        }
        .onAppear {
            if let nickname = userProfileStore.profile?.nickname {
                draftNickname = nickname
            }
        }
        .onChange(of: userProfileStore.profile?.nickname) { _, nickname in
            if let nickname {
                draftNickname = nickname
                if !userProfileStore.isSaving {
                    isEditingNickname = false
                }
            }
        }
    }

    private var profileHeaderSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let errorMessage = userProfileStore.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.82), Color.mint.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)

                    Text(avatarText)
                        .font(.title.bold())
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("내 계정")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    if isEditingNickname {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("닉네임", text: $draftNickname)
                                .textFieldStyle(.roundedBorder)

                            HStack(spacing: 10) {
                                Button("취소") {
                                    draftNickname = userProfileStore.profile?.nickname ?? ""
                                    isEditingNickname = false
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                                Button {
                                    Task {
                                        await userProfileStore.updateNickname(draftNickname, for: authViewModel.currentUser)
                                    }
                                } label: {
                                    Text(userProfileStore.isSaving ? "저장 중..." : "저장")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color.green)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .disabled(userProfileStore.isSaving || draftNickname.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                            }
                        }
                    } else {
                        HStack(alignment: .center, spacing: 12) {
                            Text(displayNickname)
                                .font(.title2.bold())
                                .foregroundStyle(.primary)

                            Button("수정") {
                                draftNickname = userProfileStore.profile?.nickname ?? ""
                                isEditingNickname = true
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("기본 정보")
                .font(.title3.bold())

            VStack(spacing: 0) {
                settingsRow(title: "이메일", value: userProfileStore.profile?.email ?? authViewModel.currentUser?.email ?? "-")
                Divider()
                    .padding(.leading, 16)
                settingsRow(
                    title: "가입일",
                    value: userProfileStore.profile?.createdAt.formatted(.dateTime.year().month().day()) ?? "-"
                )
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 12, x: 0, y: 4)
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("요약 통계")
                .font(.title3.bold())

            HStack(spacing: 12) {
                StatSummaryCard(title: "총 필사 수", value: "\(currentUserRecords.count)", unit: "회")
                StatSummaryCard(
                    title: "연속 필사일",
                    value: "\(StreakCalculator.currentStreak(from: currentUserRecords, calendar: calendar))",
                    unit: "일"
                )
            }
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("계정 관리")
                .font(.title3.bold())

            Button {
                showingLogoutConfirmation = true
            } label: {
                Text("로그아웃")
                    .font(.headline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.red.opacity(0.14), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func settingsRow(title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
    }
}

private struct StatSummaryCard: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.green.opacity(0.10), lineWidth: 1)
        }
    }
}
