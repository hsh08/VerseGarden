import Foundation

struct UserProfile: Identifiable, Equatable {
    let id: String
    var email: String
    var nickname: String
    var onboardingCompleted: Bool = false
    var favoriteVerse: String = ""
    var favoriteVerseId: String?
    var selectedWritingPlanId: String?
    var selectedTopics: [String] = []
    var createdAt: Date
    var updatedAt: Date
}
