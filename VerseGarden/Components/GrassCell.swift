import SwiftUI

struct GrassCell: View {
    let count: Int
    var size: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(color)
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(borderColor, lineWidth: 0.5)
            }
            .frame(width: size, height: size)
    }

    private var color: Color {
        Self.fillColor(for: count)
    }

    private var borderColor: Color {
        Self.strokeColor(for: count)
    }

    static func fillColor(for count: Int) -> Color {
        switch count {
        case 0:
            return AppColors.grassInactive
        case 1:
            return AppColors.grassLevel1
        case 2:
            return AppColors.grassLevel2
        case 3:
            return AppColors.grassLevel3
        default:
            return AppColors.grassLevel4
        }
    }

    static func strokeColor(for count: Int) -> Color {
        count == 0 ? AppColors.border.opacity(0.55) : GardenTheme.primary.opacity(0.18)
    }
}
