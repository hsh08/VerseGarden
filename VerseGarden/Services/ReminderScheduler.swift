import Combine
import Foundation
import UserNotifications

@MainActor
final class ReminderScheduler: ObservableObject {
    @Published private(set) var reminderEnabled: Bool
    @Published private(set) var reminderHour: Int
    @Published private(set) var reminderMinute: Int
    @Published private(set) var notificationPermissionKnown: Bool

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let defaults: UserDefaults
    private let center = UNUserNotificationCenter.current()
    private let requestIdentifier = "daily-writing-reminder"
    private let enabledKey = "reminderEnabled"
    private let hourKey = "reminderHour"
    private let minuteKey = "reminderMinute"
    private let permissionKnownKey = "notificationPermissionKnown"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.reminderEnabled = defaults.object(forKey: enabledKey) as? Bool ?? false
        self.reminderHour = defaults.object(forKey: hourKey) as? Int ?? 20
        self.reminderMinute = defaults.object(forKey: minuteKey) as? Int ?? 0
        self.notificationPermissionKnown = defaults.object(forKey: permissionKnownKey) as? Bool ?? false
    }

    func refreshAuthorizationStatus() async {
        let settings = await notificationSettings()
        authorizationStatus = settings.authorizationStatus
        if settings.authorizationStatus != .notDetermined {
            setNotificationPermissionKnown(true)
        }
    }

    func setReminder(enabled: Bool, hour: Int? = nil, minute: Int? = nil) async {
        if let hour { setReminderHour(hour) }
        if let minute { setReminderMinute(minute) }

        if enabled {
            let granted = await requestAuthorizationIfNeeded()
            if granted {
                debugLog("permission granted, scheduling daily reminder at \(String(format: "%02d:%02d", reminderHour, reminderMinute))")
                setReminderEnabled(true)
                await scheduleReminder()
            } else {
                debugLog("permission denied or unavailable")
                setReminderEnabled(false)
            }
        } else {
            debugLog("disabled, canceling pending reminder")
            setReminderEnabled(false)
            center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])
        }
        await refreshAuthorizationStatus()
    }

    func rescheduleIfNeeded() async {
        guard reminderEnabled else { return }
        await scheduleReminder()
        await refreshAuthorizationStatus()
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await notificationSettings()
        authorizationStatus = settings.authorizationStatus

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            debugLog("existing authorization status: \(settings.authorizationStatus.rawValue)")
            setNotificationPermissionKnown(true)
            return true
        case .denied:
            debugLog("authorization denied")
            setNotificationPermissionKnown(true)
            return false
        case .notDetermined:
            let granted = await requestAuthorization()
            debugLog("requested authorization, granted: \(granted)")
            setNotificationPermissionKnown(true)
            return granted
        @unknown default:
            return false
        }
    }

    private func scheduleReminder() async {
        center.removePendingNotificationRequests(withIdentifiers: [requestIdentifier])

        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute

        let content = UNMutableNotificationContent()
        content.title = "VerseGarden"
        let messages = [
            "오늘도 한 구절, 천천히 기록해볼까요?",
            "작은 기록이 믿음의 습관이 됩니다.",
            "기도와 말씀으로 오늘의 잔디를 채워보세요."
        ]
        content.body = messages.randomElement() ?? messages[0]
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: requestIdentifier, content: content, trigger: trigger)
        debugLog("scheduling request at \(String(format: "%02d:%02d", reminderHour, reminderMinute))")
        await add(request)
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private func add(_ request: UNNotificationRequest) async {
        await withCheckedContinuation { continuation in
            center.add(request) { _ in
                continuation.resume()
            }
        }
    }

    private func setReminderEnabled(_ value: Bool) {
        reminderEnabled = value
        defaults.set(value, forKey: enabledKey)
    }

    private func setReminderHour(_ value: Int) {
        reminderHour = value
        defaults.set(value, forKey: hourKey)
    }

    private func setReminderMinute(_ value: Int) {
        reminderMinute = value
        defaults.set(value, forKey: minuteKey)
    }

    private func setNotificationPermissionKnown(_ value: Bool) {
        notificationPermissionKnown = value
        defaults.set(value, forKey: permissionKnownKey)
    }

    private func debugLog(_ message: String) {
        #if DEBUG
        print("[Reminder] \(message)")
        #endif
    }
}
