import Foundation

enum AppGroupKeys {
    static let appGroupID = "group.com.versegarden.app"
    static let widgetDataKey = "verseGardenWidgetData"
    static let widgetKind = "VerseGardenWidget"
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    static let hasCompletedOnboardingKeyPrefix = "hasCompletedOnboarding_"

    static let todayVerseURL = "versegarden://verse/today"
    static let favoriteVerseURL = "versegarden://verse/favorite"
    static let profileURL = "versegarden://profile"

    static func verseURL(verseID: String) -> String {
        deepLinkURL(host: "verse", verseID: verseID)
    }

    static func writingURL(verseID: String) -> String {
        deepLinkURL(host: "write", verseID: verseID)
    }

    private static func deepLinkURL(host: String, verseID: String) -> String {
        let encodedVerseID = verseID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? verseID
        return "versegarden://\(host)/\(encodedVerseID)"
    }
}
