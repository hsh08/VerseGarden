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
        .background(backgroundColor)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: isFullyCompleted ? 1.4 : isInProgress ? 1.1 : 0.8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
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
        isFullyCompleted || isInProgress ? .green : .secondary
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
        isFullyCompleted || isInProgress ? .green : .secondary
    }

    private var backgroundColor: Color {
        if isFullyCompleted {
            return Color.green.opacity(0.16)
        }
        if isInProgress {
            return Color.green.opacity(0.08)
        }
        return Color(.systemBackground)
    }

    private var borderColor: Color {
        if isFullyCompleted {
            return Color.green.opacity(0.55)
        }
        if isInProgress {
            return Color.green.opacity(0.32)
        }
        return Color.black.opacity(0.05)
    }
}
