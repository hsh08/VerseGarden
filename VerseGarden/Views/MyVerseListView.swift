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

    private var currentUserLists: [MyVerseList] {
        lists.lists(for: authViewModel.currentUser?.uid)
    }

    private var currentUserItems: [MyVerseListItem] {
        allItems.items(for: authViewModel.currentUser?.uid)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard

                Button {
                    showingCreateSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("리스트 만들기")
                            .font(.headline)
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color.mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)

                if currentUserLists.isEmpty {
                    ContentUnavailableView(
                        "아직 만든 리스트가 없습니다",
                        systemImage: "bookmark",
                        description: Text("자주 필사하고 싶은 구절을 리스트로 모아보세요.")
                    )
                    .padding(.top, 40)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(currentUserLists) { list in
                            NavigationLink {
                                MyVerseListDetailView(list: list)
                            } label: {
                                listCard(list)
                            }
                            .buttonStyle(PressableCardStyle())
                            .contextMenu {
                                Button {
                                    editingList = list
                                } label: {
                                    Label("리스트 수정", systemImage: "square.and.pencil")
                                }

                                Button(role: .destructive) {
                                    deletingList = list
                                } label: {
                                    Label("리스트 삭제", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("리스트")
        .background(Color(.systemGroupedBackground))
        .onAppear {
            guard authViewModel.currentUser != nil else { return }
            Task {
                await verseListSyncCoordinator.syncForAuthenticatedUser(
                    userID: authViewModel.currentUser?.uid,
                    modelContext: modelContext
                )
            }
        }
        .task(id: authViewModel.currentUser?.uid) {
            guard authViewModel.currentUser != nil else { return }
            await verseListSyncCoordinator.syncForAuthenticatedUser(
                userID: authViewModel.currentUser?.uid,
                modelContext: modelContext
            )
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
        VStack(alignment: .leading, spacing: 8) {
            Text("나만의 구절 리스트")
                .font(.title3.bold())
            Text("자주 읽고 싶거나 나중에 필사하고 싶은 구절을 직접 모아둘 수 있습니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func listCard(_ list: MyVerseList) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.green.opacity(0.14))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "bookmark.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(list.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if !list.memo.isEmpty {
                    Text(list.memo)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text("\(itemCount(for: list))개 구절")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }

            Spacer()

            VStack(spacing: 10) {
                Button {
                    deletingList = list
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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func itemCount(for list: MyVerseList) -> Int {
        currentUserItems.filter { $0.listId == list.id }.count
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
