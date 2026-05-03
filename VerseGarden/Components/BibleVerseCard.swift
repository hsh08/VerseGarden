import SwiftUI

struct BibleVerseCard: View {
    let verseNumber: Int
    let previewText: String
    let isCompleted: Bool
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("\(verseNumber)절")
                    .font(.headline)
                    .foregroundStyle(.green)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                } else if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "doc.text")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(previewText)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            if isSelected {
                Text("추가할 구절")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else if isCompleted {
                Text("필사 완료")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(isSelected ? Color.green.opacity(0.08) : Color(.systemBackground))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isSelected ? Color.green.opacity(0.4) : isCompleted ? Color.green.opacity(0.18) : Color.clear, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }
}
