import SwiftUI

struct MonthGrassCell: View {
    let dayNumber: Int
    let count: Int
    let isToday: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text("\(dayNumber)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(count == 0 ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .center)

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(GrassCell.fillColor(for: count))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(GrassCell.strokeColor(for: count), lineWidth: 0.8)
                }
                .frame(width: 24, height: 24)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, minHeight: 62, maxHeight: 62, alignment: .top)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isToday ? Color.green.opacity(0.85) : Color.clear, lineWidth: 1.4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
