import FirebaseAuth
import SwiftData
import SwiftUI

struct ScriptureHomeView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var likedVerseStore: LikedVerseStore
    @Query(sort: \MyVerseList.createdAt, order: .reverse) private var lists: [MyVerseList]
    @Query(sort: \MyVerseListItem.createdAt, order: .forward) private var items: [MyVerseListItem]
    @Query(sort: \ScriptureWritingPlan.updatedAt, order: .reverse) private var plans: [ScriptureWritingPlan]
    @State private var searchQuery = ""

    private let bibleService = BibleDataService.shared

    private var todayVerse: TodayVerseContent? {
        TodayVerseService.todayVerse()
    }

    private var currentUserLists: [MyVerseList] {
        lists.lists(for: authViewModel.currentUser?.uid)
    }

    private var currentUserItems: [MyVerseListItem] {
        items.items(for: authViewModel.currentUser?.uid)
    }

    private var hasAnyPlans: Bool {
        !plans.plans(for: authViewModel.currentUser?.uid).isEmpty
    }

    private var hasBlockingPlan: Bool {
        ScriptureWritingPlanService.blockingPlan(from: plans, userID: authViewModel.currentUser?.uid) != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                todayVerseSection
                searchSection
                bibleReadSection
                scriptureActionsSection
                likedVerseSection
                verseListSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("말씀")
        .background(GardenTheme.background)
    }

    private var todayVerseSection: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.26), AppColors.cardTint.opacity(0.62)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("오늘의 구절")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(GardenTheme.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.62))
                            .clipShape(Capsule())

                        Text(todayVerse?.referenceText ?? "오늘의 말씀")
                            .font(.title3.bold())
                            .foregroundStyle(AppColors.primaryText)
                    }

                    Spacer()

                    Image(systemName: "book.pages.fill")
                        .font(.title3)
                        .foregroundStyle(GardenTheme.primary)
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.58))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                }

                if let todayVerse {
                    Text(todayVerse.displayText)
                        .font(.body)
                        .foregroundStyle(AppColors.primaryText)
                        .lineSpacing(6)
                        .lineLimit(4)

                    if let localVerse = todayVerse.verse {
                        HStack(spacing: 10) {
                            NavigationLink {
                                VerseDetailView(verse: localVerse)
                            } label: {
                                compactActionButton(title: "말씀 보기", icon: "book.pages.fill", isPrimary: true)
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                WriteView(localVerse: localVerse)
                            } label: {
                                compactActionButton(title: "필사하기", icon: "pencil.line")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Text("오늘의 말씀을 준비하는 중입니다.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                }
            }
        }
    }

    private var searchSection: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                GardenSectionHeader("말씀 검색", subtitle: "본문, 책 이름, 장절로 간단히 찾아볼 수 있습니다.")

                TextField("예: 평안, 요한복음, 시편 23", text: $searchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(GardenTheme.softFill)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                            .stroke(AppColors.border.opacity(0.8), lineWidth: 1)
                    }

                if trimmedSearchQuery.isEmpty {
                    Text("검색어를 입력하면 실제 성경 데이터에서 최대 12개 결과를 보여줍니다.")
                        .font(.caption)
                        .foregroundStyle(AppColors.secondaryText)
                } else if searchResults.isEmpty {
                    EmptyStateView(
                        icon: "magnifyingglass",
                        title: "검색 결과가 없어요",
                        message: "다른 단어나 책 이름으로 다시 검색해보세요."
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(searchResults) { verse in
                            NavigationLink {
                                VerseDetailView(verse: verse)
                            } label: {
                                versePreviewRow(verse)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var bibleReadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GardenSectionHeader("성경 읽기", subtitle: "책과 장을 선택해 본문을 읽습니다.")

            NavigationLink {
                BibleBookReadListView()
            } label: {
                actionCard(
                    title: "성경 책 목록 열기",
                    description: "구약과 신약 전체 \(bibleService.allBooks().count)권을 실제 본문으로 탐색합니다.",
                    icon: "book.closed.fill"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var scriptureActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GardenSectionHeader("필사로 이어가기", subtitle: "읽은 말씀을 쓰기 루틴으로 연결합니다.")

            if hasBlockingPlan || hasAnyPlans {
                NavigationLink {
                    MyPlansView()
                } label: {
                    featuredWritingPlanActionCard(
                        title: "필사 플랜 관리",
                        description: "진행 중인 플랜과 완료한 플랜을 한곳에서 확인하고, 오늘 분량을 이어서 필사할 수 있습니다.",
                        icon: "calendar.badge.clock"
                    )
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    CreateWritingPlanView()
                } label: {
                    featuredWritingPlanActionCard(
                        title: "필사 플랜 만들기",
                        description: "책과 장 범위, 시작일, 기간을 정해 매일 쓸 말씀 분량을 자동으로 나눕니다.",
                        icon: "calendar.badge.plus"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var likedVerseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GardenSectionHeader("내가 저장한 말씀", subtitle: "마음에 남은 말씀을 다시 꺼내보세요.")

            NavigationLink {
                VerseListView()
            } label: {
                GardenCard {
                    HStack(spacing: 14) {
                        Image(systemName: "heart.fill")
                            .font(.headline)
                            .foregroundStyle(GardenTheme.tertiary)
                            .frame(width: 46, height: 46)
                            .background(GardenTheme.tertiary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))

                        VStack(alignment: .leading, spacing: 5) {
                            Text("말씀 보관함 열기")
                                .font(.headline)
                                .foregroundStyle(AppColors.primaryText)
                            Text("\(likedVerseStore.likedCount)개 저장됨")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.secondaryText)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColors.secondaryText)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }


    private var verseListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GardenSectionHeader("나만의 구절 리스트", subtitle: currentUserLists.isEmpty ? "저장한 리스트가 없습니다." : "자주 읽고 싶은 말씀을 모아두는 공간입니다.")

            NavigationLink {
                MyVerseListView()
            } label: {
                GardenCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("구절 리스트 열기")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(currentUserLists.count)개 리스트 · \(currentUserItems.count)개 구절")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppColors.secondaryText)
                        }

                        if let firstList = currentUserLists.first {
                            Text(firstList.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(GardenTheme.primary)
                            if !firstList.memo.isEmpty {
                                Text(firstList.memo)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.secondaryText)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func actionCard(title: String, description: String, icon: String) -> some View {
        GardenCard {
            HStack(alignment: .center, spacing: 14) {
                RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                    .fill(GardenTheme.primary.opacity(0.12))
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(GardenTheme.primary)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppColors.primaryText)
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColors.secondaryText)
            }
            .frame(minHeight: 58)
        }
    }

    private func featuredWritingPlanActionCard(title: String, description: String, icon: String) -> some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.18), AppColors.cardTint.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(GardenTheme.primary.opacity(0.14))
                        .frame(width: 62, height: 62)
                        .overlay {
                            Image(systemName: icon)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(GardenTheme.primary)
                        }

                    VStack(alignment: .leading, spacing: 7) {
                        Text("필사 루틴")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(GardenTheme.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.64))
                            .clipShape(Capsule())

                        Text(title)
                            .font(.title3.bold())
                            .foregroundStyle(AppColors.primaryText)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(GardenTheme.primary)
                        .frame(width: 34, height: 34)
                        .background(GardenTheme.softFill)
                        .clipShape(Circle())
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.secondaryText)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    Text(hasBlockingPlan || hasAnyPlans ? "플랜으로 이동" : "새 플랜 시작")
                        .font(.caption.weight(.bold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(GardenTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private func compactActionButton(title: String, icon: String, isPrimary: Bool = false) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
            Text(title)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(isPrimary ? .white : GardenTheme.primary)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 48)
        .background(isPrimary ? GardenTheme.primary : GardenTheme.softFill)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                .stroke(isPrimary ? Color.clear : GardenTheme.softStroke, lineWidth: 1)
        }
    }

    private func versePreviewRow(_ verse: LocalBibleVerse) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(verse.referenceText)
                .font(.caption.weight(.bold))
                .foregroundStyle(GardenTheme.primary)
                .frame(width: 82, alignment: .leading)

            Text(verse.text)
                .font(.subheadline)
                .foregroundStyle(AppColors.primaryText)
                .lineLimit(2)
                .lineSpacing(3)

            Spacer(minLength: 0)

            Image(systemName: likedVerseStore.isLiked(verse) ? "heart.fill" : "heart")
                .font(.caption.weight(.bold))
                .foregroundStyle(likedVerseStore.isLiked(verse) ? GardenTheme.tertiary : AppColors.subtleText)
        }
        .padding(12)
        .background(GardenTheme.softFill.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
    }

    private var trimmedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchResults: [LocalBibleVerse] {
        bibleService.searchVerses(query: trimmedSearchQuery, limit: 12)
    }
}
