import Combine
import Foundation

@MainActor
final class TodayQuietTimeContentStore: ObservableObject {
    @Published private(set) var resolvedContent: QTContent?
    @Published private(set) var isLoading = false

    private let service = DailyQuietTimeContentService()
    private let dateKeyProvider = DailyQuietTimeDateKeyProvider()
    private var loadedContextKey: String?

    func content(fallback: QTContent, for date: Date = Date()) -> QTContent {
        resolvedContent ?? fallback
    }

    func loadTodayIfNeeded(
        community: Community? = nil,
        force: Bool = false
    ) async {
        let dateKey = dateKeyProvider.dateKey(for: Date())
        let contextKey = "\(dateKey)|\(community?.id ?? "global")|\(community?.status.rawValue ?? "none")"
        guard force || loadedContextKey != contextKey else {
            return
        }

        loadedContextKey = contextKey
        isLoading = true
        defer { isLoading = false }

        do {
            resolvedContent = try await service.fetchContent(
                for: Date(),
                community: community
            )
        } catch {
            #if DEBUG
            print("DailyQuietTimeContentStore fallback:", error.localizedDescription)
            #endif
            resolvedContent = nil
        }
    }

    func clear() {
        resolvedContent = nil
        loadedContextKey = nil
        isLoading = false
    }
}
