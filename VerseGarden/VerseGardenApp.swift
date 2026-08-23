import Combine
import FirebaseAuth
import FirebaseCore
import SwiftData
import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if DEBUG
        print("✅ AppDelegate didFinishLaunching")
        #endif
        FirebaseApp.configure()
        #if DEBUG
        print("✅ Firebase configured")
        #endif
        return true
    }
}

@main
struct VerseGardenApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppSceneRootView()
        }
        .modelContainer(for: [
            BibleVerse.self,
            WritingRecord.self,
            MyVerseList.self,
            MyVerseListItem.self,
            ScriptureWritingPlan.self,
            PlanDayAssignment.self,
            PrayerTemplate.self,
            PrayerWritingRecord.self
        ])
    }
}

private struct AppSceneRootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var syncCoordinator = WritingRecordSyncCoordinator()
    @StateObject private var verseListSyncCoordinator = VerseListSyncCoordinator()
    @StateObject private var prayerSyncCoordinator = PrayerSyncCoordinator()
    @StateObject private var writingPlanSyncCoordinator = WritingPlanSyncCoordinator()
    @StateObject private var likedVerseSyncCoordinator = LikedVerseSyncCoordinator()
    @StateObject private var qtRecordSyncCoordinator = QTRecordSyncCoordinator()
    @StateObject private var userProfileStore = UserProfileStore()
    @StateObject private var reminderScheduler = ReminderScheduler()
    @StateObject private var likedVerseStore = LikedVerseStore()
    @StateObject private var gardenActivityStore = GardenActivityStore()
    @StateObject private var qtStore = QTStore()
    @StateObject private var todayQuietTimeContentStore = TodayQuietTimeContentStore()
    @StateObject private var writingPlanSelectionStore = WritingPlanSelectionStore()

    var body: some View {
        AppRootView()
            .environmentObject(authViewModel)
            .environmentObject(syncCoordinator)
            .environmentObject(verseListSyncCoordinator)
            .environmentObject(prayerSyncCoordinator)
            .environmentObject(writingPlanSyncCoordinator)
            .environmentObject(likedVerseSyncCoordinator)
            .environmentObject(qtRecordSyncCoordinator)
            .environmentObject(userProfileStore)
            .environmentObject(reminderScheduler)
            .environmentObject(likedVerseStore)
            .environmentObject(gardenActivityStore)
            .environmentObject(qtStore)
            .environmentObject(todayQuietTimeContentStore)
            .environmentObject(writingPlanSelectionStore)
            .task {
                configureStoreSyncCallbacks()
                authViewModel.startAuthStateListener()
                await reminderScheduler.refreshAuthorizationStatus()
            }
            .onChange(of: authViewModel.currentUser?.uid) { _, userID in
                likedVerseStore.setActiveUserID(userID)
                gardenActivityStore.setActiveUserID(userID)
                qtStore.setActiveUserID(userID)
                writingPlanSelectionStore.setActiveUserID(userID)
            }
    }

    private func configureStoreSyncCallbacks() {
        likedVerseStore.onLikeChanged = { verseId, isLiked in
            Task { @MainActor in
                await likedVerseSyncCoordinator.syncChange(
                    verseId: verseId,
                    isLiked: isLiked,
                    createdAt: likedVerseStore.likedRecord(verseId: verseId)?.createdAt,
                    userID: authViewModel.currentUser?.uid
                )
            }
        }

        qtStore.onRecordChanged = { record in
            Task { @MainActor in
                await qtRecordSyncCoordinator.uploadRecord(
                    record,
                    userID: authViewModel.currentUser?.uid
                )
            }
        }

        writingPlanSelectionStore.onSelectionChanged = { selectedPlanId in
            Task { @MainActor in
                await userProfileStore.updateSelectedWritingPlanId(
                    selectedPlanId,
                    for: authViewModel.currentUser
                )
            }
        }
    }
}

private struct AppRootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var syncCoordinator: WritingRecordSyncCoordinator
    @EnvironmentObject private var verseListSyncCoordinator: VerseListSyncCoordinator
    @EnvironmentObject private var prayerSyncCoordinator: PrayerSyncCoordinator
    @EnvironmentObject private var writingPlanSyncCoordinator: WritingPlanSyncCoordinator
    @EnvironmentObject private var likedVerseSyncCoordinator: LikedVerseSyncCoordinator
    @EnvironmentObject private var qtRecordSyncCoordinator: QTRecordSyncCoordinator
    @EnvironmentObject private var userProfileStore: UserProfileStore
    @EnvironmentObject private var likedVerseStore: LikedVerseStore
    @EnvironmentObject private var qtStore: QTStore
    @EnvironmentObject private var writingPlanSelectionStore: WritingPlanSelectionStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \MyVerseListItem.updatedAt, order: .reverse) private var widgetVerseItems: [MyVerseListItem]
    @State private var lastForegroundSyncAt: Date?
    @State private var isRunningRootSync = false

    var body: some View {
        Group {
            if authViewModel.isLoading && !authViewModel.isLoggedIn && authViewModel.isFirebaseConfigured {
                ProgressView("인증 상태를 확인하는 중...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            } else if authViewModel.isLoggedIn {
                authenticatedContent
            } else {
                AuthView()
            }
        }
        .task(id: authViewModel.currentUser?.uid) {
            if let currentUser = authViewModel.currentUser {
                await performUserDataSync(for: currentUser, force: true)
            } else {
                userProfileStore.clear()
                syncCoordinator.stopSync()
                verseListSyncCoordinator.stopSync()
                prayerSyncCoordinator.stopSync()
                writingPlanSyncCoordinator.stopSync()
                likedVerseStore.setActiveUserID(nil)
                qtStore.setActiveUserID(nil)
                writingPlanSelectionStore.setActiveUserID(nil)
                WidgetPayloadWriter.refresh(userID: nil, savedVerseItems: [])
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, let currentUser = authViewModel.currentUser else { return }
            Task {
                await performUserDataSync(for: currentUser, force: false)
            }
        }
    }

    private func performUserDataSync(for currentUser: User, force: Bool) async {
        guard !isRunningRootSync else { return }

        if !force,
           let lastForegroundSyncAt,
           Date().timeIntervalSince(lastForegroundSyncAt) < 60 {
            return
        }

        isRunningRootSync = true
        defer {
            isRunningRootSync = false
            lastForegroundSyncAt = Date()
        }

        likedVerseStore.setActiveUserID(currentUser.uid)
        qtStore.setActiveUserID(currentUser.uid)
        writingPlanSelectionStore.setActiveUserID(currentUser.uid)

        await userProfileStore.syncProfile(for: currentUser)
        await userProfileStore.syncSelectedWritingPlanPreference(
            selectionStore: writingPlanSelectionStore,
            for: currentUser
        )
        await likedVerseSyncCoordinator.syncForAuthenticatedUser(
            userID: currentUser.uid,
            store: likedVerseStore
        )
        await qtRecordSyncCoordinator.syncForAuthenticatedUser(
            userID: currentUser.uid,
            store: qtStore
        )
        await syncCoordinator.syncForAuthenticatedUser(
            userID: currentUser.uid,
            modelContext: modelContext
        )
        await verseListSyncCoordinator.syncForAuthenticatedUser(
            userID: currentUser.uid,
            modelContext: modelContext
        )
        prayerSyncCoordinator.seedDefaultTemplatesIfNeeded(modelContext: modelContext)
        await prayerSyncCoordinator.syncForAuthenticatedUser(
            userID: currentUser.uid,
            modelContext: modelContext
        )
        await writingPlanSyncCoordinator.syncForAuthenticatedUser(
            userID: currentUser.uid,
            modelContext: modelContext
        )
        WidgetPayloadWriter.refresh(
            userID: currentUser.uid,
            savedVerseItems: widgetVerseItems
        )
    }

    @ViewBuilder
    private var authenticatedContent: some View {
        if !userProfileStore.hasResolvedProfile(for: authViewModel.currentUser?.uid) || userProfileStore.isLoadingProfile {
            ProgressView("프로필 정보를 불러오는 중...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
        } else if let currentUser = authViewModel.currentUser,
                  let profile = userProfileStore.profile {
            if profile.onboardingCompleted {
                RootTabView()
            } else {
                OnboardingView {
                    await userProfileStore.completeOnboarding(
                        selectedTopics: $0,
                        favoriteVerse: $1,
                        for: currentUser
                    )
                }
            }
        } else {
            AuthView()
        }
    }
}

struct RootTabView: View {
    @State private var selectedTab: AppTab = .home

    init() {
        Self.configureTabBarAppearance()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                VerseView()
            }
            .tag(AppTab.verse)
            .tabItem {
                Label("Verse", systemImage: "book")
            }

            NavigationStack {
                PrayerHomeView()
            }
            .tag(AppTab.prayer)
            .tabItem {
                Label("Prayer", systemImage: "hands.sparkles")
            }

            NavigationStack {
                HomeView()
            }
            .tag(AppTab.home)
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                GardenView()
            }
            .tag(AppTab.garden)
            .tabItem {
                Label("Garden", systemImage: "square.grid.3x3")
            }

            NavigationStack {
                ProfileView()
            }
            .tag(AppTab.profile)
            .tabItem {
                Label("Profile", systemImage: "person")
            }
        }
        .tint(GardenTheme.secondary)
        .onOpenURL { url in
            handleDeepLink(url)
        }
    }

    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = UIColor(AppColors.cardBackground).withAlphaComponent(0.74)
        appearance.shadowColor = UIColor(AppColors.deepGreen).withAlphaComponent(0.08)
        appearance.selectionIndicatorImage = tabSelectionIndicatorImage()

        configureItemAppearance(appearance.stackedLayoutAppearance)
        configureItemAppearance(appearance.inlineLayoutAppearance)
        configureItemAppearance(appearance.compactInlineLayoutAppearance)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = UIColor(AppColors.deepGreen)
        UITabBar.appearance().unselectedItemTintColor = UIColor(AppColors.secondaryText).withAlphaComponent(0.74)
    }

    private static func configureItemAppearance(_ itemAppearance: UITabBarItemAppearance) {
        itemAppearance.normal.iconColor = UIColor(AppColors.secondaryText).withAlphaComponent(0.74)
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.secondaryText).withAlphaComponent(0.74),
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]

        itemAppearance.selected.iconColor = UIColor(AppColors.deepGreen)
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.deepGreen),
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]
    }

    private static func tabSelectionIndicatorImage() -> UIImage {
        let size = CGSize(width: 64, height: 46)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            UIColor(AppColors.sageGreen).withAlphaComponent(0.18).setFill()
            UIBezierPath(
                roundedRect: CGRect(x: 3, y: 4, width: size.width - 6, height: size.height - 8),
                cornerRadius: 23
            ).fill()
        }
        return image.resizableImage(
            withCapInsets: UIEdgeInsets(top: 22, left: 22, bottom: 22, right: 22),
            resizingMode: .stretch
        )
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "versegarden" else { return }

        switch url.host {
        case "profile":
            selectedTab = .profile
        case "verse":
            if url.path == "/today" {
                selectedTab = .home
            } else {
                selectedTab = .verse
            }
        default:
            break
        }
    }
}

private enum AppTab {
    case verse
    case prayer
    case home
    case garden
    case profile
}
