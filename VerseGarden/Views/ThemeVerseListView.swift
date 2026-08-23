import FirebaseAuth
import SwiftData
import SwiftUI

struct ThemeVerseListView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    let theme: ThemeItem

    private let service = BibleDataService.shared
    @Query(sort: \WritingRecord.completedAt, order: .reverse) private var records: [WritingRecord]
    private var currentUserRecords: [WritingRecord] {
        records.records(for: authViewModel.currentUser?.uid)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerCard

                ForEach(resolvedVerses) { item in
                    let contextIndex = resolvedVerses.firstIndex(where: { $0.id == item.id }) ?? 0
                    NavigationLink {
                        WriteView(
                            localVerse: item.verse,
                            sourceType: .theme,
                            writingContext: .theme(
                                themeId: theme.id,
                                verses: resolvedVerses.map(\.verse),
                                currentIndex: contextIndex
                            )
                        )
                    } label: {
                        ThemeVerseCard(
                            locationText: "\(item.verse.book) \(item.verse.chapter):\(item.verse.verse)",
                            previewText: versePreview(for: item.verse.text),
                            reason: item.reference.reason,
                            isCompleted: isCompleted(item.verse)
                        )
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
            .padding()
        }
        .navigationTitle(theme.title)
        .background(GardenTheme.background)
    }

    private var resolvedVerses: [ResolvedThemeVerse] {
        theme.verses.compactMap { reference in
            guard let verse = service.getVerse(book: reference.book, chapter: reference.chapter, verse: reference.verse) else {
                return nil
            }
            return ResolvedThemeVerse(reference: reference, verse: verse)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(theme.description)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ThemeVerseService.accentColor(for: theme))
            Text("\(completedVerseCount) / \(resolvedVerses.count)개 필사")
                .font(.title3.bold())
            Text("구절을 선택하면 바로 필사 화면으로 이동합니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(GardenTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
    }

    private var completedVerseCount: Int {
        resolvedVerses.filter { isCompleted($0.verse) }.count
    }

    private func isCompleted(_ verse: LocalBibleVerse) -> Bool {
        currentUserRecords.contains {
            $0.book == verse.book && $0.chapter == verse.chapter && $0.verse == verse.verse
        }
    }

    private func versePreview(for text: String) -> String {
        if text.count <= 82 {
            return text
        }
        return String(text.prefix(82)) + "..."
    }
}

private struct ResolvedThemeVerse: Identifiable {
    let reference: ThemeVerse
    let verse: LocalBibleVerse

    var id: String { reference.id }
}

private struct ThemeVerseCard: View {
    let locationText: String
    let previewText: String
    let reason: String
    let isCompleted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(locationText)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(GardenTheme.primary)
                }
            }

            Text(previewText)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            if isCompleted {
                Text("필사 완료")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GardenTheme.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(GardenTheme.cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isCompleted ? GardenTheme.primary.opacity(0.18) : Color.clear, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }
}
