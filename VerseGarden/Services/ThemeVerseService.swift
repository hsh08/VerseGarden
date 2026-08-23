import SwiftUI

enum ThemeVerseService {
    static let themes: [ThemeItem] = [
        ThemeItem(
            title: "위로가 필요한 날",
            description: "지친 마음을 천천히 붙들어 주는 말씀",
            icon: "cloud.rain.fill",
            accentName: "mint",
            verses: [
                ThemeVerse(theme: "위로가 필요한 날", book: "시편", chapter: 23, verse: 1, reason: "하나님의 돌보심을 다시 붙들고 싶을 때"),
                ThemeVerse(theme: "위로가 필요한 날", book: "시편", chapter: 34, verse: 18, reason: "상한 마음 가까이에 계신 하나님을 기억할 때"),
                ThemeVerse(theme: "위로가 필요한 날", book: "이사야", chapter: 41, verse: 10, reason: "두려움 속에서도 함께하심을 바라볼 때"),
                ThemeVerse(theme: "위로가 필요한 날", book: "마태복음", chapter: 11, verse: 28, reason: "지친 마음이 쉼을 구할 때"),
                ThemeVerse(theme: "위로가 필요한 날", book: "고린도후서", chapter: 1, verse: 4, reason: "위로받은 사람이 다시 위로하는 삶을 배울 때")
            ]
        ),
        ThemeItem(
            title: "용기를 주는 말씀",
            description: "주저할 때 한 걸음을 내딛게 돕는 말씀",
            icon: "flame.fill",
            accentName: "green",
            verses: [
                ThemeVerse(theme: "용기를 주는 말씀", book: "여호수아", chapter: 1, verse: 9, reason: "두려움 대신 담대함을 선택하고 싶을 때"),
                ThemeVerse(theme: "용기를 주는 말씀", book: "시편", chapter: 27, verse: 1, reason: "마음의 빛과 구원이 필요할 때"),
                ThemeVerse(theme: "용기를 주는 말씀", book: "이사야", chapter: 40, verse: 31, reason: "지친 자리에서 새 힘을 얻고 싶을 때"),
                ThemeVerse(theme: "용기를 주는 말씀", book: "로마서", chapter: 8, verse: 31, reason: "하나님이 우리 편이심을 기억할 때"),
                ThemeVerse(theme: "용기를 주는 말씀", book: "디모데후서", chapter: 1, verse: 7, reason: "두려움보다 능력과 사랑을 선택할 때")
            ]
        ),
        ThemeItem(
            title: "시험기간의 학생에게",
            description: "집중과 평안, 지혜를 구하는 학생을 위한 말씀",
            icon: "pencil.and.ruler.fill",
            accentName: "teal",
            verses: [
                ThemeVerse(theme: "시험기간의 학생에게", book: "잠언", chapter: 3, verse: 5, reason: "내 생각보다 하나님을 더 의지하고 싶을 때"),
                ThemeVerse(theme: "시험기간의 학생에게", book: "잠언", chapter: 16, verse: 3, reason: "계획한 일을 하나님께 맡기고 싶을 때"),
                ThemeVerse(theme: "시험기간의 학생에게", book: "야고보서", chapter: 1, verse: 5, reason: "지혜가 부족하다고 느낄 때"),
                ThemeVerse(theme: "시험기간의 학생에게", book: "빌립보서", chapter: 4, verse: 6, reason: "불안을 기도로 바꾸고 싶을 때"),
                ThemeVerse(theme: "시험기간의 학생에게", book: "골로새서", chapter: 3, verse: 23, reason: "공부를 주께 하듯 다시 정돈하고 싶을 때")
            ]
        ),
        ThemeItem(
            title: "감사하는 마음",
            description: "일상의 은혜를 다시 바라보게 하는 말씀",
            icon: "hands.sparkles.fill",
            accentName: "green",
            verses: [
                ThemeVerse(theme: "감사하는 마음", book: "시편", chapter: 100, verse: 4, reason: "감사로 예배의 문을 열고 싶을 때"),
                ThemeVerse(theme: "감사하는 마음", book: "데살로니가전서", chapter: 5, verse: 18, reason: "모든 상황 속 감사의 태도를 배우고 싶을 때"),
                ThemeVerse(theme: "감사하는 마음", book: "골로새서", chapter: 3, verse: 17, reason: "삶의 모든 영역에서 감사하고 싶을 때"),
                ThemeVerse(theme: "감사하는 마음", book: "시편", chapter: 136, verse: 1, reason: "인자하심이 영원함을 고백하고 싶을 때"),
                ThemeVerse(theme: "감사하는 마음", book: "빌립보서", chapter: 4, verse: 4, reason: "기쁨과 감사를 함께 회복하고 싶을 때")
            ]
        ),
        ThemeItem(
            title: "사람들이 좌우명으로 삼는 말씀",
            description: "삶의 방향이 되어주는 대표 성경 말씀들을 모았습니다.",
            icon: "bookmark.fill",
            accentName: "mint",
            verses: [
                ThemeVerse(theme: "사람들이 좌우명으로 삼는 말씀", book: "요한복음", chapter: 3, verse: 16, reason: "위로처럼 가장 먼저 붙들고 싶은 사랑의 말씀"),
                ThemeVerse(theme: "사람들이 좌우명으로 삼는 말씀", book: "여호수아", chapter: 1, verse: 9, reason: "용기가 필요할 때 마음에 새기고 싶은 말씀"),
                ThemeVerse(theme: "사람들이 좌우명으로 삼는 말씀", book: "마태복음", chapter: 11, verse: 28, reason: "쉼이 필요할 때 다시 돌아오게 하는 말씀"),
                ThemeVerse(theme: "사람들이 좌우명으로 삼는 말씀", book: "데살로니가전서", chapter: 5, verse: 16, reason: "감사와 기도의 태도를 잃지 않게 붙드는 말씀"),
                ThemeVerse(theme: "사람들이 좌우명으로 삼는 말씀", book: "데살로니가전서", chapter: 5, verse: 17, reason: "감사와 기도의 태도를 잃지 않게 붙드는 말씀"),
                ThemeVerse(theme: "사람들이 좌우명으로 삼는 말씀", book: "데살로니가전서", chapter: 5, verse: 18, reason: "감사와 기도의 태도를 잃지 않게 붙드는 말씀"),
                ThemeVerse(theme: "사람들이 좌우명으로 삼는 말씀", book: "잠언", chapter: 16, verse: 9, reason: "인도하심을 신뢰하며 길을 걸어가게 하는 말씀"),
                ThemeVerse(theme: "사람들이 좌우명으로 삼는 말씀", book: "시편", chapter: 23, verse: 1, reason: "평안으로 하루를 마무리하게 하는 고백의 말씀")
            ]
        ),
        ThemeItem(
            title: "불안하고 두려운 날",
            description: "걱정이 커질 때 중심을 잡아주는 말씀",
            icon: "wind",
            accentName: "mint",
            verses: [
                ThemeVerse(theme: "불안하고 두려운 날", book: "시편", chapter: 56, verse: 3, reason: "두려운 순간에 누구를 의지할지 정하고 싶을 때"),
                ThemeVerse(theme: "불안하고 두려운 날", book: "이사야", chapter: 41, verse: 10, reason: "함께하시는 하나님을 다시 붙들 때"),
                ThemeVerse(theme: "불안하고 두려운 날", book: "요한복음", chapter: 14, verse: 27, reason: "세상이 줄 수 없는 평안을 구할 때"),
                ThemeVerse(theme: "불안하고 두려운 날", book: "빌립보서", chapter: 4, verse: 6, reason: "염려를 기도로 바꾸고 싶을 때"),
                ThemeVerse(theme: "불안하고 두려운 날", book: "베드로전서", chapter: 5, verse: 7, reason: "근심을 맡기고 싶을 때")
            ]
        ),
        ThemeItem(
            title: "사랑을 배우는 말씀",
            description: "사랑의 태도와 본질을 다시 배우는 말씀",
            icon: "heart.fill",
            accentName: "teal",
            verses: [
                ThemeVerse(theme: "사랑을 배우는 말씀", book: "고린도전서", chapter: 13, verse: 4, reason: "사랑의 실제 모습을 배우고 싶을 때"),
                ThemeVerse(theme: "사랑을 배우는 말씀", book: "고린도전서", chapter: 13, verse: 13, reason: "믿음, 소망, 사랑 중 가장 큰 것을 기억할 때"),
                ThemeVerse(theme: "사랑을 배우는 말씀", book: "요한일서", chapter: 4, verse: 7, reason: "사랑이 하나님께 속했다는 사실을 붙들 때"),
                ThemeVerse(theme: "사랑을 배우는 말씀", book: "요한일서", chapter: 4, verse: 19, reason: "내 사랑의 시작이 하나님께 있음을 배울 때"),
                ThemeVerse(theme: "사랑을 배우는 말씀", book: "요한복음", chapter: 13, verse: 34, reason: "서로 사랑하라는 새 계명을 삶에 새길 때")
            ]
        ),
        ThemeItem(
            title: "새롭게 시작하는 날",
            description: "새 출발 앞에서 마음을 정돈하게 하는 말씀",
            icon: "sun.max.fill",
            accentName: "green",
            verses: [
                ThemeVerse(theme: "새롭게 시작하는 날", book: "이사야", chapter: 43, verse: 19, reason: "새 일을 행하시는 하나님을 기대할 때"),
                ThemeVerse(theme: "새롭게 시작하는 날", book: "고린도후서", chapter: 5, verse: 17, reason: "그리스도 안의 새로움을 다시 붙들 때"),
                ThemeVerse(theme: "새롭게 시작하는 날", book: "빌립보서", chapter: 3, verse: 13, reason: "뒤를 잊고 앞으로 나아가고 싶을 때"),
                ThemeVerse(theme: "새롭게 시작하는 날", book: "잠언", chapter: 16, verse: 9, reason: "내 계획보다 인도하심을 신뢰할 때"),
                ThemeVerse(theme: "새롭게 시작하는 날", book: "시편", chapter: 37, verse: 5, reason: "길을 맡기고 이루심을 기다릴 때")
            ]
        )
    ]

    static func theme(named name: String) -> ThemeItem? {
        themes.first { $0.title == name }
    }

    static func accentColor(for theme: ThemeItem) -> Color {
        switch theme.accentName {
        case "mint":
            return GardenTheme.secondary
        case "teal":
            return GardenTheme.tertiary
        default:
            return GardenTheme.primary
        }
    }
}
