import SwiftUI
import UserNotifications

struct ReminderSettingsView: View {
    @EnvironmentObject private var reminderScheduler: ReminderScheduler

    @State private var reminderTime = Date()

    var body: some View {
        Form {
            Section("매일 리마인더") {
                Toggle("리마인더 켜기", isOn: reminderBinding)
                DatePicker("알림 시간", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .disabled(!reminderScheduler.reminderEnabled)
                    .onChange(of: reminderTime) { _, newValue in
                        let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                        Task {
                            await reminderScheduler.setReminder(
                                enabled: reminderScheduler.reminderEnabled,
                                hour: components.hour,
                                minute: components.minute
                            )
                        }
                    }
            }

            Section("상태") {
                settingsRow("권한 상태", value: authorizationText)
                settingsRow("안내", value: "강요하지 않고 부드럽게 하루를 기억하게 합니다.")
            }
        }
        .navigationTitle("리마인더")
        .task {
            reminderTime = Calendar.current.date(
                bySettingHour: reminderScheduler.reminderHour,
                minute: reminderScheduler.reminderMinute,
                second: 0,
                of: Date()
            ) ?? Date()
            await reminderScheduler.refreshAuthorizationStatus()
        }
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { reminderScheduler.reminderEnabled },
            set: { newValue in
                Task {
                    let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
                    await reminderScheduler.setReminder(
                        enabled: newValue,
                        hour: components.hour,
                        minute: components.minute
                    )
                }
            }
        )
    }

    private var authorizationText: String {
        switch reminderScheduler.authorizationStatus {
        case .notDetermined: return "아직 요청하지 않음"
        case .denied: return "거부됨 - 설정 앱에서 변경 가능"
        case .authorized: return "허용됨"
        case .provisional: return "임시 허용"
        case .ephemeral: return "일시 허용"
        @unknown default: return "알 수 없음"
        }
    }

    private func settingsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
