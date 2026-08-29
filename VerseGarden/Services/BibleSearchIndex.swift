import Foundation

struct BibleSearchResult: Sendable {
    let verses: [LocalBibleVerse]
    let hasMoreResults: Bool
}

struct BibleSearchIndex: Sendable {
    private struct Entry: Sendable {
        let verse: LocalBibleVerse
        let normalizedReference: String
        let normalizedShortReference: String
        let normalizedText: String
    }

    private let entries: [Entry]
    private let entriesByBook: [String: [Entry]]
    private let bookAliases: [String: [String]]

    nonisolated init(verses: [LocalBibleVerse]) {
        let entries = verses.map { verse in
            Entry(
                verse: verse,
                normalizedReference: Self.compactReference("\(verse.book)\(verse.chapter):\(verse.verse)"),
                normalizedShortReference: Self.compactReference("\(String(verse.book.prefix(1)))\(verse.chapter):\(verse.verse)"),
                normalizedText: Self.normalize(verse.text)
            )
        }
        self.entries = entries

        var entriesByBook = [String: [Entry]]()
        for entry in entries {
            let normalizedBook = Self.normalize(entry.verse.book)
            entriesByBook[normalizedBook, default: []].append(entry)
        }
        self.entriesByBook = entriesByBook

        var aliases = [String: Set<String>]()
        for book in entriesByBook.keys {
            aliases[book, default: []].insert(book)
            if let initial = book.first {
                aliases[String(initial), default: []].insert(book)
            }
        }
        self.bookAliases = aliases.mapValues { $0.sorted { $0.count > $1.count } }
    }

    nonisolated func search(query: String, limit: Int) -> BibleSearchResult {
        let normalizedQuery = Self.normalize(query)
        let compactQuery = Self.compactReference(query)
        guard !normalizedQuery.isEmpty, limit > 0 else {
            return BibleSearchResult(verses: [], hasMoreResults: false)
        }

        if let structuredResults = structuredReferenceSearch(compactQuery: compactQuery, limit: limit) {
            return structuredResults
        }

        let matches = entries.lazy.filter { entry in
            entry.normalizedText.contains(normalizedQuery)
                || entry.normalizedReference.contains(compactQuery)
                || entry.normalizedShortReference.contains(compactQuery)
        }
        return limitedResult(matches, limit: limit)
    }

    private nonisolated func structuredReferenceSearch(compactQuery: String, limit: Int) -> BibleSearchResult? {
        let aliases = bookAliases.keys.sorted { $0.count > $1.count }
        guard let alias = aliases.first(where: { compactQuery.hasPrefix($0) }),
              let books = bookAliases[alias] else {
            return nil
        }

        let suffix = String(compactQuery.dropFirst(alias.count))
        guard suffix.isEmpty || suffix.first?.isNumber == true else { return nil }

        let candidateEntries = books.flatMap { entriesByBook[$0] ?? [] }
        guard !suffix.isEmpty else {
            return limitedResult(candidateEntries.lazy, limit: limit)
        }

        let components = suffix.split(separator: ":", maxSplits: 1).map(String.init)
        guard let chapter = Int(components[0]) else { return nil }
        let matches: LazyFilterSequence<[Entry]> = candidateEntries.lazy.filter { entry in
            guard entry.verse.chapter == chapter else { return false }
            guard components.count == 2, let verse = Int(components[1]) else { return true }
            return entry.verse.verse == verse
        }
        return limitedResult(matches, limit: limit)
    }

    private nonisolated func limitedResult<S: Sequence>(_ matches: S, limit: Int) -> BibleSearchResult where S.Element == Entry {
        var verses = [LocalBibleVerse]()
        verses.reserveCapacity(limit)
        var hasMoreResults = false

        for entry in matches {
            if verses.count == limit {
                hasMoreResults = true
                break
            }
            verses.append(entry.verse)
        }

        return BibleSearchResult(verses: verses, hasMoreResults: hasMoreResults)
    }

    private nonisolated static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ko_KR"))
    }

    private nonisolated static func compactReference(_ value: String) -> String {
        normalize(value)
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
            .replacingOccurrences(of: "장", with: ":")
            .replacingOccurrences(of: "절", with: "")
    }
}

actor BibleSearchIndexStore {
    static let shared = BibleSearchIndexStore()

    private var index: BibleSearchIndex?

    func index(for verses: [LocalBibleVerse]) -> BibleSearchIndex {
        if let index {
            return index
        }

        let builtIndex = BibleSearchIndex(verses: verses)
        index = builtIndex
        return builtIndex
    }
}
