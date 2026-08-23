import Foundation

enum GardenActivityTimelineBuilder {
    static func mergedActivities(
        writingRecords: [WritingRecord],
        prayerRecords: [PrayerWritingRecord],
        qtRecords: [QTRecord] = [],
        likedVerseRecords: [LikedVerseRecord] = [],
        activityLog: [GardenActivity],
        calendar: Calendar = .current
    ) -> [GardenActivity] {
        let derivedActivities =
            writingRecords.map { scriptureCopyActivity(from: $0) }
            + prayerRecords.map { prayerActivity(from: $0) }
            + qtRecords.compactMap { qtCompletedActivity(from: $0) }
            + likedVerseRecords.map { verseLikedActivity(from: $0) }

        let localFallbackActivities = activityLog.filter { activity in
            shouldIncludeLocalActivity(activity, sourceActivities: derivedActivities, calendar: calendar)
        }

        return deduplicated(
            activities: localFallbackActivities + derivedActivities,
            calendar: calendar
        )
        .sorted { $0.createdAt > $1.createdAt }
    }

    static func activities(_ activities: [GardenActivity], on date: Date, calendar: Calendar = .current) -> [GardenActivity] {
        activities
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    static func gardenGrowthActivities(from activities: [GardenActivity]) -> [GardenActivity] {
        activities.filter { $0.type.countsTowardGardenGrowth }
    }

    static func gardenGrowthActivities(_ activities: [GardenActivity], on date: Date, calendar: Calendar = .current) -> [GardenActivity] {
        self.activities(activities, on: date, calendar: calendar)
            .filter { $0.type.countsTowardGardenGrowth }
    }

    static func daySummaries(
        from activities: [GardenActivity],
        calendar: Calendar = .current
    ) -> [Date: HabitDaySummary] {
        Dictionary(grouping: gardenGrowthActivities(from: activities), by: { calendar.startOfDay(for: $0.createdAt) })
            .reduce(into: [Date: HabitDaySummary]()) { result, item in
                let bibleCount = item.value.filter { $0.type != .prayer }.count
                let prayerCount = item.value.filter { $0.type == .prayer }.count
                result[item.key] = HabitDaySummary(
                    date: item.key,
                    bibleCount: bibleCount,
                    prayerCount: prayerCount
                )
            }
    }

    static func currentStreak(from activities: [GardenActivity], calendar: Calendar = .current) -> Int {
        let uniqueDays = Set(gardenGrowthActivities(from: activities).map { calendar.startOfDay(for: $0.createdAt) })
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

    static func weeklyActivities(from activities: [GardenActivity], calendar: Calendar = .current) -> [GardenActivity] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }
        return gardenGrowthActivities(from: activities).filter { week.contains($0.createdAt) }
    }

    static func weeklySummary(
        from activities: [GardenActivity],
        calendar: Calendar = .current
    ) -> [HabitDaySummary] {
        let summaries = daySummaries(from: activities, calendar: calendar)
        let today = calendar.startOfDay(for: Date())

        return (0..<7).compactMap { offset -> HabitDaySummary? in
            guard let date = calendar.date(byAdding: .day, value: -(6 - offset), to: today) else { return nil }
            return summaries[date] ?? HabitDaySummary(date: date, bibleCount: 0, prayerCount: 0)
        }
    }

    private static func scriptureCopyActivity(from record: WritingRecord) -> GardenActivity {
        GardenActivity(
            id: "writing-\(record.id.uuidString)",
            type: .scriptureCopy,
            title: GardenActivityType.scriptureCopy.displayTitle,
            verseId: record.verseId.isEmpty ? nil : record.verseId,
            reference: "\(record.book) \(record.chapter):\(record.verse)",
            contentPreview: record.originalText,
            sourceId: record.id.uuidString,
            createdAt: record.completedAt
        )
    }

    private static func prayerActivity(from record: PrayerWritingRecord) -> GardenActivity {
        GardenActivity(
            id: "prayer-\(record.id.uuidString)",
            type: .prayer,
            title: GardenActivityType.prayer.displayTitle,
            contentPreview: record.titleSnapshot,
            sourceId: record.id.uuidString,
            createdAt: record.completedAt
        )
    }

    private static func qtCompletedActivity(from record: QTRecord) -> GardenActivity? {
        guard let completedAt = record.completedAt else { return nil }

        let reflectionPreview = record.reflectionAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        return GardenActivity(
            id: "qt-\(record.id)",
            type: .qtCompleted,
            title: GardenActivityType.qtCompleted.displayTitle,
            verseId: record.verseId,
            reference: record.reference,
            contentPreview: reflectionPreview.isEmpty ? record.verseText : reflectionPreview,
            sourceId: record.id,
            createdAt: completedAt
        )
    }

    private static func verseLikedActivity(from record: LikedVerseRecord) -> GardenActivity {
        let verse = BibleDataService.shared.getVerse(id: record.verseId)
        return GardenActivity(
            id: "liked-\(record.verseId)",
            type: .verseLiked,
            title: GardenActivityType.verseLiked.displayTitle,
            verseId: record.verseId,
            reference: verse?.referenceText,
            contentPreview: verse?.text,
            sourceId: record.verseId,
            createdAt: record.createdAt
        )
    }

    private static func shouldIncludeLocalActivity(
        _ activity: GardenActivity,
        sourceActivities: [GardenActivity],
        calendar: Calendar
    ) -> Bool {
        if activity.type == .verseRead {
            return true
        }

        return !sourceActivities.contains { sourceActivity in
            sourceActivityCoversLocalActivity(sourceActivity, activity, calendar: calendar)
        }
    }

    private static func sourceActivityCoversLocalActivity(
        _ sourceActivity: GardenActivity,
        _ localActivity: GardenActivity,
        calendar: Calendar
    ) -> Bool {
        guard sourceActivity.type == localActivity.type else { return false }

        if let sourceId = localActivity.sourceId,
           !sourceId.isEmpty,
           sourceActivity.sourceId == sourceId {
            return true
        }

        switch localActivity.type {
        case .verseRead:
            return false
        case .verseLiked:
            return sourceActivity.verseId == localActivity.verseId
        case .qtCompleted:
            return calendar.isDate(sourceActivity.createdAt, inSameDayAs: localActivity.createdAt)
        case .scriptureCopy:
            guard calendar.isDate(sourceActivity.createdAt, inSameDayAs: localActivity.createdAt) else {
                return false
            }
            if let verseId = localActivity.verseId, !verseId.isEmpty {
                return sourceActivity.verseId == verseId
            }
            return sourceActivity.reference == localActivity.reference
        case .prayer:
            return calendar.isDate(sourceActivity.createdAt, inSameDayAs: localActivity.createdAt)
                && sourceActivity.contentPreview == localActivity.contentPreview
        }
    }

    private static func deduplicated(activities: [GardenActivity], calendar: Calendar) -> [GardenActivity] {
        var seenSourceKeys = Set<String>()
        var seenFallbackKeys = Set<String>()
        var seenQTDays = Set<TimeInterval>()
        var seenScriptureCopyKeys = Set<String>()
        var seenVerseLikedKeys = Set<String>()
        var result: [GardenActivity] = []

        for activity in activities.sorted(by: activityPrioritySort) {
            let day = calendar.startOfDay(for: activity.createdAt).timeIntervalSince1970
            if activity.type == .qtCompleted {
                guard seenQTDays.insert(day).inserted else { continue }
            }

            if activity.type == .scriptureCopy {
                let identity = activity.verseId ?? activity.reference ?? activity.title
                let key = "\(identity.normalizedGardenIdentity)|\(day)"
                guard seenScriptureCopyKeys.insert(key).inserted else { continue }
            }

            if activity.type == .verseLiked {
                let identity = activity.verseId ?? activity.reference ?? activity.title
                let key = identity.normalizedGardenIdentity
                guard seenVerseLikedKeys.insert(key).inserted else { continue }
            }

            if let sourceId = activity.sourceId, !sourceId.isEmpty {
                let key = "\(activity.type.rawValue)|source|\(sourceId)"
                guard seenSourceKeys.insert(key).inserted else { continue }
                result.append(activity)
                continue
            }

            let identity = activity.verseId ?? activity.reference ?? activity.title
            let key = "\(activity.type.rawValue)|\(identity)|\(day)"
            guard seenFallbackKeys.insert(key).inserted else { continue }
            result.append(activity)
        }

        return result
    }

    private nonisolated static func activityPrioritySort(lhs: GardenActivity, rhs: GardenActivity) -> Bool {
        if lhs.type != rhs.type {
            return lhs.createdAt > rhs.createdAt
        }

        // SwiftData-derived records carry sourceId and should win over mirrored log entries for the same source.
        let lhsHasSource = lhs.sourceId?.isEmpty == false
        let rhsHasSource = rhs.sourceId?.isEmpty == false
        if lhsHasSource != rhsHasSource {
            return lhsHasSource
        }

        return lhs.createdAt > rhs.createdAt
    }
}

private extension String {
    var normalizedGardenIdentity: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}
