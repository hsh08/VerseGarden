import Foundation

struct CommunityQTSubmissionRequest: Hashable {
    let communityId: String
    let dateKey: String
    let contentId: String
    let contentVersion: Int
    let reflectionAnswer: String
    let applicationText: String

    init?(record: QTRecord) {
        guard record.isCompleted,
              record.contentSource == .community,
              let communityId = record.communityId?.trimmedForCommunitySubmission,
              !communityId.isEmpty,
              let contentId = record.contentId?.trimmedForCommunitySubmission,
              !contentId.isEmpty,
              let contentVersion = record.contentVersion,
              contentVersion > 0 else {
            return nil
        }

        let dateKey = record.contentDateKey?.trimmedForCommunitySubmission ?? record.dateKey
        guard !dateKey.isEmpty, contentId == dateKey else { return nil }

        self.communityId = communityId
        self.dateKey = dateKey
        self.contentId = contentId
        self.contentVersion = contentVersion
        self.reflectionAnswer = record.reflectionAnswer
        self.applicationText = record.applicationText
    }

    var payload: [String: Any] {
        [
            "communityId": communityId,
            "dateKey": dateKey,
            "contentId": contentId,
            "contentVersion": contentVersion,
            "reflectionAnswer": reflectionAnswer,
            "applicationText": applicationText
        ]
    }
}

struct CommunityQTSubmissionResult: Hashable {
    let alreadySubmitted: Bool
    let submissionId: String
}

struct PendingCommunityQTSubmission: Identifiable, Codable, Hashable {
    let recordId: String
    let communityId: String
    let dateKey: String
    let contentId: String
    let contentVersion: Int

    var id: String {
        "\(communityId)|\(dateKey)|\(recordId)"
    }

    init?(record: QTRecord) {
        guard let request = CommunityQTSubmissionRequest(record: record) else { return nil }
        self.recordId = record.id
        self.communityId = request.communityId
        self.dateKey = request.dateKey
        self.contentId = request.contentId
        self.contentVersion = request.contentVersion
    }

    func matches(_ record: QTRecord) -> Bool {
        guard let request = CommunityQTSubmissionRequest(record: record) else { return false }
        return request.communityId == communityId
            && request.dateKey == dateKey
            && request.contentId == contentId
            && request.contentVersion == contentVersion
    }
}

enum CommunityQTSubmissionFailure: Error {
    case unauthenticated
    case retryable
    case permanent
    case invalidResponse
}

private extension String {
    var trimmedForCommunitySubmission: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
