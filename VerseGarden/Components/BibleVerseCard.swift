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
                    .foregroundStyle(GardenTheme.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(GardenTheme.primary)
                } else if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(GardenTheme.primary)
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
                    .foregroundStyle(GardenTheme.primary)
            } else if isCompleted {
                Text("필사 완료")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GardenTheme.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .gardenCardSurface(
            background: isSelected ? GardenTheme.softFill : GardenTheme.cardBackground,
            border: isSelected ? GardenTheme.primary.opacity(0.36) : isCompleted ? GardenTheme.primary.opacity(0.16) : AppColors.border.opacity(0.45),
            cornerRadius: AppRadius.card,
            shadowRadius: 10,
            shadowY: 4
        )
    }
}
