import Combine
import FirebaseAuth
import FirebaseCore
import UIKit
import SwiftData
import SwiftUI

@main
struct VerseGardenApp: App {
    @UIApplicationDelegateAdaptor(VerseGardenAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            AppSceneRootView()
        }
        .modelContainer(for: [BibleVerse.self, WritingRecord.self, MyVerseList.self, MyVerseListItem.self])
    }
}

final class VerseGardenAppDelegate: NSObject, UIApplicationDelegate {
    static private(set) var didConfigureFirebase = false

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard FirebaseApp.app() == nil else {
            Self.didConfigureFirebase = true
            return true
        }
        guard let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let options = FirebaseOptions(contentsOfFile: filePath) else {
            return true
        }

        FirebaseApp.configure(options: options)
        Self.didConfigureFirebase = true
        return true
    }
}

private struct AppSceneRootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var syncCoordinator = WritingRecordSyncCoordinator()
    @StateObject private var verseListSyncCoordinator = VerseListSyncCoordinator()
    @StateObject private var userProfileStore = UserProfileStore()

    var body: some View {
        AppRootView()
            .environmentObject(authViewModel)
            .environmentObject(syncCoordinator)
            .environmentObject(verseListSyncCoordinator)
            .environmentObject(userProfileStore)
            .task {
                while !VerseGardenAppDelegate.didConfigureFirebase {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
                authViewModel.startAuthStateListener()
            }
    }
}

private struct AppRootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var syncCoordinator: WritingRecordSyncCoordinator
    @EnvironmentObject private var verseListSyncCoordinator: VerseListSyncCoordinator
    @EnvironmentObject private var userProfileStore: UserProfileStore
    @Environment(\.modelContext) private var modelContext

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
                await userProfileStore.syncProfile(for: currentUser)
                await syncCoordinator.syncForAuthenticatedUser(
                    userID: currentUser.uid,
                    modelContext: modelContext
                )
                await verseListSyncCoordinator.syncForAuthenticatedUser(
                    userID: currentUser.uid,
                    modelContext: modelContext
                )
            } else {
                userProfileStore.clear()
                syncCoordinator.stopSync()
                verseListSyncCoordinator.stopSync()
            }
        }
    }

    @ViewBuilder
    private var authenticatedContent: some View {
        if !userProfileStore.hasResolvedProfile(for: authViewModel.currentUser?.uid) || userProfileStore.isLoadingProfile {
            ProgressView("프로필 정보를 불러오는 중...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
        } else if userProfileStore.requiresNicknameSetup {
            NicknameSetupView()
        } else {
            RootTabView()
        }
    }
}

struct RootTabView: View {
    @State private var selectedTab: AppTab = .home
    @State private var selectedHistoryDate: Date?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tag(AppTab.home)
            .tabItem {
                Label("홈", systemImage: "house.fill")
            }

            NavigationStack {
                GrassView { date in
                    selectedHistoryDate = date
                    selectedTab = .history
                }
            }
            .tag(AppTab.grass)
            .tabItem {
                Label("잔디", systemImage: "square.grid.3x3.fill")
            }

            NavigationStack {
                MyVerseListView()
            }
            .tag(AppTab.list)
            .tabItem {
                Label("리스트", systemImage: "bookmark.fill")
            }

            NavigationStack {
                HistoryView(selectedDate: $selectedHistoryDate)
            }
            .tag(AppTab.history)
            .tabItem {
                Label("기록", systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                ProfileView()
            }
            .tag(AppTab.account)
            .tabItem {
                Label("계정", systemImage: "person.crop.circle")
            }
        }
        .tint(.green)
    }
}

private enum AppTab {
    case home
    case grass
    case list
    case history
    case account
}
