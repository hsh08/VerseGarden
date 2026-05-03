import SwiftUI

struct BibleSelectView: View {
    private let service = BibleDataService.shared
    private let onSelectVerses: (([LocalBibleVerse]) -> Void)?

    init(onSelectVerses: (([LocalBibleVerse]) -> Void)? = nil) {
        self.onSelectVerses = onSelectVerses
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                introCard

                testamentSection(
                    title: "구약",
                    subtitle: "창세기부터 말라기까지",
                    testament: BibleTestament.old.rawValue,
                    accent: .green
                )

                testamentSection(
                    title: "신약",
                    subtitle: "마태복음부터 요한계시록까지",
                    testament: BibleTestament.new.rawValue,
                    accent: .mint
                )

                sourceCard
            }
            .padding()
        }
        .navigationTitle("성경 직접 선택")
        .background(Color(.systemGroupedBackground))
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("원하는 본문으로 필사하기")
                .font(.title3.bold())
            Text("구약 또는 신약을 고른 뒤 성경 권, 장, 절 순서로 선택해 필사를 시작할 수 있습니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            LinearGradient(
                colors: [Color.green.opacity(0.18), Color.mint.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func testamentSection(
        title: String,
        subtitle: String,
        testament: String,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            NavigationLink {
                BibleBookListView(testament: testament, onSelectVerses: onSelectVerses)
            } label: {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(0.14))
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: testament == BibleTestament.old.rawValue ? "text.book.closed.fill" : "book.fill")
                                .font(.title3)
                                .foregroundStyle(accent)
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(title) 성경 권 보기")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("\(subtitle) · \(service.getBooks(testament: testament).count)권")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("본문 출처")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(BibleDataService.translationSourceTitle)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
