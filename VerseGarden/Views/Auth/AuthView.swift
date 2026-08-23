import Combine
import SwiftUI

struct AuthView: View {
    enum AuthMode {
        case welcome
        case login
        case signup
    }

    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var mode: AuthMode = .welcome

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .welcome:
                    WelcomeAuthView(
                        startSignup: {
                            authViewModel.clearErrorMessage()
                            mode = .signup
                        },
                        startLogin: {
                            authViewModel.clearErrorMessage()
                            mode = .login
                        }
                    )
                case .login:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            LoginView {
                                mode = .signup
                            }
                        }
                        .padding()
                    }
                case .signup:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            SignupView {
                                mode = .login
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(GardenTheme.background)
            .navigationBarHidden(true)
            .overlay {
                if authViewModel.isSubmitting {
                    ZStack {
                        Color.black.opacity(0.06)
                            .ignoresSafeArea()
                        ProgressView("처리 중...")
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(GardenTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }
}

private struct WelcomeAuthView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var gridOpacity = 0.0

    let startSignup: () -> Void
    let startLogin: () -> Void

    var body: some View {
        ZStack {
            welcomeImageBackground

            welcomeImageOverlay

            VStack(alignment: .leading, spacing: 0) {
                heroSection

                if let setupMessage = authViewModel.setupMessage {
                    Text(setupMessage)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.28))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.top, 20)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 50)
            .padding(.bottom, 152)
        }
        .safeAreaInset(edge: .bottom) {
            ZStack(alignment: .bottom) {
                actionSection
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
            }
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.0), Color.black.opacity(0.34), Color.black.opacity(0.58)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                gridOpacity = 1
            }
        }
    }

    private var welcomeImageBackground: some View {
        Image("WelcomeJesusGarden")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
    }

    private var welcomeImageOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.44),
                    Color.white.opacity(0.18),
                    Color.black.opacity(0.28),
                    Color.black.opacity(0.60)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            LinearGradient(
                colors: [
                    GardenTheme.primary.opacity(0.10),
                    Color.clear,
                    GardenTheme.secondary.opacity(0.18)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        .ignoresSafeArea()
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.white,
                GardenTheme.primary.opacity(0.06),
                GardenTheme.secondary.opacity(0.10),
                GardenTheme.primary.opacity(0.16)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("VerseGarden")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .tracking(1.1)
                .foregroundStyle(AppColors.primaryText)
                .shadow(color: Color.white.opacity(0.74), radius: 12, x: 0, y: 3)

            Label("조용히 자라는 기록의 정원", systemImage: "leaf.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GardenTheme.secondary)
                .labelStyle(.titleAndIcon)

            Text("기록은 쌓이고, 믿음은 자랍니다.")
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppColors.primaryText)
                .shadow(color: Color.white.opacity(0.66), radius: 10, x: 0, y: 3)

            Text("매일 한 구절씩 조용히 적어 내려가며\n나만의 정원을 천천히 채워보세요.")
                .font(.body)
                .foregroundStyle(AppColors.secondaryText)
                .lineSpacing(10)
                .shadow(color: Color.white.opacity(0.62), radius: 8, x: 0, y: 3)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 6)
    }

    private var grassSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("오늘의 잔디")
                .font(.headline)
                .foregroundStyle(AppColors.secondaryText)

            GrassGridView(rows: 5, columns: 7, filledCount: 12)

            Text("12/35")
                .font(.title3.weight(.semibold))
                .foregroundStyle(GardenTheme.primary)
        }
        // Changed: 카드 느낌을 제거하고 섹션 자체만 남김
    }

    private var actionSection: some View {
        VStack(spacing: 14) {
            Button(action: startSignup) {
                Text("시작하기")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [GardenTheme.primary, GardenTheme.secondary],
                            startPoint: .leading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: GardenTheme.primary.opacity(0.12), radius: 18, x: 0, y: 10)
            }
            // Changed: 탭 시 살짝 눌리는 인터랙션 추가
            .buttonStyle(PrimaryAuthButtonStyle())
            .disabled(authViewModel.isSubmitting || !authViewModel.isFirebaseConfigured)
            .opacity(authViewModel.isSubmitting || !authViewModel.isFirebaseConfigured ? 0.6 : 1)

            Button(action: startLogin) {
                Text("이미 계정이 있나요? 로그인")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .opacity(0.82)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .disabled(authViewModel.isSubmitting)
        }
    }

    private var decorativeGrassField: some View {
        ZStack {
            Circle()
                .fill(GardenTheme.secondary.opacity(0.08))
                .frame(width: 260, height: 260)
                .offset(x: 120, y: 130)

            Circle()
                .fill(GardenTheme.primary.opacity(0.06))
                .frame(width: 220, height: 220)
                .offset(x: -140, y: 90)

            VStack(spacing: 18) {
                Spacer()

                GrassGridView(rows: 5, columns: 11, filledCount: 18)
                    .opacity(0.05)

                GrassGridView(rows: 5, columns: 11, filledCount: 26)
                    .opacity(0.07)

                GrassGridView(rows: 5, columns: 11, filledCount: 33)
                    .opacity(0.09)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

private struct PrimaryAuthButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
