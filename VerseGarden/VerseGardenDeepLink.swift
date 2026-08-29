import Combine
import Foundation

enum VerseGardenDeepLink: Equatable {
    case verse(verseID: String)
    case write(verseID: String)
    case profile
    case today
    case favorite

    init?(url: URL) {
        guard url.scheme?.lowercased() == "versegarden" else { return nil }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch (url.host?.lowercased(), pathComponents) {
        case ("verse", ["today"]):
            self = .today
        case ("verse", ["favorite"]):
            self = .favorite
        case ("verse", let pathComponents) where pathComponents.count == 1:
            let verseID = pathComponents[0]
            guard !verseID.isEmpty else { return nil }
            self = .verse(verseID: verseID)
        case ("write", let pathComponents) where pathComponents.count == 1:
            let verseID = pathComponents[0]
            guard !verseID.isEmpty else { return nil }
            self = .write(verseID: verseID)
        case ("profile", []):
            self = .profile
        default:
            return nil
        }
    }
}

@MainActor
final class VerseGardenDeepLinkRouter: ObservableObject {
    @Published private(set) var pendingDeepLink: VerseGardenDeepLink?

    func handle(_ url: URL) {
        guard let deepLink = VerseGardenDeepLink(url: url) else { return }
        pendingDeepLink = deepLink
    }

    func consumePendingDeepLink() -> VerseGardenDeepLink? {
        guard let pendingDeepLink else { return nil }
        self.pendingDeepLink = nil
        return pendingDeepLink
    }
}
