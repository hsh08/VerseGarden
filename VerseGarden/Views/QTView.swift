import SwiftUI

struct QTView: View {
    private var todayVerse: TodayVerseContent? {
        TodayVerseService.todayVerse()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                todayQuietTimeCard
                versePlaceholderCard
                reflectionQuestionCard
                readyStateCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("QT")
        .background(GardenTheme.background)
    }

    private var todayQuietTimeCard: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.26), AppColors.cardTint.opacity(0.62)],
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
                            .background(Color.white.opacity(0.62))
                            .clipShape(Capsule())

                        Text(todayVerse?.referenceText ?? "오늘의 말씀")
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

                Text("말씀을 읽고, 필사하고, 묵상으로 오늘의 마음을 정리하는 공간입니다.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineSpacing(4)

                NavigationLink {
                    TodayQuietTimeView(
                        todayVerse: todayVerse,
                        planLaunchVerse: nil,
                        planLaunchContext: nil,
                        isPlanPaused: false,
                        isWritingCompleted: false
                    )
                } label: {
                    GardenPrimaryButtonLabel(title: "큐티 시작하기", icon: "leaf.fill")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var versePlaceholderCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 10) {
                GardenSectionHeader("말씀 본문", subtitle: todayVerse?.referenceText)
                Text(todayVersePreview)
                    .font(.body)
                    .foregroundStyle(AppColors.primaryText)
                    .lineSpacing(6)
                    .lineLimit(5)
            }
        }
    }

    private var reflectionQuestionCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 12) {
                GardenSectionHeader("묵상 질문", subtitle: "말씀을 읽고 오늘의 마음과 적용을 차분히 정리합니다.")
                VStack(alignment: .leading, spacing: 10) {
                    questionRow("오늘 말씀에서 마음에 남는 단어는 무엇인가요?")
                    questionRow("오늘 내가 순종으로 심을 작은 행동은 무엇인가요?")
                }
            }
        }
    }

    private var readyStateCard: some View {
        GardenCard {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.headline)
                    .foregroundStyle(GardenTheme.primary)
                    .frame(width: 40, height: 40)
                    .background(GardenTheme.softFill)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("오늘의 큐티는 Home에서 이어갈 수 있어요")
                        .font(.headline)
                        .foregroundStyle(AppColors.primaryText)
                    Text("완료한 묵상과 기도는 Garden 기록에 함께 쌓입니다.")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(2)
                }
            }
        }
    }

    private func questionRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "questionmark.circle.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(GardenTheme.primary)
                .padding(.top, 2)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.primaryText)
        }
        .padding(12)
        .background(GardenTheme.softFill.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
    }

    private var todayVersePreview: String {
        guard let todayVerse else {
            return "오늘의 말씀을 준비하는 중입니다."
        }
        return todayVerse.displayText
    }
}
