import SwiftUI

struct BibleChapterCard: View {
    let chapter: Int
    let verseCount: Int
    let completedVerseCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: iconName)
                    .font(.subheadline)
                    .foregroundStyle(iconColor)
                Spacer()
            }

            Text("\(chapter)장")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(statusColor)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(14)
        .gardenCardSurface(
            background: backgroundColor,
            border: borderColor,
            cornerRadius: AppRadius.medium,
            shadowRadius: 8,
            shadowY: 3
        )
    }

    private var isInProgress: Bool {
        completedVerseCount > 0 && completedVerseCount < verseCount
    }

    private var isFullyCompleted: Bool {
        verseCount > 0 && completedVerseCount == verseCount
    }

    private var iconName: String {
        if isFullyCompleted {
            return "checkmark.circle.fill"
        }
        if isInProgress {
            return "doc.text.fill"
        }
        return "square.grid.2x2"
    }

    private var iconColor: Color {
        isFullyCompleted || isInProgress ? GardenTheme.primary : .secondary
    }

    private var statusText: String {
        if isFullyCompleted {
            return "\(completedVerseCount) / \(verseCount)절 완료"
        }
        if isInProgress {
            return "\(completedVerseCount) / \(verseCount)절 필사"
        }
        return "\(verseCount)절"
    }

    private var statusColor: Color {
        isFullyCompleted || isInProgress ? GardenTheme.primary : .secondary
    }

    private var backgroundColor: Color {
        if isFullyCompleted {
            return GardenTheme.primary.opacity(0.14)
        }
        if isInProgress {
            return GardenTheme.primary.opacity(0.08)
        }
        return GardenTheme.cardBackground
    }

    private var borderColor: Color {
        if isFullyCompleted {
            return GardenTheme.primary.opacity(0.50)
        }
        if isInProgress {
            return GardenTheme.primary.opacity(0.30)
        }
        return AppColors.border.opacity(0.72)
    }
}
