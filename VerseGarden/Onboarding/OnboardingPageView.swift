import SwiftUI

struct OnboardingPageView: View {
    let page: OnboardingPage
    let index: Int
    let topics: [String]
    @Binding var selectedTopics: Set<String>

    private var accentColor: Color {
        switch page.accentName {
        case "mint":
            return GardenTheme.secondary
        case "teal":
            return GardenTheme.tertiary
        case "brown":
            return AppColors.accent
        default:
            return GardenTheme.primary
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                visual

                VStack(spacing: 12) {
                    Text(page.title)
                        .font(.title2.bold())
                        .foregroundStyle(AppColors.primaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(page.message)
                        .font(.body)
                        .lineSpacing(5)
                        .foregroundStyle(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 10)

                sampleCard
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)
        }
    }

    private var visual: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.12))
                .frame(width: 176, height: 176)

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accentColor.opacity(0.86), GardenTheme.secondary.opacity(0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 134, height: 134)
                .rotationEffect(.degrees(-4))
                .shadow(color: accentColor.opacity(0.18), radius: 18, x: 0, y: 10)

            Image(systemName: page.iconName)
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(height: 190)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var sampleCard: some View {
        switch index {
        case 0:
            versePreviewCard(label: "오늘의 말씀", text: "오늘도 한 구절, 천천히", reference: "시편 23:1")
        case 1:
            VStack(spacing: 10) {
                miniSavedVerse("두려워하지 말라", reference: "이사야 41:10")
                miniSavedVerse("내가 너희를 쉬게 하리라", reference: "마태복음 11:28")
            }
        case 2:
            VStack(spacing: 10) {
                miniSavedVerse("두려워하지 말라", reference: "이사야 41:10")
                miniSavedVerse("내가 너희를 쉬게 하리라", reference: "마태복음 11:28")
            }
        case 3:
            topicSelectionCard
        case 4:
            favoriteVerseCard
        default:
            VStack(alignment: .leading, spacing: 12) {
                prayerRow(title: "등교 전 마음", status: "기도 중")
                prayerRow(title: "이번 주 감사", status: "응답 기록")
            }
            .padding(18)
            .background(AppColors.cardTint)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }

    private var topicSelectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("관심 주제")
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(topics, id: \.self) { topic in
                    topicChip(topic)
                }
            }

            Text(selectedTopics.isEmpty ? "선택하지 않아도 시작할 수 있어요." : "\(selectedTopics.count)개 주제를 선택했어요.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.cardTint)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var favoriteVerseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            versePreviewCard(
                label: "나의 대표 말씀",
                text: "강하고 담대하라",
                reference: "여호수아 1:9"
            )

            Text("대표 말씀은 가입 후 Profile에서 실제 성경 말씀을 검색해서 선택할 수 있어요.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GardenTheme.softFill)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

            widgetNotice
        }
    }

    private func topicChip(_ topic: String) -> some View {
        let isSelected = selectedTopics.contains(topic)
        return Button {
            if isSelected {
                selectedTopics.remove(topic)
            } else {
                selectedTopics.insert(topic)
            }
        } label: {
            Text(topic)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : GardenTheme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(isSelected ? GardenTheme.primary : GardenTheme.softFill)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? Color.clear : GardenTheme.softStroke, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func versePreviewCard(label: String, text: String, reference: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentColor)
            Text(text)
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)
            Text(reference)
                .font(.caption)
                .foregroundStyle(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.cardTint)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func miniSavedVerse(_ text: String, reference: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accentColor)
                .frame(width: 34, height: 34)
                .background(accentColor.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.primaryText)
                Text(reference)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppColors.cardTint)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func prayerRow(title: String, status: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(accentColor.opacity(0.16))
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: "note.text")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accentColor)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.primaryText)
                Text(status)
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }

            Spacer(minLength: 0)
        }
    }

    private var widgetNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GardenTheme.primary)
                .padding(.top, 2)

            Text("홈 화면에서도 오늘의 말씀을 확인할 수 있어요.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(GardenTheme.softFill)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
