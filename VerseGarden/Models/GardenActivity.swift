import Foundation

struct GardenActivity: Identifiable, Codable, Hashable {
    let id: String
    let type: GardenActivityType
    let title: String
    let verseId: String?
    let reference: String?
    let contentPreview: String?
    let sourceId: String?
    let createdAt: Date

    init(
        id: String = UUID().uuidString,
        type: GardenActivityType,
        title: String,
        verseId: String? = nil,
        reference: String? = nil,
        contentPreview: String? = nil,
        sourceId: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.verseId = verseId
        self.reference = reference
        self.contentPreview = contentPreview
        self.sourceId = sourceId
        self.createdAt = createdAt
    }
}

enum GardenActivityType: String, CaseIterable, Codable {
    case verseRead
    case verseLiked
    case scriptureCopy
    case prayer
    case qtCompleted

    var displayTitle: String {
        switch self {
        case .verseRead:
            return "말씀 읽음"
        case .verseLiked:
            return "말씀 저장"
        case .scriptureCopy:
            return "필사 완료"
        case .prayer:
            return "기도 기록"
        case .qtCompleted:
            return "QT 완료"
        }
    }

    var iconName: String {
        switch self {
        case .verseRead:
            return "book.pages.fill"
        case .verseLiked:
            return "heart.fill"
        case .scriptureCopy:
            return "pencil.line"
        case .prayer:
            return "hands.sparkles.fill"
        case .qtCompleted:
            return "sun.max.fill"
        }
    }

    var countsTowardGardenGrowth: Bool {
        switch self {
        case .verseLiked, .scriptureCopy, .prayer, .qtCompleted:
            return true
        case .verseRead:
            return false
        }
    }

    var appearsInRecentActivity: Bool {
        true
    }
}
