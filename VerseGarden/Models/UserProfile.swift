import Foundation

struct UserProfile: Identifiable, Equatable {
    let id: String
    var email: String
    var nickname: String
    var createdAt: Date
    var updatedAt: Date
}
