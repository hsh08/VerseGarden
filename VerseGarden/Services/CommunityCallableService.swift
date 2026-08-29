import FirebaseAuth
import FirebaseFunctions
import Foundation

struct CommunityCallableService {
    private let functions = Functions.functions(region: "us-central1")

    private static let fractionalISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standardISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    func fetchMyCommunities() async throws -> [CommunityMembership] {
        guard Auth.auth().currentUser != nil else {
            throw CommunityError.notAuthenticated
        }

        do {
            let result = try await functions.httpsCallable("getMyCommunities").call()
            guard let payload = result.data as? [String: Any],
                  let items = payload["communities"] as? [[String: Any]] else {
                throw CommunityError.invalidResponse
            }

            return try items.map(makeMembership)
        } catch let error as CommunityError {
            throw error
        } catch {
            throw map(error)
        }
    }

    func redeemInvite(code: String) async throws -> CommunityJoinResult {
        guard Auth.auth().currentUser != nil else {
            throw CommunityError.notAuthenticated
        }

        let normalizedCode = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !normalizedCode.isEmpty else {
            throw CommunityError.invalidInvite
        }

        do {
            let result = try await functions
                .httpsCallable("redeemCommunityInvite")
                .call(["code": normalizedCode])
            guard let payload = result.data as? [String: Any],
                  let communityId = payload["communityId"] as? String,
                  let name = payload["name"] as? String else {
                throw CommunityError.invalidResponse
            }

            return CommunityJoinResult(
                communityId: communityId,
                communityName: name,
                alreadyMember: payload["alreadyMember"] as? Bool ?? false
            )
        } catch let error as CommunityError {
            throw error
        } catch {
            throw map(error)
        }
    }

    func submitCommunityQT(
        _ request: CommunityQTSubmissionRequest
    ) async throws -> CommunityQTSubmissionResult {
        guard Auth.auth().currentUser != nil else {
            throw CommunityQTSubmissionFailure.unauthenticated
        }

        do {
            let result = try await functions
                .httpsCallable("submitCommunityQT")
                .call(request.payload)
            guard let payload = result.data as? [String: Any],
                  payload["success"] as? Bool == true,
                  let submissionId = payload["submissionId"] as? String else {
                throw CommunityQTSubmissionFailure.invalidResponse
            }

            return CommunityQTSubmissionResult(
                alreadySubmitted: payload["alreadySubmitted"] as? Bool ?? false,
                submissionId: submissionId
            )
        } catch let failure as CommunityQTSubmissionFailure {
            throw failure
        } catch {
            throw mapSubmissionFailure(error)
        }
    }

    private func makeMembership(_ data: [String: Any]) throws -> CommunityMembership {
        guard let communityId = data["communityId"] as? String,
              let communityName = data["communityName"] as? String,
              let communityStatusValue = data["communityStatus"] as? String,
              let communityStatus = CommunityStatus(rawValue: communityStatusValue),
              let timezone = data["timezone"] as? String,
              let roleValue = data["role"] as? String,
              let role = CommunityRole(rawValue: roleValue),
              let membershipStatusValue = data["membershipStatus"] as? String,
              let membershipStatus = MembershipStatus(rawValue: membershipStatusValue),
              let joinedAtValue = data["joinedAt"] as? String,
              let joinedAt = parseISO8601Date(joinedAtValue) else {
            throw CommunityError.invalidResponse
        }

        return CommunityMembership(
            communityId: communityId,
            communityName: communityName,
            communityStatus: communityStatus,
            timezone: timezone,
            role: role,
            status: membershipStatus,
            joinedAt: joinedAt,
            memberCount: intValue(data["memberCount"])
        )
    }

    private func parseISO8601Date(_ value: String) -> Date? {
        Self.fractionalISO8601Formatter.date(from: value)
            ?? Self.standardISO8601Formatter.date(from: value)
    }

    private func map(_ error: Error) -> CommunityError {
        let nsError = error as NSError
        let message = nsError.localizedDescription.lowercased()
        let code = FunctionsErrorCode(rawValue: nsError.code)

        switch code {
        case .unauthenticated:
            return .notAuthenticated
        case .notFound, .invalidArgument:
            return .invalidInvite
        case .resourceExhausted:
            return .inviteUnavailable
        case .permissionDenied:
            return message.contains("cannot join") ? .membershipBlocked : .permissionDenied
        case .failedPrecondition:
            if message.contains("community") && (message.contains("inactive") || message.contains("not active")) {
                return .communityInactive
            }
            return .inviteUnavailable
        case .unavailable, .deadlineExceeded:
            return .network
        default:
            return .unknown
        }
    }

    private func mapSubmissionFailure(_ error: Error) -> CommunityQTSubmissionFailure {
        let nsError = error as NSError
        let code = FunctionsErrorCode(rawValue: nsError.code)

        switch code {
        case .unauthenticated:
            return .unauthenticated
        case .permissionDenied, .invalidArgument, .notFound, .failedPrecondition,
             .outOfRange, .unimplemented, .dataLoss:
            return .permanent
        case .unavailable, .deadlineExceeded, .resourceExhausted, .aborted, .cancelled,
             .internal:
            return .retryable
        default:
            if nsError.domain == NSURLErrorDomain {
                return .retryable
            }
            return .retryable
        }
    }

    private func intValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        return (value as? NSNumber)?.intValue
    }
}
