import Foundation

enum CommunityStatus: String, Codable, Hashable {
    case active
    case inactive
    case archived
}

enum CommunityRole: String, Codable, Hashable {
    case member
    case leader
    case admin

    var displayName: String {
        switch self {
        case .member: "멤버"
        case .leader: "리더"
        case .admin: "공동체 관리자"
        }
    }
}

enum MembershipStatus: String, Codable, Hashable {
    case active
    case removed
    case banned
    case left
}

struct Community: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String?
    let status: CommunityStatus
    let timezone: String
    let memberCount: Int?
    let primaryLeaderUid: String?
    let inviteEnabled: Bool
}

struct CommunityMembership: Identifiable, Hashable {
    var id: String { communityId }

    let communityId: String
    let communityName: String
    let communityStatus: CommunityStatus
    let timezone: String
    let role: CommunityRole
    let status: MembershipStatus
    let joinedAt: Date
    let memberCount: Int?

    var isOperational: Bool {
        status == .active && communityStatus == .active
    }
}

struct CommunityJoinResult: Hashable {
    let communityId: String
    let communityName: String
    let alreadyMember: Bool
}

enum CommunityError: LocalizedError {
    case notAuthenticated
    case invalidInvite
    case inviteUnavailable
    case communityInactive
    case membershipBlocked
    case permissionDenied
    case invalidResponse
    case network
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "다시 로그인한 뒤 시도해주세요."
        case .invalidInvite:
            "유효하지 않은 초대 코드입니다."
        case .inviteUnavailable:
            "사용할 수 없는 초대 코드입니다."
        case .communityInactive:
            "현재 참여할 수 없는 공동체입니다."
        case .membershipBlocked:
            "이 공동체에 참여할 수 없습니다."
        case .permissionDenied:
            "공동체 정보를 확인할 권한이 없습니다."
        case .invalidResponse:
            "공동체 정보를 불러오지 못했습니다."
        case .network:
            "네트워크 연결을 확인한 뒤 다시 시도해주세요."
        case .unknown:
            "공동체 참여 중 문제가 발생했습니다. 다시 시도해주세요."
        }
    }
}
