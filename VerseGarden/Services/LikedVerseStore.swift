import Combine
import Foundation

struct LikedVerseRecord: Codable, Identifiable, Hashable {
    let verseId: String
    let createdAt: Date

    var id: String { verseId }
}

final class LikedVerseStore: ObservableObject {
    @Published private(set) var likedVerseRecords: [LikedVerseRecord] = []
    var onLikeChanged: ((String, Bool) -> Void)?

    private let defaults: UserDefaults
    private let baseStorageKey = "likedVerseIds"
    private var activeUserID: String?
    private var isApplyingSync = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadLikedVerseIds()
    }

    var likedVerseIds: [String] {
        likedVerseRecords.map(\.verseId)
    }

    var likedCount: Int {
        likedVerseRecords.count
    }

    func setActiveUserID(_ userID: String?) {
        guard activeUserID != userID else { return }
        activeUserID = userID
        loadLikedVerseIds()
    }

    func isLiked(verseId: String) -> Bool {
        likedVerseRecords.contains { $0.verseId == verseId }
    }

    func isLiked(_ verse: LocalBibleVerse) -> Bool {
        isLiked(verseId: verse.id)
    }

    func isLiked(_ verse: BibleVerse) -> Bool {
        isLiked(verseId: verse.id)
    }

    func toggleLike(_ verse: LocalBibleVerse) {
        isLiked(verse) ? unlike(verse) : like(verse)
    }

    func toggleLike(_ verse: BibleVerse) {
        isLiked(verse) ? unlike(verse) : like(verse)
    }

    func like(_ verse: LocalBibleVerse) {
        like(verseId: verse.id)
    }

    func like(_ verse: BibleVerse) {
        like(verseId: verse.id)
    }

    func unlike(_ verse: LocalBibleVerse) {
        unlike(verseId: verse.id)
    }

    func unlike(_ verse: BibleVerse) {
        unlike(verseId: verse.id)
    }

    func getLikedVerseIds() -> [String] {
        likedVerseIds
    }

    func getLikedVerseRecords() -> [LikedVerseRecord] {
        likedVerseRecords
    }

    func likedRecord(verseId: String) -> LikedVerseRecord? {
        likedVerseRecords.first { $0.verseId == verseId }
    }

    func replaceLikedVerseIdsFromSync(_ verseIds: [String]) {
        let records = verseIds.map { LikedVerseRecord(verseId: $0, createdAt: Date()) }
        replaceLikedVerseRecordsFromSync(records)
    }

    func replaceLikedVerseRecordsFromSync(_ records: [LikedVerseRecord]) {
        isApplyingSync = true
        likedVerseRecords = records.reduce(into: [LikedVerseRecord]()) { result, record in
            let trimmed = record.verseId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !result.contains(where: { $0.verseId == trimmed }) else {
                return
            }
            result.append(LikedVerseRecord(verseId: trimmed, createdAt: record.createdAt))
        }
        persistLikedVerseRecords()
        isApplyingSync = false
    }

    private func like(verseId: String) {
        guard !isLiked(verseId: verseId) else { return }
        likedVerseRecords.insert(LikedVerseRecord(verseId: verseId, createdAt: Date()), at: 0)
        persistLikedVerseRecords()
        notifyLikeChanged(verseId: verseId, isLiked: true)
    }

    private func unlike(verseId: String) {
        likedVerseRecords.removeAll { $0.verseId == verseId }
        persistLikedVerseRecords()
        notifyLikeChanged(verseId: verseId, isLiked: false)
    }

    private func notifyLikeChanged(verseId: String, isLiked: Bool) {
        guard !isApplyingSync else { return }
        onLikeChanged?(verseId, isLiked)
    }

    private func loadLikedVerseIds() {
        guard let data = defaults.data(forKey: storageKey) else {
            likedVerseRecords = []
            return
        }

        if let decodedRecords = try? JSONDecoder().decode([LikedVerseRecord].self, from: data) {
            likedVerseRecords = uniqueRecords(decodedRecords)
            return
        }

        if let decodedIds = try? JSONDecoder().decode([String].self, from: data) {
            likedVerseRecords = uniqueRecords(
                decodedIds.map { LikedVerseRecord(verseId: $0, createdAt: Date()) }
            )
            persistLikedVerseRecords()
            return
        }

        likedVerseRecords = []
    }

    private func uniqueRecords(_ records: [LikedVerseRecord]) -> [LikedVerseRecord] {
        records.reduce(into: [LikedVerseRecord]()) { result, record in
            let trimmed = record.verseId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !result.contains(where: { $0.verseId == trimmed }) else {
                return
            }
            result.append(LikedVerseRecord(verseId: trimmed, createdAt: record.createdAt))
        }
    }

    private func persistLikedVerseRecords() {
        guard let data = try? JSONEncoder().encode(likedVerseRecords) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private var storageKey: String {
        guard let activeUserID, !activeUserID.isEmpty else {
            return baseStorageKey
        }
        return "\(baseStorageKey)_\(activeUserID)"
    }
}
