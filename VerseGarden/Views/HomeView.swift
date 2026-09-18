import FirebaseAuth
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WritingRecord.completedAt, order: .reverse) private var records: [WritingRecord]
    @Query(sort: \PrayerWritingRecord.completedAt, order: .reverse) private var prayerRecords: [PrayerWritingRecord]
    @Query(sort: \ScriptureWritingPlan.createdAt, order: .reverse) private var plans: [ScriptureWritingPlan]
    @Query(sort: \PlanDayAssignment.date, order: .forward) private var assignments: [PlanDayAssignment]
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var gardenActivityStore: GardenActivityStore
    @EnvironmentObject private var qtStore: QTStore
    @EnvironmentObject private var todayQuietTimeContentStore: TodayQuietTimeContentStore
    @EnvironmentObject private var writingPlanSelectionStore: WritingPlanSelectionStore
    @EnvironmentObject private var likedVerseStore: LikedVerseStore
    @EnvironmentObject private var communityStore: CommunityStore

    private let calendar = Calendar.current
    @State private var metrics = HomeMetrics.empty
    @State private var planState = HomePlanState.empty
    @State private var showingCreatePlan = false
    @State private var showingPlanSelector = false
    @State private var isCompletedQTExpanded = false
    @State private var isCompletedVerseExpanded = false
    @State private var isCompletedWritingPlanExpanded = false

    private var todayVerse: TodayVerseContent? {
        TodayVerseService.todayVerse(date: Date(), calendar: calendar)
    }

    private var localTodayQTContent: QTContent {
        QTContent(
            date: Date(),
            calendar: calendar,
            todayVerse: todayVerse,
            fallbackVerse: planState.launchVerse
        )
    }

    private var todayQTContent: QTContent {
        todayQuietTimeContentStore.content(fallback: localTodayQTContent)
    }

    private var currentUserRecords: [WritingRecord] {
        records.records(for: authViewModel.currentUser?.uid)
    }

    private var currentUserPrayerRecords: [PrayerWritingRecord] {
        prayerRecords.records(for: authViewModel.currentUser?.uid)
    }

    private var currentUserPlans: [ScriptureWritingPlan] {
        plans.plans(for: authViewModel.currentUser?.uid)
    }

    private var selectableWritingPlans: [ScriptureWritingPlan] {
        currentUserPlans
            .filter { $0.status == .active }
            .sorted { lhs, rhs in
                if lhs.status == rhs.status {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.status.sortPriority < rhs.status.sortPriority
            }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                greetingHeader
                if shouldShowTodayQuietTimeCard {
                    todayQuietTimeCard
                }
                if shouldShowFeaturedWritingPlanCard {
                    featuredWritingPlanCard
                } else {
                    collapsedRoutineCard(
                        title: "오늘 필사 완료",
                        subtitle: "완료 기록은 최근 활동과 플랜 상세에서 볼 수 있어요.",
                        icon: "checkmark.circle.fill",
                        tint: GardenTheme.primary,
                        isExpanded: isCompletedWritingPlanExpanded
                    ) {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isCompletedWritingPlanExpanded.toggle()
                        }
                    }
                }
                if shouldShowTodayVerseCard {
                    todayVerseCard
                } else {
                    collapsedRoutineCard(
                        title: "오늘의 말씀 완료",
                        subtitle: "오늘 말씀 루틴이 Garden에 반영됐어요.",
                        icon: "book.closed.fill",
                        tint: GardenTheme.primary,
                        isExpanded: isCompletedVerseExpanded
                    ) {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isCompletedVerseExpanded.toggle()
                        }
                    }
                }
                gardenSummaryCard
                recentActivitySection
                weeklyRoutineSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("VerseGarden")
        .navigationBarTitleDisplayMode(.inline)
        .background(GardenTheme.background)
        .task(id: recordsSignature) {
            PlanAssignmentStateEvaluator.refreshStates(
                userID: authViewModel.currentUser?.uid,
                modelContext: modelContext,
                calendar: calendar
            )
            refreshMetrics()
        }
        .task(id: quietTimeContextID) {
            await todayQuietTimeContentStore.loadTodayIfNeeded(
                community: communityStore.currentCommunity,
                force: true
            )
        }
        .sheet(isPresented: $showingCreatePlan) {
            NavigationStack {
                CreateWritingPlanView()
            }
        }
        .sheet(isPresented: $showingPlanSelector) {
            WritingPlanSelectorView(
                plans: selectableWritingPlans,
                selectedPlan: planState.displayedPlan,
                assignments: assignments.assignments(for: authViewModel.currentUser?.uid),
                userID: authViewModel.currentUser?.uid,
                onSelect: { plan in
                    writingPlanSelectionStore.selectPlan(plan)
                    refreshMetrics()
                    isCompletedWritingPlanExpanded = shouldKeepWritingPlanExpandedAfterSelection(plan)
                    showingPlanSelector = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("VerseGarden")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.primaryText)
            Text("오늘도 작은 순종을 심어봐요")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
        .padding(.bottom, 2)
    }

    private var todayVerseCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("오늘의 말씀")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(GardenTheme.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(GardenTheme.softFill)
                            .clipShape(Capsule())

                        Text(todayVerse?.referenceText ?? "오늘의 말씀")
                            .font(.title3.bold())
                            .foregroundStyle(AppColors.primaryText)
                    }

                    Spacer()

                    Image(systemName: "book.pages.fill")
                        .font(.title3)
                        .foregroundStyle(GardenTheme.primary)
                        .frame(width: 42, height: 42)
                        .background(GardenTheme.softFill)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                }

                Text(todayVersePreview)
                    .font(.body)
                    .foregroundStyle(AppColors.primaryText)
                    .lineSpacing(5)
                    .lineLimit(3)

                HStack(spacing: 10) {
                    if let localVerse = todayVerse?.verse {
                        NavigationLink {
                            VerseDetailView(verse: localVerse)
                        } label: {
                            homeCompactButton(title: "말씀 보기", icon: "book", isPrimary: true)
                        }
                        .buttonStyle(.plain)

                        NavigationLink {
                            WriteView(localVerse: localVerse)
                        } label: {
                            homeCompactButton(title: "필사하기", icon: "pencil.line")
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink {
                            VerseView()
                        } label: {
                            homeCompactButton(title: "말씀 보기", icon: "book")
                        }
                        .buttonStyle(.plain)

                        homeCompactButton(title: "필사 준비중", icon: "lock.fill", isDisabled: true)
                    }
                }

                if isTodayVerseCompleted {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isCompletedVerseExpanded = false
                        }
                    } label: {
                        homeCompactButton(title: "접기", icon: "chevron.up", isNeutral: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var todayQuietTimeCard: some View {
        Group {
            if isTodayQuietTimeCompleted, !isCompletedQTExpanded {
                collapsedRoutineCard(
                    title: "오늘의 QT 완료",
                    subtitle: "묵상과 기도가 오늘의 Garden에 심겼어요.",
                    icon: "checkmark.seal.fill",
                    tint: GardenTheme.secondary,
                    isExpanded: isCompletedQTExpanded
                ) {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isCompletedQTExpanded.toggle()
                    }
                }
            } else {
                expandedQuietTimeCard
            }
        }
    }

    private var expandedQuietTimeCard: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.34), AppColors.cardTint.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("오늘의 큐티")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(GardenTheme.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.64))
                            .clipShape(Capsule())

                        if todayQTContent.source == .community,
                           let communityName = todayQTContent.communityName {
                            Text("공동체 QT · \(communityName)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(GardenTheme.primary)
                                .lineLimit(1)
                        }

                        Text(isTodayQuietTimeCompleted ? "완료한 QT를 다시 볼 수 있어요" : todayQTContent.title)
                            .font(.title3.bold())
                            .foregroundStyle(AppColors.primaryText)
                    }

                    Spacer()

                    Image(systemName: "leaf.fill")
                        .font(.title3)
                        .foregroundStyle(GardenTheme.primary)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.58))
                        .clipShape(Circle())
                }

                Text(todayQTContent.devotionalText)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineSpacing(4)
                    .lineLimit(3)

                NavigationLink {
                    TodayQuietTimeView(
                        todayVerse: todayVerse,
                        planLaunchVerse: planState.launchVerse,
                        planLaunchContext: planState.launchContext,
                        isPlanPaused: planState.isPaused,
                        isWritingCompleted: planState.isTodayAssignmentCompleted,
                        qtContentOverride: todayQTContent
                    )
                } label: {
                    GardenPrimaryButtonLabel(title: isTodayQuietTimeCompleted ? "오늘의 QT 다시 보기" : todayQuietTimeButtonTitle, icon: "leaf.fill")
                }
                .buttonStyle(.plain)

                if isTodayQuietTimeCompleted {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isCompletedQTExpanded = false
                        }
                    } label: {
                        homeCompactButton(title: "접기", icon: "chevron.up", isNeutral: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var featuredWritingPlanCard: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.secondary.opacity(0.22), AppColors.cardTint.opacity(0.66)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Button {
                        if selectableWritingPlans.isEmpty {
                            showingCreatePlan = true
                        } else {
                            showingPlanSelector = true
                        }
                    } label: {
                        WritingPlanFolderStackView(
                            plans: selectableWritingPlans,
                            selectedPlan: planState.displayedPlan
                        )
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("필사 플랜")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(GardenTheme.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.72))
                            .clipShape(Capsule())

                        Text(planState.displayedPlan?.title ?? "말씀을 매일 따라 쓰는 계획")
                            .font(.title3.bold())
                            .foregroundStyle(AppColors.primaryText)
                            .lineLimit(2)

                        if !selectableWritingPlans.isEmpty {
                            Button {
                                showingPlanSelector = true
                            } label: {
                                HStack(spacing: 5) {
                                    Text("\(selectableWritingPlans.count)개 플랜 중 선택")
                                    Image(systemName: "chevron.down")
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(GardenTheme.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer(minLength: 0)
                }

                Text(planSupportSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineSpacing(4)

                if planState.displayedPlan != nil {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(planState.todayProgressLabel)
                                .font(.headline.bold())
                                .foregroundStyle(GardenTheme.primary)
                            Spacer()
                            Text(planState.todayCompletionLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.secondaryText)
                        }

                        ProgressView(value: planState.todayProgressValue)
                            .tint(GardenTheme.primary)
                            .scaleEffect(x: 1, y: 0.86, anchor: .center)

                        Text("오늘 필사 진행도")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryText)

                        if let statusMessage = planState.statusMessage {
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.54))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                            .stroke(AppColors.border.opacity(0.62), lineWidth: 0.8)
                    }
                }

                featuredWritingPlanAction

                if planState.isTodayAssignmentCompleted || planState.displayedPlan?.status == .completed {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isCompletedWritingPlanExpanded = false
                        }
                    } label: {
                        homeCompactButton(title: "접기", icon: "chevron.up", isNeutral: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var gardenSummaryCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                GardenSectionHeader("Garden 요약", subtitle: "오늘 남긴 활동이 나의 정원에 쌓입니다.")

                HStack(spacing: 10) {
                    growthStatusItem(
                        icon: "book.closed.fill",
                        title: "말씀",
                        isCompleted: isTodayVerseCompleted,
                        tint: GardenTheme.primary
                    )
                    growthStatusItem(
                        icon: "hands.sparkles.fill",
                        title: "기도",
                        isCompleted: hasTodayGardenActivity(.prayer),
                        tint: GardenTheme.tertiary
                    )
                    growthStatusItem(
                        icon: "leaf.fill",
                        title: "큐티",
                        isCompleted: hasTodayGardenActivity(.qtCompleted),
                        tint: GardenTheme.secondary,
                        isMock: !hasTodayGardenActivity(.qtCompleted)
                    )
                }

                Divider()
                    .overlay(AppColors.border.opacity(0.7))

                HStack(spacing: 10) {
                    metricPill(title: "오늘 활동", value: "\(todayGardenActivityCount)회")
                    metricPill(title: "연속 루틴", value: "\(currentStreak)일")
                }

                HStack(spacing: 10) {
                    metricPill(title: "이번 주 활동", value: "\(GardenActivityTimelineBuilder.weeklyActivities(from: timelineActivities, calendar: calendar).count)회")
                    NavigationLink {
                        GardenView()
                    } label: {
                        HStack {
                            Text("Garden 보기")
                                .font(.caption.weight(.bold))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(GardenTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(GardenTheme.softFill)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var recentActivitySection: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                GardenSectionHeader("최근 활동", subtitle: "최근 기록한 신앙 습관을 한눈에 봅니다.")

                if recentActivities.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "아직 최근 활동이 없어요",
                        message: "말씀 필사나 기도 기록을 남기면 이곳에 표시됩니다."
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(recentActivities) { activity in
                            HStack(spacing: 12) {
                                Image(systemName: activity.icon)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(activity.tint)
                                    .frame(width: 34, height: 34)
                                    .background(activity.tint.opacity(0.12))
                                    .clipShape(Circle())

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(activity.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppColors.primaryText)
                                    Text(activity.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(AppColors.secondaryText)
                                }

                                Spacer()
                            }
                            .padding(12)
                            .background(GardenTheme.softFill.opacity(0.62))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var featuredWritingPlanAction: some View {
        if planState.displayedPlan == nil {
            VStack(spacing: 10) {
                Button {
                    showingCreatePlan = true
                } label: {
                    GardenPrimaryButtonLabel(title: "필사 플랜 만들기", icon: "calendar.badge.plus")
                }
                .buttonStyle(.plain)

                if !currentUserPlans.isEmpty {
                    NavigationLink {
                        WritingPlanHubView()
                    } label: {
                        homeSecondaryPlanButton(title: "필사 플랜 관리", icon: "slider.horizontal.3")
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if planState.isTodayAssignmentCompleted || planState.displayedPlan?.status == .completed {
            VStack(spacing: 10) {
                homeDisabledPlanButton(
                    title: planState.displayedPlan?.status == .completed ? "완료된 플랜" : "오늘 필사 완료",
                    icon: "checkmark.circle.fill"
                )
                featuredWritingPlanDetailLink(title: "필사 플랜 관리", icon: "slider.horizontal.3")
            }
        } else if planState.isPaused {
            featuredWritingPlanDetailLink(title: "필사 플랜 관리", icon: "slider.horizontal.3")
        } else if let planLaunchContext = planState.launchContext, let launchVerse = planState.launchVerse {
            VStack(spacing: 10) {
                NavigationLink {
                    WriteView(
                        localVerse: launchVerse,
                        sourceType: .plan,
                        writingContext: planLaunchContext
                    )
                } label: {
                    GardenPrimaryButtonLabel(title: "오늘 필사 이어가기", icon: "pencil.line")
                }
                .buttonStyle(.plain)

                featuredWritingPlanDetailLink(title: "필사 플랜 관리", icon: "slider.horizontal.3")
            }
        } else {
            featuredWritingPlanDetailLink(title: "필사 플랜 관리", icon: "slider.horizontal.3")
        }
    }

    @ViewBuilder
    private func featuredWritingPlanDetailLink(title: String, icon: String) -> some View {
        NavigationLink {
            WritingPlanHubView()
        } label: {
            homeSecondaryPlanButton(title: title, icon: icon)
        }
        .buttonStyle(.plain)
    }

    private func homeSecondaryPlanButton(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
            Text(title)
                .font(.headline.weight(.semibold))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(GardenTheme.primary)
        .frame(minHeight: 54)
        .padding(.horizontal, 16)
        .background(GardenTheme.softFill)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                .stroke(GardenTheme.primary.opacity(0.18), lineWidth: 1)
        }
    }

    private func homeDisabledPlanButton(title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
            Text(title)
                .font(.headline.weight(.semibold))
            Spacer()
        }
        .foregroundStyle(AppColors.secondaryText)
        .frame(minHeight: 54)
        .padding(.horizontal, 16)
        .background(AppColors.cardTint.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                .stroke(AppColors.border.opacity(0.62), lineWidth: 1)
        }
        .disabled(true)
    }

    private var weeklyRoutineSection: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                GardenSectionHeader("이번 주 루틴", subtitle: "작은 정원이 매일의 기록으로 채워집니다.")

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(weeklySummary) { summary in
                        weeklyGardenCell(summary)
                    }
                }
            }
        }
    }

    private func growthStatusItem(
        icon: String,
        title: String,
        isCompleted: Bool,
        tint: Color,
        isMock: Bool = false
    ) -> some View {
        let pendingTint = Color(hex: 0xC75D5D)
        let iconTint = isCompleted ? GardenTheme.primary : pendingTint
        let iconBackground = isCompleted ? GardenTheme.primary.opacity(0.12) : pendingTint.opacity(0.18)
        let statusTint = isCompleted ? GardenTheme.primary : pendingTint
        let borderTint = isCompleted ? GardenTheme.primary.opacity(0.20) : pendingTint.opacity(0.28)

        return VStack(spacing: 8) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : icon)
                .font(.headline)
                .foregroundStyle(iconTint)
                .frame(width: 34, height: 34)
                .background(iconBackground)
                .clipShape(Circle())

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.primaryText)

            Text(isCompleted ? "완료" : isMock ? "준비중" : "대기")
                .font(.caption2.weight(.bold))
                .foregroundStyle(statusTint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(borderTint, lineWidth: 0.8)
        }
    }

    private func metricPill(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.bold())
                .foregroundStyle(AppColors.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(GardenTheme.softFill)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
    }

    private func collapsedRoutineCard(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        isExpanded: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.secondaryText)
            }
            .padding(14)
            .gardenCardSurface(
                background: GardenTheme.cardBackground.opacity(0.82),
                border: tint.opacity(0.18),
                cornerRadius: AppRadius.card,
                shadowRadius: 6,
                shadowY: 3
            )
        }
        .buttonStyle(.plain)
    }

    private func homeCompactButton(
        title: String,
        icon: String,
        isPrimary: Bool = false,
        isDisabled: Bool = false,
        isNeutral: Bool = false
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
            Text(title)
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(compactButtonForeground(isPrimary: isPrimary, isDisabled: isDisabled, isNeutral: isNeutral))
        .frame(maxWidth: .infinity)
        .frame(minHeight: 44)
        .background(compactButtonBackground(isPrimary: isPrimary, isDisabled: isDisabled, isNeutral: isNeutral))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                .stroke(compactButtonBorder(isPrimary: isPrimary, isNeutral: isNeutral), lineWidth: 0.8)
        }
        .opacity(isDisabled ? 0.72 : 1)
    }

    private func compactButtonForeground(isPrimary: Bool, isDisabled: Bool, isNeutral: Bool) -> Color {
        if isDisabled { return AppColors.subtleText }
        if isPrimary { return .white }
        if isNeutral { return AppColors.secondaryText }
        return GardenTheme.primary
    }

    private func compactButtonBackground(isPrimary: Bool, isDisabled: Bool, isNeutral: Bool) -> Color {
        if isDisabled { return AppColors.cardTint.opacity(0.6) }
        if isPrimary { return GardenTheme.primary }
        if isNeutral { return Color(hex: 0xEEF0EC) }
        return GardenTheme.softFill
    }

    private func compactButtonBorder(isPrimary: Bool, isNeutral: Bool) -> Color {
        if isPrimary { return .clear }
        if isNeutral { return Color(hex: 0xD7DCD4) }
        return AppColors.border.opacity(0.72)
    }

    private func weeklyGardenCell(_ summary: HabitDaySummary) -> some View {
        let isToday = calendar.isDateInToday(summary.date)

        return VStack(spacing: 7) {
            Text(summary.date.formatted(.dateTime.weekday(.narrow)))
                .font(.caption2.weight(.bold))
                .foregroundStyle(isToday ? GardenTheme.primary : AppColors.secondaryText)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(color(for: summary.totalCount))
                .frame(height: 34)
                .overlay {
                    VStack(spacing: 3) {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(summary.bibleCount > 0 ? Color.white.opacity(0.95) : Color.white.opacity(0.36))
                                .frame(width: 5, height: 5)
                            Circle()
                                .fill(summary.prayerCount > 0 ? Color.white.opacity(0.95) : Color.white.opacity(0.36))
                                .frame(width: 5, height: 5)
                        }
                        if summary.totalCount > 1 {
                            Circle()
                                .fill(Color.white.opacity(0.92))
                                .frame(width: 5, height: 5)
                        }
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isToday ? GardenTheme.primary.opacity(0.62) : AppColors.border.opacity(0.55), lineWidth: isToday ? 1.2 : 0.8)
                }

            Text(summary.date.formatted(.dateTime.day()))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.subtleText)
        }
        .frame(maxWidth: .infinity)
    }

    private func color(for totalCount: Int) -> Color {
        switch totalCount {
        case 0: return AppColors.grassInactive.opacity(0.72)
        case 1: return GardenTheme.primary.opacity(0.50)
        case 2: return GardenTheme.primary.opacity(0.74)
        default: return GardenTheme.secondary
        }
    }

    private var todayVersePreview: String {
        guard let todayVerse else {
            return "오늘의 말씀을 준비하는 중입니다."
        }
        if todayVerse.displayText.count <= 86 {
            return todayVerse.displayText
        }
        return String(todayVerse.displayText.prefix(86)) + "..."
    }

    private var isTodayQuietTimeCompleted: Bool {
        qtStore.isCompleted(dateKey: todayQTContent.id) || hasTodayGardenActivity(.qtCompleted)
    }

    private var shouldShowTodayQuietTimeCard: Bool {
        true
    }

    private var shouldShowTodayVerseCard: Bool {
        !isTodayVerseCompleted || isCompletedVerseExpanded
    }

    private var shouldShowFeaturedWritingPlanCard: Bool {
        guard planState.displayedPlan != nil else { return true }
        if planState.isTodayAssignmentCompleted || planState.displayedPlan?.status == .completed {
            return isCompletedWritingPlanExpanded
        }
        return planState.todayAssignment != nil || planState.missedCount > 0 || planState.isPaused
    }

    private var isTodayVerseCompleted: Bool {
        guard let todayVerse else {
            return false
        }

        return GardenActivityTimelineBuilder.activities(timelineActivities, on: Date(), calendar: calendar)
            .contains { activity in
                guard activity.type == .scriptureCopy else { return false }

                if let verseId = todayVerse.verse?.id,
                   activity.verseId == verseId {
                    return true
                }

                return activity.reference?.normalizedHomeReference == todayVerse.referenceText.normalizedHomeReference
            }
    }

    private var todayQuietTimeButtonTitle: String {
        qtStore.hasDraft(dateKey: todayQTContent.id) ? "오늘의 QT 이어하기" : "오늘의 QT 시작하기"
    }

    private var quietTimeContextID: String {
        "\(authViewModel.currentUser?.uid ?? "signed-out")|\(communityStore.currentCommunity?.id ?? "global")"
    }

    private var planSupportSubtitle: String {
        if let displayedPlan = planState.displayedPlan {
            if planState.isPaused {
                return "잠시 멈춘 플랜 · \(planState.remainingDaysLabel)"
            }
            if let rangeText = planState.todayRangeText {
                return "\(planState.dayLabel) · 오늘 \(rangeText)"
            }
            return "\(displayedPlan.completedDays)일 완료 · \(planState.remainingDaysLabel)"
        }
        return "원하는 성경 범위를 정하고, 매일 조금씩 말씀을 따라 써보세요."
    }

    private var todaySummary: HabitDaySummary { metrics.todaySummary }
    private var weeklySummary: [HabitDaySummary] { metrics.weeklySummary }
    private var currentStreak: Int { metrics.currentStreak }

    private var todayGardenActivityCount: Int {
        GardenActivityTimelineBuilder.gardenGrowthActivities(timelineActivities, on: Date(), calendar: calendar).count
    }

    private func hasTodayGardenActivity(_ type: GardenActivityType) -> Bool {
        GardenActivityTimelineBuilder.activities(timelineActivities, on: Date(), calendar: calendar).contains { $0.type == type }
    }

    private func hasTodayGardenActivity(_ type: GardenActivityType, verseId: String) -> Bool {
        GardenActivityTimelineBuilder.activities(timelineActivities, on: Date(), calendar: calendar)
            .contains { $0.type == type && $0.verseId == verseId }
    }

    private func shouldKeepWritingPlanExpandedAfterSelection(_ plan: ScriptureWritingPlan) -> Bool {
        if plan.status == .completed {
            return true
        }

        let currentUserAssignments = assignments.assignments(for: authViewModel.currentUser?.uid)
        let todayAssignment = ScriptureWritingPlanService.todayAssignment(
            for: plan,
            assignments: currentUserAssignments,
            userID: authViewModel.currentUser?.uid,
            calendar: calendar
        )
        return todayAssignment?.state == .completed
    }

    private var recentActivities: [HomeRecentActivity] {
        timelineActivities
            .filter { $0.type.appearsInRecentActivity }
            .prefix(3)
            .map { activity in
                HomeRecentActivity(
                    title: activity.type.displayTitle,
                    subtitle: activity.reference ?? activity.contentPreview ?? "오늘의 Garden 활동",
                    icon: activity.type.iconName,
                    tint: homeActivityTint(for: activity.type),
                    date: activity.createdAt
                )
            }
    }

    private var recordsSignature: String {
        let uid = authViewModel.currentUser?.uid ?? ""
        let bible = records.map { "\($0.id.uuidString)-\($0.ownerUserId)-\($0.completedAt.timeIntervalSince1970)" }.joined(separator: "|")
        let prayer = prayerRecords.map { "\($0.id.uuidString)-\($0.ownerUserId)-\($0.completedAt.timeIntervalSince1970)" }.joined(separator: "|")
        let qt = qtStore.records.map { "\($0.id)-\($0.completedAt?.timeIntervalSince1970 ?? 0)-\($0.updatedAt.timeIntervalSince1970)" }.joined(separator: "|")
        let liked = likedVerseStore.getLikedVerseRecords().map { "\($0.verseId)-\($0.createdAt.timeIntervalSince1970)" }.joined(separator: "|")
        let activityLog = gardenActivityStore.activities.map { "\($0.id)-\($0.type.rawValue)-\($0.createdAt.timeIntervalSince1970)" }.joined(separator: "|")
        let planSignature = plans.map { "\($0.id.uuidString)-\($0.ownerUserId)-\($0.statusRaw)-\($0.completedDays)-\($0.updatedAt.timeIntervalSince1970)" }.joined(separator: "|")
        let assignmentSignature = assignments.map { "\($0.id.uuidString)-\($0.ownerUserId)-\($0.planLocalId.uuidString)-\($0.stateRaw)-\($0.completedAt?.timeIntervalSince1970 ?? 0)-\($0.completionRecordIdsRaw)" }.joined(separator: "|")
        let selectedPlan = writingPlanSelectionStore.selectedPlanId ?? ""
        return "\(uid)#\(selectedPlan)#\(bible)#\(prayer)#\(qt)#\(liked)#\(activityLog)#\(planSignature)#\(assignmentSignature)"
    }

    private func resolveDisplayedPlan(
        from plans: [ScriptureWritingPlan],
        assignments: [PlanDayAssignment]
    ) -> ScriptureWritingPlan? {
        let candidates = plans
            .filter { $0.status == .active }
            .sorted { lhs, rhs in
                if lhs.status == rhs.status {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.status.sortPriority < rhs.status.sortPriority
            }

        guard !candidates.isEmpty else { return nil }

        let selectedPlan = writingPlanSelectionStore.selectedPlanId.flatMap { selectedId in
            candidates.first { $0.id.uuidString == selectedId }
        }

        let incompleteTodayPlan = candidates.first { plan in
            guard plan.status == .active,
                  let todayAssignment = ScriptureWritingPlanService.todayAssignment(
                    for: plan,
                    assignments: assignments,
                    userID: authViewModel.currentUser?.uid,
                    calendar: calendar
                  ) else {
                return false
            }
            return todayAssignment.state != .completed
        }

        if let selectedPlan {
            return selectedPlan
        }

        if let incompleteTodayPlan {
            return incompleteTodayPlan
        }

        return candidates.first { plan in
            ScriptureWritingPlanService.missedCount(
                for: plan,
                assignments: assignments,
                userID: authViewModel.currentUser?.uid
            ) > 0
        } ?? candidates.first
    }

    private func refreshMetrics() {
        let activities = timelineActivities
        metrics = HomeMetrics(
            todaySummary: GardenActivityTimelineBuilder.daySummaries(from: activities, calendar: calendar)[calendar.startOfDay(for: Date())]
                ?? HabitDaySummary(date: calendar.startOfDay(for: Date()), bibleCount: 0, prayerCount: 0),
            weeklySummary: GardenActivityTimelineBuilder.weeklySummary(from: activities, calendar: calendar),
            currentStreak: GardenActivityTimelineBuilder.currentStreak(from: activities, calendar: calendar)
        )

        let currentUserPlans = self.currentUserPlans
        let currentUserAssignments = assignments.assignments(for: authViewModel.currentUser?.uid)
        let displayedPlan = resolveDisplayedPlan(
            from: currentUserPlans,
            assignments: currentUserAssignments
        )

        if writingPlanSelectionStore.selectedPlanId != displayedPlan?.id.uuidString {
            writingPlanSelectionStore.selectPlan(displayedPlan)
        }

        if let displayedPlan {
            let todayAssignment = ScriptureWritingPlanService.todayAssignment(
                for: displayedPlan,
                assignments: currentUserAssignments,
                userID: authViewModel.currentUser?.uid,
                calendar: calendar
            )
            let missedCount = ScriptureWritingPlanService.missedCount(
                for: displayedPlan,
                assignments: currentUserAssignments,
                userID: authViewModel.currentUser?.uid
            )
            let assignmentVerses = todayAssignment.map { ScriptureWritingPlanService.verses(for: $0) } ?? []
            let completedVerseCount = todayAssignment?.completionRecordIds.count ?? 0
            let todayVerseCount = todayAssignment?.verseCount ?? 0
            let todayProgressValue = todayVerseCount > 0
                ? min(Double(completedVerseCount) / Double(todayVerseCount), 1)
                : 0
            let safeStartIndex = assignmentVerses.isEmpty ? 0 : min(completedVerseCount, max(assignmentVerses.count - 1, 0))
            let launchVerse = assignmentVerses[safe: safeStartIndex]
            let launchContext: WritingContext? = {
                guard let todayAssignment, !assignmentVerses.isEmpty else { return nil }
                return .plan(
                    planId: displayedPlan.id,
                    assignmentId: todayAssignment.id,
                    verses: assignmentVerses,
                    currentIndex: safeStartIndex
                )
            }()

            let dayLabel: String = {
                if let todayAssignment {
                    return "Day \(todayAssignment.dayIndex) / \(displayedPlan.totalDays)"
                }
                return "Day \(min(displayedPlan.completedDays + 1, displayedPlan.totalDays)) / \(displayedPlan.totalDays)"
            }()

            let statusMessage: String? = {
                if displayedPlan.status == .paused {
                    return "플랜이 잠시 멈춰 있습니다."
                }
                if todayAssignment == nil && displayedPlan.startDate > calendar.startOfDay(for: Date()) {
                    return "\(displayedPlan.startDate.formatted(.dateTime.month().day()))에 시작합니다."
                }
                if todayAssignment == nil && missedCount > 0 {
                    return "오늘 할당은 없지만 놓친 필사가 남아 있습니다."
                }
                return nil
            }()

            planState = HomePlanState(
                displayedPlan: displayedPlan,
                todayAssignment: todayAssignment,
                launchVerse: launchVerse,
                launchContext: launchContext,
                dayLabel: dayLabel,
                todayProgressLabel: "오늘 \(Int(todayProgressValue * 100))% 완료",
                todayProgressValue: todayProgressValue,
                todayCompletionLabel: todayVerseCount > 0 ? "\(min(completedVerseCount, todayVerseCount)) / \(todayVerseCount)절" : "오늘 분량 대기",
                todayRangeText: todayAssignment.map { ScriptureWritingPlanService.rangeText(for: $0) },
                remainingDaysLabel: "\(displayedPlan.remainingDays)일 남음",
                missedCount: missedCount,
                isPaused: displayedPlan.status == .paused,
                isTodayAssignmentCompleted: todayAssignment?.state == .completed,
                statusMessage: statusMessage
            )
        } else {
            planState = .empty
        }
    }

    private func homeActivityTint(for type: GardenActivityType) -> Color {
        switch type {
        case .verseRead, .qtCompleted:
            return GardenTheme.primary
        case .verseLiked, .prayer:
            return GardenTheme.tertiary
        case .scriptureCopy:
            return GardenTheme.secondary
        }
    }
}

private struct HomeMetrics {
    let todaySummary: HabitDaySummary
    let weeklySummary: [HabitDaySummary]
    let currentStreak: Int

    static let empty = HomeMetrics(
        todaySummary: HabitDaySummary(date: Calendar.current.startOfDay(for: Date()), bibleCount: 0, prayerCount: 0),
        weeklySummary: [],
        currentStreak: 0
    )
}

private struct HomePlanState {
    let displayedPlan: ScriptureWritingPlan?
    let todayAssignment: PlanDayAssignment?
    let launchVerse: LocalBibleVerse?
    let launchContext: WritingContext?
    let dayLabel: String
    let todayProgressLabel: String
    let todayProgressValue: Double
    let todayCompletionLabel: String
    let todayRangeText: String?
    let remainingDaysLabel: String
    let missedCount: Int
    let isPaused: Bool
    let isTodayAssignmentCompleted: Bool
    let statusMessage: String?

    static let empty = HomePlanState(
        displayedPlan: nil,
        todayAssignment: nil,
        launchVerse: nil,
        launchContext: nil,
        dayLabel: "",
        todayProgressLabel: "오늘 0% 완료",
        todayProgressValue: 0,
        todayCompletionLabel: "0 / 0절",
        todayRangeText: nil,
        remainingDaysLabel: "",
        missedCount: 0,
        isPaused: false,
        isTodayAssignmentCompleted: false,
        statusMessage: nil
    )
}

private struct HomeRecentActivity: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let date: Date
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

private extension String {
    var normalizedHomeReference: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}

private extension ScriptureWritingPlanStatus {
    var sortPriority: Int {
        switch self {
        case .active:
            return 0
        case .paused:
            return 1
        case .completed:
            return 2
        case .cancelled:
            return 3
        }
    }
}
