import SwiftUI

struct GrassGridView: View {
    let rows: Int
    let columns: Int
    let filledCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(cellColor(for: index))
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("잔디 기록 프리뷰")
    }

    private func cellColor(for index: Int) -> Color {
        if index < filledCount {
            let ratio = Double(index) / Double(max(filledCount, 1))
            if ratio < 0.34 {
                return Color.green.opacity(0.32)
            } else if ratio < 0.67 {
                return Color.green.opacity(0.50)
            } else {
                return Color.mint.opacity(0.72)
            }
        }

        return Color.green.opacity(0.10)
    }
}
