import Combine
import FirebaseAuth
import Foundation

@MainActor
final class LikedVerseSyncCoordinator: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published var errorMessage: String?

    private let service = FirestoreLikedVerseService()
    private var syncingUserID: String?

    func syncForAuthenticatedUser(userID: String?, store: LikedVerseStore) async {
        guard let userID = validatedCurrentUserID(for: userID) else {
            return
        }

        guard syncingUserID != userID else { return }
        syncingUserID = userID
        isSyncing = true
        errorMessage = nil
        defer {
            syncingUserID = nil
            isSyncing = false
        }

        do {
            let localRecords = store.getLikedVerseRecords()
            let remoteRecords = try await service.fetchLikedVerses(for: userID)

            let mergedRecords = merge(localRecords: localRecords, remoteRecords: remoteRecords)
            store.replaceLikedVerseRecordsFromSync(mergedRecords)

            let remoteSet = Set(remoteRecords.map(\.verseId))
            for record in localRecords where !remoteSet.contains(record.verseId) {
                try await service.like(
                    verseId: record.verseId,
                    createdAt: record.createdAt,
                    for: userID
                )
            }
        } catch {
            errorMessage = "저장한 말씀 동기화에 실패했습니다."
        }
    }

    func syncChange(verseId: String, isLiked: Bool, createdAt: Date? = nil, userID: String?) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }

        do {
            if isLiked {
                try await service.like(verseId: verseId, createdAt: createdAt ?? Date(), for: userID)
            } else {
                try await service.unlike(verseId: verseId, for: userID)
            }
        } catch {
            errorMessage = "말씀 저장 상태를 동기화하지 못했습니다."
        }
    }

    private func merge(localRecords: [LikedVerseRecord], remoteRecords: [LikedVerseRecord]) -> [LikedVerseRecord] {
        var merged: [LikedVerseRecord] = []

        for record in localRecords + remoteRecords {
            let trimmed = record.verseId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if let index = merged.firstIndex(where: { $0.verseId == trimmed }) {
                if record.createdAt < merged[index].createdAt {
                    merged[index] = LikedVerseRecord(verseId: trimmed, createdAt: record.createdAt)
                }
            } else {
                merged.append(LikedVerseRecord(verseId: trimmed, createdAt: record.createdAt))
            }
        }

        return merged
    }

    private func validatedCurrentUserID(for userID: String?) -> String? {
        guard let currentUID = Auth.auth().currentUser?.uid,
              let userID,
              !userID.isEmpty,
              currentUID == userID else {
            return nil
        }
        return userID
    }
}
