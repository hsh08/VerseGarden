import FirebaseAuth
import SwiftData
import SwiftUI

struct MyVerseListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var verseListSyncCoordinator: VerseListSyncCoordinator
    @Query(sort: \MyVerseList.createdAt, order: .reverse) private var lists: [MyVerseList]
    @Query(sort: \MyVerseListItem.createdAt, order: .forward) private var allItems: [MyVerseListItem]

    @State private var showingCreateSheet = false
    @State private var editingList: MyVerseList?
    @State private var deletingList: MyVerseList?
    @State private var listSummaries: [VerseListSummary] = []

    private var listMetricsSignature: String {
        let userID = authViewModel.currentUser?.uid ?? "no-user"
        let filteredLists = lists.lists(for: authViewModel.currentUser?.uid)
        let filteredItems = allItems.items(for: authViewModel.currentUser?.uid)
        let listSignature = filteredLists
            .map {
                "\($0.id.uuidString)|\($0.title)|\($0.memo)|\($0.updatedAt.timeIntervalSince1970)|\($0.remoteDocumentId ?? "")"
            }
            .joined(separator: ",")
        let itemSignature = filteredItems
            .map { "\($0.id.uuidString)|\($0.listId.uuidString)" }
            .joined(separator: ",")
        return "\(userID)||\(listSignature)||\(itemSignature)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                headerCard

                GardenPrimaryButton(title: "리스트 만들기", icon: "plus.circle.fill") {
                    showingCreateSheet = true
                }
                .buttonStyle(.plain)

                if listSummaries.isEmpty {
                    ContentUnavailableView(
                        "아직 만든 리스트가 없습니다",
                        systemImage: "bookmark",
                        description: Text("자주 필사하고 싶은 구절을 리스트로 모아보세요.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(listSummaries) { summary in
                            NavigationLink {
                                MyVerseListDetailView(list: summary.list)
                            } label: {
                                listCard(summary)
                            }
                            .buttonStyle(PressableCardStyle())
                            .contextMenu {
                                Button {
                                    editingList = summary.list
                                } label: {
                                    Label("리스트 수정", systemImage: "square.and.pencil")
                                }

                                Button(role: .destructive) {
                                    deletingList = summary.list
                                } label: {
                                    Label("리스트 삭제", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("리스트")
        .background(GardenTheme.background)
        .task(id: listMetricsSignature) {
            refreshListSummaries()
        }
        .sheet(isPresented: $showingCreateSheet) {
            NavigationStack {
                CreateMyVerseListView()
            }
        }
        .sheet(item: $editingList) { list in
            NavigationStack {
                CreateMyVerseListView(list: list)
            }
        }
        .alert("리스트를 삭제할까요?", isPresented: deleteAlertBinding) {
            Button("취소", role: .cancel) {
                deletingList = nil
            }
            Button("삭제", role: .destructive) {
                confirmDeleteList()
            }
        } message: {
            Text("리스트와 그 안의 구절이 함께 삭제됩니다.")
        }
    }

    private var headerCard: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.75), GardenTheme.secondary.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("나만의 구절 리스트")
                    .font(.title3.bold())
                Text("자주 읽고 싶거나 나중에 필사하고 싶은 구절을 직접 모아둘 수 있습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func listCard(_ summary: VerseListSummary) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GardenTheme.primary.opacity(0.14))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "bookmark.fill")
                        .font(.title3)
                        .foregroundStyle(GardenTheme.primary)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(summary.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if !summary.memo.isEmpty {
                    Text(summary.memo)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text("\(summary.itemCount)개 구절")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GardenTheme.primary)
            }

            Spacer()

            VStack(spacing: 10) {
                Button {
                    deletingList = summary.list
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.10))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AppColors.cardTint)
        .clipShape(RoundedRectangle(cornerRadius: GardenTheme.cornerRadius, style: .continuous))
    }

    private func refreshListSummaries() {
        let currentUserLists = lists.lists(for: authViewModel.currentUser?.uid)
        let currentUserItems = allItems.items(for: authViewModel.currentUser?.uid)
        let itemCountByListID = Dictionary(currentUserItems.map { ($0.listId, 1) }, uniquingKeysWith: +)

        listSummaries = currentUserLists.map { list in
            VerseListSummary(
                list: list,
                itemCount: itemCountByListID[list.id] ?? 0
            )
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deletingList != nil },
            set: { isPresented in
                if !isPresented {
                    deletingList = nil
                }
            }
        )
    }

    private func confirmDeleteList() {
        guard let list = deletingList else { return }
        deletingList = nil

        Task {
            await verseListSyncCoordinator.deleteListIfNeeded(
                localListID: list.id,
                userID: authViewModel.currentUser?.uid,
                modelContext: modelContext
            )
        }
    }
}

private struct VerseListSummary: Identifiable {
    let list: MyVerseList
    let itemCount: Int

    var id: UUID { list.id }
    var title: String { list.title }
    var memo: String { list.memo }
    var updatedAt: Date { list.updatedAt }
    var remoteDocumentId: String? { list.remoteDocumentId }
}
