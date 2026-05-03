import Foundation

enum SampleVerses {
    static let items: [BibleVerseSeed] = [
        BibleVerseSeed(id: "sample-001", book: "시편", chapter: 23, verse: 1, text: "여호와는 나의 목자시니 내가 부족함이 없으리로다."),
        BibleVerseSeed(id: "sample-002", book: "잠언", chapter: 3, verse: 5, text: "너는 마음을 다하여 여호와를 신뢰하고 네 명철을 의지하지 말라."),
        BibleVerseSeed(id: "sample-003", book: "이사야", chapter: 41, verse: 10, text: "두려워하지 말라 내가 너와 함께 함이라."),
        BibleVerseSeed(id: "sample-004", book: "마태복음", chapter: 5, verse: 14, text: "너희는 세상의 빛이라."),
        BibleVerseSeed(id: "sample-005", book: "마태복음", chapter: 11, verse: 28, text: "수고하고 무거운 짐 진 자들아 다 내게로 오라."),
        BibleVerseSeed(id: "sample-006", book: "요한복음", chapter: 8, verse: 12, text: "나는 세상의 빛이니 나를 따르는 자는 어둠에 다니지 아니하리라."),
        BibleVerseSeed(id: "sample-007", book: "로마서", chapter: 8, verse: 28, text: "하나님을 사랑하는 자들에게는 모든 것이 합력하여 선을 이루느니라."),
        BibleVerseSeed(id: "sample-008", book: "고린도전서", chapter: 13, verse: 13, text: "그런즉 믿음 소망 사랑 이 세 가지는 항상 있을 것인데 그중의 제일은 사랑이라."),
        BibleVerseSeed(id: "sample-009", book: "빌립보서", chapter: 4, verse: 13, text: "내게 능력 주시는 자 안에서 내가 모든 것을 할 수 있느니라."),
        BibleVerseSeed(id: "sample-010", book: "데살로니가전서", chapter: 5, verse: 16, text: "항상 기뻐하라.")
    ]
}

struct BibleVerseSeed {
    let id: String
    let book: String
    let chapter: Int
    let verse: Int
    let text: String
}
