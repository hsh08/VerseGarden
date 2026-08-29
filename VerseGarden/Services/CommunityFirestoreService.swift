import FirebaseAuth
import FirebaseFirestore
import Foundation

struct CommunityFirestoreService {
    private var database: Firestore { Firestore.firestore() }

    func fetchCommunity(id: String) async throws -> Community {
        guard Auth.auth().currentUser != nil else {
            throw CommunityError.notAuthenticated
        }

        let snapshot = try await database
            .collection("communities")
            .document(id)
            .getDocument()
        guard snapshot.exists,
              let data = snapshot.data(),
              let name = data["name"] as? String,
              let statusValue = data["status"] as? String,
              let status = CommunityStatus(rawValue: statusValue),
              let timezone = data["timezone"] as? String else {
            throw CommunityError.invalidResponse
        }

        return Community(
            id: snapshot.documentID,
            name: name,
            description: data["description"] as? String,
            status: status,
            timezone: timezone,
            memberCount: intValue(data["memberCount"]),
            primaryLeaderUid: data["primaryLeaderUid"] as? String,
            inviteEnabled: data["inviteEnabled"] as? Bool ?? true
        )
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        return (value as? NSNumber)?.intValue
    }
}
