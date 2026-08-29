import Combine
import FirebaseAuth
import Foundation

@MainActor
final class CommunityQTSubmissionCoordinator: ObservableObject {
    @Published private(set) var pendingCount = 0

    private let callableService: CommunityCallableService
    private let defaults: UserDefaults
    private let baseStorageKey = "versegarden_pending_community_qt_submissions"
    private var activeUserID: String?
    private var pendingItems: [PendingCommunityQTSubmission] = []
    private var isFlushing = false

    init(
        callableService: CommunityCallableService? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.callableService = callableService ?? CommunityCallableService()
        self.defaults = defaults
    }

    func setActiveUserID(_ userID: String?) {
        guard activeUserID != userID else { return }
        activeUserID = userID
        loadPendingItems()
    }

    func submitCompletedRecord(_ record: QTRecord, store: QTStore) async {
        guard let userID = validatedCurrentUserID(),
              let pendingItem = PendingCommunityQTSubmission(record: record) else {
            return
        }

        enqueue(pendingItem)
        await flushPending(userID: userID, store: store)
    }

    func flushPending(userID: String, store: QTStore) async {
        guard validatedCurrentUserID(for: userID) != nil,
              !pendingItems.isEmpty,
              !isFlushing else {
            return
        }

        isFlushing = true
        defer { isFlushing = false }

        var attemptedIDs = Set<String>()
        while let item = pendingItems.first(where: { !attemptedIDs.contains($0.id) }) {
            attemptedIDs.insert(item.id)

            guard let record = record(for: item, in: store), item.matches(record) else {
                remove(item)
                debugLog("Removed stale Community QT submission", item: item)
                continue
            }

            guard let request = CommunityQTSubmissionRequest(record: record) else {
                remove(item)
                debugLog("Removed invalid Community QT submission", item: item)
                continue
            }

            do {
                let result = try await callableService.submitCommunityQT(request)
                remove(item)
                debugLog(
                    result.alreadySubmitted
                        ? "Community QT was already submitted"
                        : "Community QT submission succeeded",
                    item: item
                )
            } catch let failure as CommunityQTSubmissionFailure {
                switch failure {
                case .unauthenticated:
                    return
                case .retryable:
                    debugLog("Queued Community QT submission retry", item: item)
                case .permanent, .invalidResponse:
                    remove(item)
                    debugLog("Removed permanently failed Community QT submission", item: item)
                }
            } catch {
                debugLog("Queued Community QT submission retry", item: item)
            }
        }
    }

    private func record(
        for item: PendingCommunityQTSubmission,
        in store: QTStore
    ) -> QTRecord? {
        if let exactRecord = store.record(id: item.recordId) {
            return exactRecord
        }
        return store.record(dateKey: item.dateKey)
    }

    private func enqueue(_ item: PendingCommunityQTSubmission) {
        guard !pendingItems.contains(where: { $0.id == item.id }) else { return }
        pendingItems.append(item)
        persistPendingItems()
        debugLog("Queued Community QT submission", item: item)
    }

    private func remove(_ item: PendingCommunityQTSubmission) {
        pendingItems.removeAll { $0.id == item.id }
        persistPendingItems()
    }

    private func validatedCurrentUserID(for expectedUserID: String? = nil) -> String? {
        guard let currentUserID = Auth.auth().currentUser?.uid,
              currentUserID == activeUserID,
              expectedUserID == nil || currentUserID == expectedUserID else {
            return nil
        }
        return currentUserID
    }

    private func loadPendingItems() {
        guard let activeUserID, !activeUserID.isEmpty else {
            pendingItems = []
            pendingCount = 0
            return
        }

        guard let data = defaults.data(forKey: storageKey(userID: activeUserID)),
              let decoded = try? JSONDecoder().decode(
                [PendingCommunityQTSubmission].self,
                from: data
              ) else {
            pendingItems = []
            pendingCount = 0
            return
        }

        pendingItems = decoded
        pendingCount = decoded.count
    }

    private func persistPendingItems() {
        guard let activeUserID, !activeUserID.isEmpty else { return }
        if pendingItems.isEmpty {
            defaults.removeObject(forKey: storageKey(userID: activeUserID))
        } else if let data = try? JSONEncoder().encode(pendingItems) {
            defaults.set(data, forKey: storageKey(userID: activeUserID))
        }
        pendingCount = pendingItems.count
    }

    private func storageKey(userID: String) -> String {
        "\(baseStorageKey)_\(userID)"
    }

    private func debugLog(_ message: String, item: PendingCommunityQTSubmission) {
        #if DEBUG
        print("\(message): \(item.communityId)/\(item.dateKey)")
        #endif
    }
}
