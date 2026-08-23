import SwiftUI

enum WritingPlanFolderColor: String, CaseIterable, Identifiable {
    case sage
    case honey
    case sky
    case soil
    case cream
    case red
    case coral
    case orange
    case yellow
    case mint
    case blue
    case navy
    case purple
    case pink

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sage:
            return "세이지"
        case .honey:
            return "허니"
        case .sky:
            return "스카이"
        case .soil:
            return "브라운"
        case .cream:
            return "크림"
        case .red:
            return "레드"
        case .coral:
            return "코랄"
        case .orange:
            return "오렌지"
        case .yellow:
            return "옐로"
        case .mint:
            return "민트"
        case .blue:
            return "블루"
        case .navy:
            return "네이비"
        case .purple:
            return "퍼플"
        case .pink:
            return "핑크"
        }
    }

    var color: Color {
        switch self {
        case .sage:
            return GardenTheme.primary
        case .honey:
            return GardenTheme.tertiary
        case .sky:
            return Color(hex: 0x8FA9C7)
        case .soil:
            return Color(hex: 0xB89B72)
        case .cream:
            return GardenTheme.secondary
        case .red:
            return Color(hex: 0xC75D5D)
        case .coral:
            return Color(hex: 0xD98A76)
        case .orange:
            return Color(hex: 0xD49A4B)
        case .yellow:
            return Color(hex: 0xD8BE57)
        case .mint:
            return Color(hex: 0x7DB7A0)
        case .blue:
            return Color(hex: 0x5F83B5)
        case .navy:
            return Color(hex: 0x4B628A)
        case .purple:
            return Color(hex: 0x8B6FAE)
        case .pink:
            return Color(hex: 0xC982A0)
        }
    }

    var checkmarkColor: Color {
        switch self {
        case .cream, .yellow, .honey:
            return AppColors.primaryText
        default:
            return .white
        }
    }
}
