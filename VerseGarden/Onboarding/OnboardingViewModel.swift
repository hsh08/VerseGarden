import Combine
import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var selectedPage = 0
    @Published var selectedTopics: Set<String> = []

    let pages: [OnboardingPage] = [
        OnboardingPage(
            title: "말씀으로 하루를 시작해요",
            message: "VerseGarden은 매일 말씀을 읽고, 필사하고, 기도하며 신앙 습관을 쌓아가는 공간이에요.",
            iconName: "book.pages.fill",
            accentName: "green"
        ),
        OnboardingPage(
            title: "작은 기록이 정원이 돼요",
            message: "말씀 읽기, 필사, 기도, QT 완료 기록이 하루하루 쌓여 나만의 Garden으로 자라나요.",
            iconName: "leaf.fill",
            accentName: "mint"
        ),
        OnboardingPage(
            title: "내게 필요한 말씀을 모아보세요",
            message: "마음에 남는 말씀을 저장하고, 다시 꺼내 보며 삶에 적용할 수 있어요.",
            iconName: "bookmark.fill",
            accentName: "teal"
        ),
        OnboardingPage(
            title: "관심 있는 말씀 주제를 골라보세요",
            message: "지금 마음에 가까운 주제를 고르면 내 신앙 기록을 더 나답게 정리할 수 있어요.",
            iconName: "slider.horizontal.3",
            accentName: "brown"
        ),
        OnboardingPage(
            title: "대표 말씀을 남겨보세요",
            message: "가입 후 Profile에서 실제 성경 말씀을 검색해 나의 대표 말씀으로 선택할 수 있어요.",
            iconName: "text.quote",
            accentName: "green"
        )
    ]

    let availableTopics = ["위로", "감사", "믿음", "불안", "진로", "관계", "기도", "회복"]

    var isLastPage: Bool {
        selectedPage == pages.indices.last
    }

    var selectedTopicList: [String] {
        Array(selectedTopics).sorted()
    }

    func moveNext() {
        selectedPage = min(selectedPage + 1, max(pages.count - 1, 0))
    }
}

struct OnboardingPage: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let iconName: String
    let accentName: String
}
