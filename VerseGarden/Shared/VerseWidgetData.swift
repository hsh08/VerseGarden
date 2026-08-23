import Foundation

struct VerseWidgetData: Codable, Equatable {
    enum Source: String, Codable {
        case representative
        case saved
        case today
        case fallback
    }

    let label: String
    let text: String
    let reference: String
    let source: Source
    let deepLinkURLString: String
    let updatedAt: Date

    static let fallback = VerseWidgetData(
        label: "오늘의 말씀",
        text: "여호와는 나의 목자시니 내게 부족함이 없으리로다",
        reference: "시편 23:1",
        source: .fallback,
        deepLinkURLString: AppGroupKeys.todayVerseURL,
        updatedAt: Date()
    )
}
