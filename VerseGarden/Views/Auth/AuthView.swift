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
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .overlay {
                if authViewModel.isSubmitting {
                    ZStack {
                        Color.black.opacity(0.06)
                            .ignoresSafeArea()
                        ProgressView("처리 중...")
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color(.systemBackground))
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
            backgroundGradient
                .edgesIgnoringSafeArea(.all)

            decorativeGrassField
                .opacity(gridOpacity)

            VStack(alignment: .leading, spacing: 0) {
                heroSection

                Spacer(minLength: 20)

                grassSection

                if let setupMessage = authViewModel.setupMessage {
                    Text(setupMessage)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.top, 28)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 40)
        }
        .safeAreaInset(edge: .bottom) {
            ZStack(alignment: .bottom) {
                // Changed: CTA 아래를 비워두지 않고 매우 연한 잔디 패턴으로 마감
                GrassGridView(rows: 3, columns: 12, filledCount: 20)
                    .opacity(0.07)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                actionSection
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
            }
            .background(
                LinearGradient(
                    colors: [Color.white.opacity(0.0), Color.white.opacity(0.82), Color.white.opacity(0.96)],
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

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color.white,
                Color.green.opacity(0.06),
                Color.mint.opacity(0.10),
                Color.green.opacity(0.16)
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

            // Changed: 브랜드 감성을 보강하는 작은 자연 아이콘 추가
            Label("조용히 자라는 기록의 정원", systemImage: "leaf.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.29, green: 0.42, blue: 0.36))
                .labelStyle(.titleAndIcon)

            Text("기록은 쌓이고, 믿음은 자랍니다.")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(red: 0.29, green: 0.42, blue: 0.36))

            Text("매일 한 구절씩 조용히 적어 내려가며\n나만의 정원을 천천히 채워보세요.")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineSpacing(10)
        }
    }

    private var grassSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("오늘의 잔디")
                .font(.headline)
                .foregroundStyle(Color(red: 0.29, green: 0.42, blue: 0.36))

            GrassGridView(rows: 5, columns: 7, filledCount: 12)

            Text("12/35")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.green)
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
                            colors: [Color.green, Color.mint],
                            startPoint: .leading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.green.opacity(0.12), radius: 18, x: 0, y: 10)
            }
            // Changed: 탭 시 살짝 눌리는 인터랙션 추가
            .buttonStyle(PrimaryAuthButtonStyle())
            .disabled(authViewModel.isSubmitting || !authViewModel.isFirebaseConfigured)
            .opacity(authViewModel.isSubmitting || !authViewModel.isFirebaseConfigured ? 0.6 : 1)

            Button(action: startLogin) {
                Text("이미 계정이 있나요? 로그인")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .opacity(0.72)
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
                .fill(Color.mint.opacity(0.08))
                .frame(width: 260, height: 260)
                .offset(x: 120, y: 130)

            Circle()
                .fill(Color.green.opacity(0.06))
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
