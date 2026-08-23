import Foundation

struct TodayVerseContent {
    let reference: ThemeVerse
    let verse: LocalBibleVerse?
    let displayText: String

    var referenceText: String {
        "\(reference.book) \(reference.chapter):\(reference.verse)"
    }
}

enum TodayVerseService {
    private static let fallbackMessage = "오늘의 말씀을 준비하는 중입니다."

    static func todayVerse(
        date: Date = Date(),
        calendar: Calendar = .current,
        bibleService: BibleDataService = .shared
    ) -> TodayVerseContent? {
        let versePool = ThemeVerseService.themes.flatMap(\.verses)
        guard !versePool.isEmpty else { return nil }

        let selectedIndex = dailyIndex(for: date, calendar: calendar, count: versePool.count)
        let selectedReference = versePool[selectedIndex]

        for offset in 0..<versePool.count {
            let reference = versePool[(selectedIndex + offset) % versePool.count]
            if let verse = bibleService.verse(book: reference.book, chapter: reference.chapter, verse: reference.verse) {
                return TodayVerseContent(reference: reference, verse: verse, displayText: verse.text)
            }
        }

        return TodayVerseContent(reference: selectedReference, verse: nil, displayText: fallbackMessage)
    }

    private static func dailyIndex(for date: Date, calendar: Calendar, count: Int) -> Int {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.calendar = calendar
        let seed = (components.year ?? 0) * 10_000
            + (components.month ?? 0) * 100
            + (components.day ?? 0)

        return abs(seed) % max(count, 1)
    }
}
