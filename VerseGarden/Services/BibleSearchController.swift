import Combine
import Foundation

@MainActor
final class BibleSearchController: ObservableObject {
    @Published private(set) var results: [LocalBibleVerse] = []
    @Published private(set) var hasMoreResults = false
    @Published private(set) var isSearching = false

    private let resultLimit: Int
    private var index: BibleSearchIndex?
    private var pendingQuery = ""
    private var indexTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?

    init(resultLimit: Int) {
        self.resultLimit = resultLimit
    }

    deinit {
        indexTask?.cancel()
        searchTask?.cancel()
    }

    func prepare(verses: [LocalBibleVerse]) {
        guard index == nil else { return }

        indexTask?.cancel()
        indexTask = Task { [weak self] in
            let index = await BibleSearchIndexStore.shared.index(for: verses)
            guard !Task.isCancelled else { return }

            self?.index = index
            self?.update(query: self?.pendingQuery ?? "")
        }
    }

    func update(query: String) {
        searchTask?.cancel()
        pendingQuery = query

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
            hasMoreResults = false
            isSearching = false
            return
        }

        isSearching = true
        guard let index else { return }
        let resultLimit = resultLimit

        searchTask = Task { [weak self, index] in
            do {
                try await Task.sleep(nanoseconds: 250_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            let result = await Task.detached(priority: .userInitiated) {
                index.search(query: query, limit: resultLimit)
            }.value
            guard !Task.isCancelled else { return }

            self?.results = result.verses
            self?.hasMoreResults = result.hasMoreResults
            self?.isSearching = false
        }
    }
}
