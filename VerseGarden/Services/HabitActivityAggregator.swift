import Foundation

struct HabitDaySummary: Identifiable {
    let date: Date
    let bibleCount: Int
    let prayerCount: Int

    var id: Date { date }
    var totalCount: Int { bibleCount + prayerCount }
    var isCompleted: Bool { totalCount > 0 }
}

enum HabitActivityAggregator {
    static func daySummaries(
        bibleRecords: [WritingRecord],
        prayerRecords: [PrayerWritingRecord],
        calendar: Calendar = .current
    ) -> [Date: HabitDaySummary] {
        let bibleGrouped = Dictionary(grouping: bibleRecords, by: { calendar.startOfDay(for: $0.date) })
        let prayerGrouped = Dictionary(grouping: prayerRecords, by: { calendar.startOfDay(for: $0.date) })
        let dates = Set(bibleGrouped.keys).union(prayerGrouped.keys)

        var result: [Date: HabitDaySummary] = [:]
        for date in dates {
            result[date] = HabitDaySummary(
                date: date,
                bibleCount: bibleGrouped[date]?.count ?? 0,
                prayerCount: prayerGrouped[date]?.count ?? 0
            )
        }
        return result
    }

    static func currentStreak(
        bibleRecords: [WritingRecord],
        prayerRecords: [PrayerWritingRecord],
        calendar: Calendar = .current
    ) -> Int {
        let uniqueDays = Set(daySummaries(bibleRecords: bibleRecords, prayerRecords: prayerRecords, calendar: calendar).keys)
        guard !uniqueDays.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())

        if !uniqueDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor),
                  uniqueDays.contains(yesterday) else {
                return 0
            }
            cursor = yesterday
        }

        while uniqueDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previousDay
        }

        return streak
    }

    static func totalActivityCount(
        bibleRecords: [WritingRecord],
        prayerRecords: [PrayerWritingRecord]
    ) -> Int {
        bibleRecords.count + prayerRecords.count
    }

    static func todaySummary(
        bibleRecords: [WritingRecord],
        prayerRecords: [PrayerWritingRecord],
        calendar: Calendar = .current
    ) -> HabitDaySummary {
        let today = calendar.startOfDay(for: Date())
        return daySummaries(bibleRecords: bibleRecords, prayerRecords: prayerRecords, calendar: calendar)[today]
            ?? HabitDaySummary(date: today, bibleCount: 0, prayerCount: 0)
    }

    static func weeklySummary(
        bibleRecords: [WritingRecord],
        prayerRecords: [PrayerWritingRecord],
        calendar: Calendar = .current
    ) -> [HabitDaySummary] {
        let summaries = daySummaries(bibleRecords: bibleRecords, prayerRecords: prayerRecords, calendar: calendar)
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset -> HabitDaySummary? in
            guard let date = calendar.date(byAdding: .day, value: -(6 - offset), to: today) else { return nil }
            return summaries[date] ?? HabitDaySummary(date: date, bibleCount: 0, prayerCount: 0)
        }
    }

    static func milestone(for streak: Int) -> Int? {
        [100, 30, 14, 7, 3].first(where: { streak >= $0 })
    }
}
