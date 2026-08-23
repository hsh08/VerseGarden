import SwiftUI

struct BibleBookReadListView: View {
    private let service = BibleDataService.shared
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                headerCard
                testamentSection(.old)
                testamentSection(.new)
                sourceCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("성경 읽기")
        .background(GardenTheme.background)
    }

    private var headerCard: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.18), GardenTheme.secondary.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("성경 말씀 탐색")
                    .font(.title2.bold())
                    .foregroundStyle(AppColors.primaryText)
                Text("책과 장을 고르고 실제 성경 본문을 읽을 수 있습니다.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }

    private func testamentSection(_ testament: BibleTestament) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            GardenSectionHeader(
                testament.title,
                subtitle: "\(service.books(in: testament).count)권"
            )

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(service.books(in: testament), id: \.self) { book in
                    NavigationLink {
                        BibleChapterReadView(book: book, chapter: service.getChapters(book: book).first ?? 1)
                    } label: {
                        bookCard(book: book)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func bookCard(book: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(book)
                .font(.headline)
                .foregroundStyle(AppColors.primaryText)
                .lineLimit(1)
            Text("\(service.getChapters(book: book).count)장")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GardenTheme.primary)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(14)
        .gardenCardSurface(
            background: GardenTheme.cardBackground,
            border: AppColors.border.opacity(0.68),
            cornerRadius: AppRadius.medium,
            shadowRadius: 6,
            shadowY: 3
        )
    }

    private var sourceCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("본문 출처")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.secondaryText)
                Text(BibleDataService.translationSourceTitle)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.primaryText)
                Text("배포 전 번역본 사용 허가와 라이선스를 확인해야 합니다.")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryText)
            }
        }
    }
}
