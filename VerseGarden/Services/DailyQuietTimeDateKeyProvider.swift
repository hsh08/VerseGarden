import Foundation

struct DailyQuietTimeDateKeyProvider {
    static let seoulTimeZoneIdentifier = "Asia/Seoul"

    private var calendar: Calendar

    init(timeZoneIdentifier: String = Self.seoulTimeZoneIdentifier) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        self.calendar = calendar
    }

    func dateKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}
