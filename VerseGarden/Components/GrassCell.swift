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
            return Color(red: 0.92, green: 0.94, blue: 0.93)
        case 1:
            return Color(red: 0.77, green: 0.91, blue: 0.75)
        case 2:
            return Color(red: 0.49, green: 0.78, blue: 0.48)
        case 3:
            return Color(red: 0.23, green: 0.63, blue: 0.31)
        default:
            return Color(red: 0.10, green: 0.42, blue: 0.18)
        }
    }

    static func strokeColor(for count: Int) -> Color {
        count == 0 ? Color.black.opacity(0.04) : Color.black.opacity(0.08)
    }
}
