import Foundation
import WidgetKit

@MainActor
enum WidgetPayloadWriter {
    static func refresh(
        userID: String?,
        savedVerseItems: [MyVerseListItem]
    ) {
        refresh(
            userID: userID,
            savedVerseItems: savedVerseItems,
            bibleService: .shared
        )
    }

    static func refresh(
        userID: String?,
        savedVerseItems: [MyVerseListItem],
        bibleService: BibleDataService
    ) {
        let data = widgetData(
            userID: userID,
            savedVerseItems: savedVerseItems,
            bibleService: bibleService
        )
        SharedVerseProvider.saveWidgetData(data)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func widgetData(
        userID: String?,
        savedVerseItems: [MyVerseListItem],
        bibleService: BibleDataService
    ) -> VerseWidgetData {
        if let representativeVerse = representativeVerseWidgetData() {
            return representativeVerse
        }

        if let savedVerse = savedVerseWidgetData(
            userID: userID,
            savedVerseItems: savedVerseItems,
            bibleService: bibleService
        ) {
            return savedVerse
        }

        if let todayVerse = TodayVerseService.todayVerse(bibleService: bibleService) {
            return VerseWidgetData(
                label: "오늘의 말씀",
                text: todayVerse.displayText,
                reference: todayVerse.referenceText,
                source: .today,
                deepLinkURLString: AppGroupKeys.todayVerseURL,
                updatedAt: Date()
            )
        }

        return VerseWidgetData.fallback
    }

    private static func representativeVerseWidgetData() -> VerseWidgetData? {
        // Reserved for a future profile/Firebase representative verse field.
        nil
    }

    private static func savedVerseWidgetData(
        userID: String?,
        savedVerseItems: [MyVerseListItem],
        bibleService: BibleDataService
    ) -> VerseWidgetData? {
        let filteredItems = savedVerseItems
            .items(for: userID)
            .sorted { lhs, rhs in
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.createdAt > rhs.createdAt
            }

        guard let item = filteredItems.first,
              let verse = bibleService.getVerse(book: item.book, chapter: item.chapter, verse: item.verse) else {
            return nil
        }

        return VerseWidgetData(
            label: "저장한 말씀",
            text: verse.text,
            reference: "\(verse.book) \(verse.chapter):\(verse.verse)",
            source: .saved,
            deepLinkURLString: AppGroupKeys.favoriteVerseURL,
            updatedAt: Date()
        )
    }
}
