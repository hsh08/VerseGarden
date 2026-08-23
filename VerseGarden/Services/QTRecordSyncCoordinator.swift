import Combine
import FirebaseAuth
import Foundation

@MainActor
final class QTRecordSyncCoordinator: ObservableObject {
    @Published private(set) var isSyncing = false
    @Published var errorMessage: String?

    private let service = FirestoreQTRecordService()
    private var syncingUserID: String?

    func syncForAuthenticatedUser(userID: String?, store: QTStore) async {
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
            let remoteRecords = try await service.fetchRecords(for: userID)
            store.mergeRecordsFromSync(remoteRecords)

            for record in store.records {
                try await service.upsert(record, for: userID)
            }
        } catch {
            errorMessage = "QT 기록 동기화에 실패했습니다."
        }
    }

    func uploadRecord(_ record: QTRecord, userID: String?) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }

        do {
            try await service.upsert(record, for: userID)
        } catch {
            errorMessage = "QT 기록을 동기화하지 못했습니다."
        }
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
