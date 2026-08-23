import Combine
import Foundation

final class GardenActivityStore: ObservableObject {
    @Published private(set) var activities: [GardenActivity] = []

    private let defaults: UserDefaults
    private let calendar: Calendar
    // This store is an activity log, not the single source of truth for every Garden record.
    // WritingRecord and PrayerWritingRecord remain SwiftData source records and are merged at display time.
    private let baseStorageKey = "versegarden_garden_activities"
    private var activeUserID: String?

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        loadActivities()
    }

    func setActiveUserID(_ userID: String?) {
        guard activeUserID != userID else { return }
        activeUserID = userID
        loadActivities()
    }

    func addActivity(_ activity: GardenActivity) {
        guard !isDuplicate(activity) else { return }
        activities.insert(activity, at: 0)
        persistActivities()
    }

    func addActivity(
        type: GardenActivityType,
        title: String,
        verseId: String? = nil,
        reference: String? = nil,
        contentPreview: String? = nil,
        sourceId: String? = nil,
        createdAt: Date = Date()
    ) {
        addActivity(
            GardenActivity(
                type: type,
                title: title,
                verseId: verseId,
                reference: reference,
                contentPreview: contentPreview,
                sourceId: sourceId,
                createdAt: createdAt
            )
        )
    }

    func activities(on date: Date) -> [GardenActivity] {
        activities
            .filter { calendar.isDate($0.createdAt, inSameDayAs: date) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func activitiesThisWeek() -> [GardenActivity] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return []
        }
        return activities.filter { week.contains($0.createdAt) }
    }

    func activityCount(on date: Date) -> Int {
        activities(on: date).count
    }

    func hasActivity(on date: Date) -> Bool {
        activityCount(on: date) > 0
    }

    func activeDayCountThisWeek() -> Int {
        Set(activitiesThisWeek().map { calendar.startOfDay(for: $0.createdAt) }).count
    }

    func totalCount(of type: GardenActivityType? = nil) -> Int {
        guard let type else { return activities.count }
        return activities.filter { $0.type == type }.count
    }

    func currentStreak() -> Int {
        let uniqueDays = Set(activities.map { calendar.startOfDay(for: $0.createdAt) })
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

    private func isDuplicate(_ activity: GardenActivity) -> Bool {
        activities.contains { existing in
            guard existing.type == activity.type,
                  calendar.isDate(existing.createdAt, inSameDayAs: activity.createdAt) else {
                return false
            }

            if activity.type == .scriptureCopy {
                if let verseId = activity.verseId, !verseId.isEmpty {
                    return existing.verseId == verseId
                }

                if let reference = activity.reference, !reference.isEmpty {
                    return existing.reference == reference
                }
            }

            if let sourceId = activity.sourceId, !sourceId.isEmpty {
                return existing.sourceId == sourceId
            }

            if let verseId = activity.verseId, !verseId.isEmpty {
                return existing.verseId == verseId
            }

            return existing.title == activity.title
        }
    }

    private func loadActivities() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([GardenActivity].self, from: data) else {
            activities = []
            return
        }

        activities = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    private func persistActivities() {
        guard let data = try? JSONEncoder().encode(activities) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private var storageKey: String {
        guard let activeUserID, !activeUserID.isEmpty else {
            return baseStorageKey
        }
        return "\(baseStorageKey)_\(activeUserID)"
    }
}
