import SwiftUI

struct BibleBookCard: View {
    let title: String
    let chapterCount: Int
    let startedChapterCount: Int
    let isFullyCompleted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(chapterCount)개 장")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isFullyCompleted ? "checkmark.circle.fill" : startedChapterCount > 0 ? "book.fill" : "book.closed")
                    .font(.title3)
                    .foregroundStyle(isFullyCompleted || startedChapterCount > 0 ? GardenTheme.primary : .secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(statusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)

                ProgressView(value: progressValue)
                    .tint(GardenTheme.primary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(18)
        .gardenCardSurface()
    }

    private var progressValue: Double {
        guard chapterCount > 0 else { return 0 }
        return Double(startedChapterCount) / Double(chapterCount)
    }

    private var statusText: String {
        if isFullyCompleted {
            return "완료"
        }
        if startedChapterCount == 0 {
            return "아직 필사 전"
        }
        return "진행 중 · \(startedChapterCount)장 필사"
    }

    private var statusColor: Color {
        startedChapterCount > 0 || isFullyCompleted ? GardenTheme.primary : .secondary
    }
}
