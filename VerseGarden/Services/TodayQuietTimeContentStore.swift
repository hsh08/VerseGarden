import Combine
import Foundation

@MainActor
final class TodayQuietTimeContentStore: ObservableObject {
    @Published private(set) var remoteContent: QTContent?
    @Published private(set) var isLoading = false

    private let service = DailyQuietTimeContentService()
    private let dateKeyProvider = DailyQuietTimeDateKeyProvider()
    private var loadedDateKey: String?

    func content(fallback: QTContent, for date: Date = Date()) -> QTContent {
        guard let remoteContent,
              remoteContent.contentDateKey == dateKeyProvider.dateKey(for: date) else {
            return fallback
        }
        return remoteContent
    }

    func loadTodayIfNeeded(force: Bool = false) async {
        let dateKey = dateKeyProvider.dateKey(for: Date())
        guard force || loadedDateKey != dateKey else {
            return
        }

        loadedDateKey = dateKey
        isLoading = true
        defer { isLoading = false }

        do {
            remoteContent = try await service.fetchContent(for: Date())
        } catch {
            #if DEBUG
            print("DailyQuietTimeContentStore fallback:", error.localizedDescription)
            #endif
            remoteContent = nil
        }
    }
}
