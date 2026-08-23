import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var userProfileStore: UserProfileStore
    @StateObject private var viewModel = OnboardingViewModel()
    let onComplete: ([String], String) async -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar

            TabView(selection: $viewModel.selectedPage) {
                ForEach(Array(viewModel.pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(
                        page: page,
                        index: index,
                        topics: viewModel.availableTopics,
                        selectedTopics: $viewModel.selectedTopics
                    )
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            bottomBar
        }
        .background(GardenTheme.background.ignoresSafeArea())
    }

    private var topBar: some View {
        HStack {
            Text("VerseGarden")
                .font(.headline.bold())
                .foregroundStyle(AppColors.primaryText)

            Spacer()

            Button("건너뛰기") {
                Task {
                    await complete()
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColors.secondaryText)
            .disabled(userProfileStore.isSaving)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(viewModel.pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == viewModel.selectedPage ? GardenTheme.primary : AppColors.border)
                        .frame(width: index == viewModel.selectedPage ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedPage)
                }
            }

            if let errorMessage = userProfileStore.errorMessage {
                Text(errorMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColors.destructiveRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppColors.destructiveFill.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.small, style: .continuous))
            }

            Button {
                if viewModel.isLastPage {
                    Task {
                        await complete()
                    }
                } else {
                    viewModel.moveNext()
                }
            } label: {
                HStack {
                    if userProfileStore.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(viewModel.isLastPage ? "VerseGarden 시작하기" : "다음")
                            .font(.headline)
                    }
                    Spacer()
                    Image(systemName: viewModel.isLastPage ? "checkmark.circle.fill" : "arrow.right")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(.vertical, 16)
                .padding(.horizontal, 18)
                .background(
                    LinearGradient(
                        colors: [GardenTheme.primary, GardenTheme.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(GardenAccentButtonStyle())
            .disabled(userProfileStore.isSaving)
            .opacity(userProfileStore.isSaving ? 0.7 : 1)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 24)
    }

    private func complete() async {
        await onComplete(viewModel.selectedTopicList, "")
    }
}

struct OnboardingGateView<Content: View>: View {
    let userID: String
    let content: Content
    @State private var hasCompletedOnboarding = true

    init(userID: String, @ViewBuilder content: () -> Content) {
        self.userID = userID
        self.content = content()
        _hasCompletedOnboarding = State(initialValue: OnboardingState.hasCompleted(userID: userID))
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                content
            } else {
                OnboardingView { _, _ in
                    OnboardingState.complete(userID: userID)
                    hasCompletedOnboarding = true
                }
            }
        }
        .task(id: userID) {
            hasCompletedOnboarding = OnboardingState.hasCompleted(userID: userID)
        }
    }
}

enum OnboardingState {
    static func key(for userID: String) -> String {
        AppGroupKeys.hasCompletedOnboardingKeyPrefix + userID
    }

    static func hasCompleted(userID: String) -> Bool {
        guard !userID.isEmpty else { return true }
        return UserDefaults.standard.bool(forKey: key(for: userID))
    }

    static func complete(userID: String) {
        guard !userID.isEmpty else { return }
        UserDefaults.standard.set(true, forKey: key(for: userID))
    }

    #if DEBUG
    static func reset(userID: String) {
        guard !userID.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: key(for: userID))
    }
    #endif
}
