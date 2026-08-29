import Combine
import Foundation

@MainActor
final class CommunityStore: ObservableObject {
    @Published private(set) var memberships: [CommunityMembership] = []
    @Published private(set) var currentMembership: CommunityMembership?
    @Published private(set) var currentCommunity: Community?
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var errorMessage: String?

    private let callableService: CommunityCallableService
    private let firestoreService: CommunityFirestoreService
    private let defaults: UserDefaults
    private var activeUserID: String?

    init(
        callableService: CommunityCallableService? = nil,
        firestoreService: CommunityFirestoreService? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.callableService = callableService ?? CommunityCallableService()
        self.firestoreService = firestoreService ?? CommunityFirestoreService()
        self.defaults = defaults
    }

    func load(for userID: String, force: Bool = false) async {
        guard !userID.isEmpty else {
            clear()
            return
        }
        if activeUserID != userID {
            clear()
            activeUserID = userID
        }
        guard force || !hasLoaded else { return }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let fetched = try await callableService.fetchMyCommunities()
            memberships = fetched
            let operational = fetched.filter(\.isOperational)
            let preferredId = defaults.string(forKey: selectionKey(userID: userID))
            let selected = operational.first { $0.communityId == preferredId }
                ?? operational.first
            currentMembership = selected

            if let selected {
                defaults.set(selected.communityId, forKey: selectionKey(userID: userID))
                currentCommunity = try await firestoreService.fetchCommunity(id: selected.communityId)
            } else {
                currentCommunity = nil
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "공동체 정보를 불러오지 못했습니다."
        }
    }

    func refresh() async {
        guard let activeUserID else { return }
        await load(for: activeUserID, force: true)
    }

    func redeemInvite(code: String) async throws -> CommunityJoinResult {
        let result = try await callableService.redeemInvite(code: code)
        guard let activeUserID else {
            throw CommunityError.notAuthenticated
        }
        defaults.set(result.communityId, forKey: selectionKey(userID: activeUserID))
        await load(for: activeUserID, force: true)
        return result
    }

    func retry() async {
        await refresh()
    }

    func clear() {
        memberships = []
        currentMembership = nil
        currentCommunity = nil
        isLoading = false
        hasLoaded = false
        errorMessage = nil
        activeUserID = nil
    }

    private func selectionKey(userID: String) -> String {
        "versegarden_selected_community_\(userID)"
    }
}
