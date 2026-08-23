import Foundation

enum SharedVerseProvider {
    static func currentWidgetData() -> VerseWidgetData {
        guard let data = sharedDefaults().data(forKey: AppGroupKeys.widgetDataKey),
              let decoded = try? JSONDecoder().decode(VerseWidgetData.self, from: data) else {
            return VerseWidgetData.fallback
        }

        return decoded
    }

    @discardableResult
    static func saveWidgetData(_ widgetData: VerseWidgetData) -> Bool {
        guard let encoded = try? JSONEncoder().encode(widgetData) else {
            return false
        }

        let defaults = sharedDefaults()
        defaults.set(encoded, forKey: AppGroupKeys.widgetDataKey)
        return defaults.synchronize()
    }

    static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: AppGroupKeys.appGroupID) ?? .standard
    }
}
