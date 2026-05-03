import FirebaseAuth
import SwiftData
import SwiftUI

struct ThemeSelectView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Query(sort: \WritingRecord.completedAt, order: .reverse) private var records: [WritingRecord]
    private var currentUserRecords: [WritingRecord] {
        records.records(for: authViewModel.currentUser?.uid)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                introCard

                ForEach(ThemeVerseService.themes) { theme in
                    NavigationLink {
                        ThemeVerseListView(theme: theme)
                    } label: {
                        themeCard(theme)
                    }
                    .buttonStyle(PressableCardStyle())
                }
            }
            .padding()
        }
        .navigationTitle("테마 선택")
        .background(Color(.systemGroupedBackground))
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("상황에 맞는 말씀으로 필사를 시작하세요.")
                .font(.title3.bold())
            Text("테마별로 묶인 구절을 보며 오늘 필요한 말씀을 고를 수 있습니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 4)
    }

    private func themeCard(_ theme: ThemeItem) -> some View {
        let accent = ThemeVerseService.accentColor(for: theme)

        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(accent.opacity(0.14))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: theme.icon)
                        .font(.title3)
                        .foregroundStyle(accent)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(theme.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(theme.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(progressText(for: theme))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(progressColor(for: theme))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)
    }

    private func completedCount(for theme: ThemeItem) -> Int {
        theme.verses.filter { verse in
            currentUserRecords.contains {
                $0.book == verse.book && $0.chapter == verse.chapter && $0.verse == verse.verse
            }
        }.count
    }

    private func progressText(for theme: ThemeItem) -> String {
        let completed = completedCount(for: theme)
        if completed == theme.verses.count {
            return "완료"
        }
        return "\(completed) / \(theme.verses.count)개 필사"
    }

    private func progressColor(for theme: ThemeItem) -> Color {
        completedCount(for: theme) > 0 ? .green : .secondary
    }
}
