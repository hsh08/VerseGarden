import FirebaseAuth
import SwiftData
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var userProfileStore: UserProfileStore
    @EnvironmentObject private var reminderScheduler: ReminderScheduler
    @EnvironmentObject private var likedVerseStore: LikedVerseStore
    @EnvironmentObject private var gardenActivityStore: GardenActivityStore
    @EnvironmentObject private var qtStore: QTStore
    @EnvironmentObject private var communityStore: CommunityStore
    @Query(sort: \WritingRecord.completedAt, order: .reverse) private var records: [WritingRecord]
    @Query(sort: \PrayerWritingRecord.completedAt, order: .reverse) private var prayerRecords: [PrayerWritingRecord]

    @State private var draftNickname = ""
    @State private var isEditingNickname = false
    @State private var favoriteVerseID: String?
    private let calendar = Calendar.current
    private let bibleService = BibleDataService.shared

    private var currentUserRecords: [WritingRecord] {
        records.records(for: authViewModel.currentUser?.uid)
    }

    private var currentUserPrayerRecords: [PrayerWritingRecord] {
        prayerRecords.records(for: authViewModel.currentUser?.uid)
    }

    private var timelineActivities: [GardenActivity] {
        GardenActivityTimelineBuilder.mergedActivities(
            writingRecords: currentUserRecords,
            prayerRecords: currentUserPrayerRecords,
            qtRecords: qtStore.records,
            likedVerseRecords: likedVerseStore.getLikedVerseRecords(),
            activityLog: gardenActivityStore.activities,
            calendar: calendar
        )
    }

    private var representativeVerse: LocalBibleVerse? {
        guard let favoriteVerseID else { return nil }
        return bibleService.getVerse(id: favoriteVerseID)
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
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                VStack(spacing: 8) {
                    profileHeaderSection
                    accountSettingsEntrySection
                }
                representativeVerseSection
                statsSection
                verseListEntrySection
                reminderSection
                communitySection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("계정")
        .background(GardenTheme.background)
        .onAppear {
            if let nickname = userProfileStore.profile?.nickname {
                draftNickname = nickname
            }
            loadFavoriteVerseID()
        }
        .onChange(of: userProfileStore.profile?.nickname) { _, nickname in
            if let nickname {
                draftNickname = nickname
                if !userProfileStore.isSaving {
                    isEditingNickname = false
                }
            }
        }
        .onChange(of: authViewModel.currentUser?.uid) { _, _ in
            loadFavoriteVerseID()
        }
        .onChange(of: userProfileStore.profile?.favoriteVerseId) { _, _ in
            loadFavoriteVerseID()
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
                                colors: [GardenTheme.primary.opacity(0.82), GardenTheme.secondary.opacity(0.72)],
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
                    HStack(spacing: 8) {
                        Text("내 가든")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(GardenTheme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(GardenTheme.softFill)
                            .clipShape(Capsule())

                        Text("오늘도 자라는 중")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryText)
                    }

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
                                        .background(GardenTheme.primary)
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
                                .foregroundStyle(AppColors.primaryText)

                            Button("수정") {
                                draftNickname = userProfileStore.profile?.nickname ?? ""
                                isEditingNickname = true
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GardenTheme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(GardenTheme.softFill)
                            .clipShape(Capsule())
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .gardenCardSurface(background: AppColors.cardTint, shadowRadius: AppShadows.elevatedRadius, shadowY: AppShadows.elevatedY)
    }

    private var accountSettingsEntrySection: some View {
        NavigationLink {
            AccountSettingsView(
                email: userProfileStore.profile?.email ?? authViewModel.currentUser?.email ?? "-",
                joinedAtText: userProfileStore.profile?.createdAt.formatted(.dateTime.year().month().day()) ?? "-",
                canChangePassword: authViewModel.canChangePassword,
                onLogout: {
                    authViewModel.signOut()
                }
            )
        } label: {
            accountSettingsEntryLabel
        }
        .buttonStyle(.plain)
    }

    private var accountSettingsEntryLabel: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GardenTheme.primary)
                .frame(width: 32, height: 32)
                .background(GardenTheme.primary.opacity(0.12))
                .clipShape(Circle())

            Text("계정 설정")
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .gardenCardSurface(
            background: GardenTheme.cardBackground,
            border: AppColors.border.opacity(0.72),
            cornerRadius: AppRadius.card,
            shadowRadius: 8,
            shadowY: 3
        )
    }

    private var representativeVerseSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GardenSectionHeader("대표 말씀", subtitle: "나의 가든에 오래 남길 말씀입니다.")

            GardenCard(
                accentGradient: LinearGradient(
                    colors: [GardenTheme.primary.opacity(0.20), AppColors.cardTint.opacity(0.62)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    if let representativeVerse {
                        Text("나의 대표 말씀")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(GardenTheme.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.66))
                            .clipShape(Capsule())

                        Text(representativeVerse.referenceText)
                            .font(.headline)
                            .foregroundStyle(GardenTheme.secondary)

                        Text(representativeVerse.text)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.primaryText)
                            .lineSpacing(5)
                            .lineLimit(3)

                        NavigationLink {
                            FavoriteVersePickerView(selectedVerseID: favoriteVerseID) { verse in
                                saveFavoriteVerseID(verse.id)
                            }
                        } label: {
                            profileInlineAction(title: "변경하기", icon: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.plain)
                    } else {
                        EmptyStateView(
                            icon: "book.pages.fill",
                            title: "아직 대표 말씀이 없어요",
                            message: "삶의 기준이 되는 말씀을 하나 선택해보세요."
                        )

                        NavigationLink {
                            FavoriteVersePickerView(selectedVerseID: favoriteVerseID) { verse in
                                saveFavoriteVerseID(verse.id)
                            }
                        } label: {
                            GardenPrimaryButtonLabel(title: "대표 말씀 선택하기", icon: "book.pages.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GardenSectionHeader("요약 통계", subtitle: "Garden 활동 기록을 기준으로 집계합니다.")

            HStack(spacing: 12) {
                StatSummaryCard(
                    title: "총 활동 수",
                    value: "\(GardenActivityTimelineBuilder.gardenGrowthActivities(from: timelineActivities).count)",
                    unit: "회",
                    accent: GardenTheme.primary
                )
                StatSummaryCard(
                    title: "연속 루틴",
                    value: "\(GardenActivityTimelineBuilder.currentStreak(from: timelineActivities, calendar: calendar))",
                    unit: "일",
                    accent: GardenTheme.secondary
                )
            }

            HStack(spacing: 12) {
                StatSummaryCard(
                    title: "말씀 읽기",
                    value: "\(activityCount(for: .verseRead))",
                    unit: "회",
                    accent: GardenTheme.primary
                )
                StatSummaryCard(
                    title: "필사 완료",
                    value: "\(activityCount(for: .scriptureCopy))",
                    unit: "회",
                    accent: GardenTheme.secondary
                )
            }

            HStack(spacing: 12) {
                StatSummaryCard(
                    title: "기도 기록",
                    value: "\(activityCount(for: .prayer))",
                    unit: "회",
                    accent: GardenTheme.tertiary
                )
                StatSummaryCard(
                    title: "QT 완료",
                    value: "\(activityCount(for: .qtCompleted))",
                    unit: "회",
                    accent: GardenTheme.primary
                )
            }
        }
    }

    private func activityCount(for type: GardenActivityType) -> Int {
        timelineActivities.filter { $0.type == type }.count
    }

    private var verseListEntrySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GardenSectionHeader("VerseList", subtitle: "좋아하거나 다시 보고 싶은 말씀을 모아둡니다.")

            VStack(spacing: 10) {
                NavigationLink {
                    VerseListView()
                } label: {
                    profileEntryCard(
                        title: "내가 저장한 말씀",
                        subtitle: "\(likedVerseStore.likedCount)개 저장됨 · 마음에 남은 말씀을 다시 봅니다.",
                        icon: "heart.fill",
                        tint: GardenTheme.tertiary
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    MyVerseListView()
                } label: {
                    profileEntryCard(
                        title: "내 말씀 리스트",
                        subtitle: "직접 만든 말씀 리스트를 관리합니다.",
                        icon: "bookmark.fill",
                        tint: GardenTheme.primary
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GardenSectionHeader("리마인더", subtitle: "작은 습관을 잊지 않도록 도와줍니다.")

            NavigationLink {
                ReminderSettingsView()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "bell.badge.fill")
                        .font(.headline)
                        .foregroundStyle(reminderScheduler.reminderEnabled ? GardenTheme.primary : AppColors.subtleText)
                        .frame(width: 42, height: 42)
                        .background((reminderScheduler.reminderEnabled ? GardenTheme.primary : AppColors.border).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text("매일 알림")
                                .font(.headline)
                                .foregroundStyle(AppColors.primaryText)
                            reminderBadge
                        }
                        Text(reminderSummary)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.secondaryText)
                }
                .padding(18)
                .gardenCardSurface(background: GardenTheme.cardBackground, cornerRadius: AppRadius.card, shadowRadius: 8, shadowY: 4)
            }
            .buttonStyle(.plain)
        }
    }

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GardenSectionHeader("나의 공동체", subtitle: "함께 말씀을 묵상하는 공동체를 확인합니다.")

            if communityStore.isLoading && !communityStore.hasLoaded {
                communityLoadingCard
            } else if let community = communityStore.currentCommunity,
                      let membership = communityStore.currentMembership {
                joinedCommunityCard(community: community, membership: membership)
            } else if let errorMessage = communityStore.errorMessage {
                communityErrorCard(message: errorMessage)
            } else {
                noCommunityCard
            }
        }
    }

    private var communityLoadingCard: some View {
        GardenCard {
            HStack(spacing: 14) {
                ProgressView()
                    .tint(GardenTheme.primary)
                Text("공동체 정보를 불러오는 중이에요.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText)
            }
            .frame(minHeight: 56)
        }
    }

    private var noCommunityCard: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.20), GardenTheme.tertiary.opacity(0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: 15) {
                Label("함께 신앙생활하는 공동체에 참여해보세요.", systemImage: "person.2.fill")
                    .font(.headline)
                    .foregroundStyle(AppColors.primaryText)

                NavigationLink {
                    CommunityJoinView()
                } label: {
                    GardenPrimaryButtonLabel(title: "초대 코드로 공동체 참여하기", icon: "ticket.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func joinedCommunityCard(
        community: Community,
        membership: CommunityMembership
    ) -> some View {
        NavigationLink {
            CommunityDetailView()
        } label: {
            GardenCard(
                accentGradient: LinearGradient(
                    colors: [GardenTheme.primary.opacity(0.24), GardenTheme.tertiary.opacity(0.14)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: "person.3.fill")
                            .font(.title3)
                            .foregroundStyle(GardenTheme.secondary)
                            .frame(width: 46, height: 46)
                            .background(Color.white.opacity(0.66))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

                        VStack(alignment: .leading, spacing: 5) {
                            Text(community.name)
                                .font(.title3.bold())
                                .foregroundStyle(AppColors.primaryText)
                            Text(membership.role.displayName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(GardenTheme.primary)
                        }

                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.secondaryText)
                            .padding(.top, 8)
                    }

                    Divider().overlay(AppColors.border)

                    HStack {
                        Label("오늘의 공동체 QT", systemImage: "leaf.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GardenTheme.secondary)
                        Spacer()
                        Text("보기")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(GardenTheme.primary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func communityErrorCard(message: String) -> some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(message, systemImage: "wifi.exclamationmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText)

                Button {
                    Task { await communityStore.retry() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("다시 시도")
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(GardenTheme.primary)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(GardenTheme.softFill)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var reminderSummary: String {
        if reminderScheduler.reminderEnabled {
            return String(format: "매일 %02d:%02d", reminderScheduler.reminderHour, reminderScheduler.reminderMinute)
        }
        return "알림이 꺼져 있어요"
    }

    private var reminderBadge: some View {
        Text(reminderScheduler.reminderEnabled ? "켜짐" : "꺼짐")
            .font(.caption2.weight(.bold))
            .foregroundStyle(reminderScheduler.reminderEnabled ? GardenTheme.primary : AppColors.subtleText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((reminderScheduler.reminderEnabled ? GardenTheme.primary : AppColors.border).opacity(0.12))
            .clipShape(Capsule())
    }

    private func profileEntryCard(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColors.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColors.secondaryText)
        }
        .padding(16)
        .gardenCardSurface(
            background: GardenTheme.cardBackground,
            border: AppColors.border.opacity(0.72),
            cornerRadius: AppRadius.card,
            shadowRadius: 8,
            shadowY: 4
        )
    }

    private func profileInlineAction(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline.weight(.bold))
            Text(title)
                .font(.subheadline.weight(.bold))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(GardenTheme.primary)
        .frame(minHeight: 46)
        .padding(.horizontal, 14)
        .background(GardenTheme.softFill)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                .stroke(GardenTheme.softStroke, lineWidth: 1)
        }
    }

    private func loadFavoriteVerseID() {
        favoriteVerseID = userProfileStore.profile?.favoriteVerseId
    }

    private func saveFavoriteVerseID(_ verseID: String) {
        favoriteVerseID = verseID
        Task {
            await userProfileStore.updateFavoriteVerseId(verseID, for: authViewModel.currentUser)
        }
    }

}

private struct AccountSettingsView: View {
    let email: String
    let joinedAtText: String
    let canChangePassword: Bool
    let onLogout: () -> Void

    @State private var showingLogoutConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                basicInfoSection
                accountManagementSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("계정 설정")
        .navigationBarTitleDisplayMode(.inline)
        .background(GardenTheme.background)
        .alert("로그아웃", isPresented: $showingLogoutConfirmation) {
            Button("취소", role: .cancel) {}
            Button("로그아웃", role: .destructive) {
                onLogout()
            }
        } message: {
            Text("정말 로그아웃하시겠습니까?")
        }
    }

    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GardenSectionHeader("기본 정보")

            VStack(spacing: 0) {
                settingsRow(title: "이메일", value: email)
                Divider()
                    .padding(.leading, 16)
                settingsRow(title: "가입일", value: joinedAtText)
            }
            .gardenCardSurface(background: AppColors.cardTint, cornerRadius: AppRadius.medium, shadowRadius: 12, shadowY: 4)
        }
    }

    private var accountManagementSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GardenSectionHeader("계정 관리")

            if canChangePassword {
                NavigationLink {
                    ChangePasswordView()
                } label: {
                    accountActionRow(
                        title: "비밀번호 변경",
                        subtitle: "현재 비밀번호 확인 후 새 비밀번호로 변경합니다.",
                        icon: "lock.fill",
                        tint: GardenTheme.primary
                    )
                }
                .buttonStyle(.plain)
            } else {
                accountActionRow(
                    title: "비밀번호 변경",
                    subtitle: "이 계정은 비밀번호 변경을 지원하지 않습니다.",
                    icon: "lock.slash",
                    tint: AppColors.subtleText
                )
                .opacity(0.72)
            }

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

    private func accountActionRow(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColors.primaryText)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            if canChangePassword {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
        .padding(16)
        .gardenCardSurface(
            background: GardenTheme.cardBackground,
            border: AppColors.border.opacity(0.72),
            cornerRadius: AppRadius.card,
            shadowRadius: 8,
            shadowY: 4
        )
    }

    private func settingsRow(title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.primaryText)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppColors.secondaryText)
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
    var accent: Color = GardenTheme.primary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.primaryText)
                    .monospacedDigit()
                Text(unit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 0.8)
        }
    }
}
