import FirebaseAuth
import SwiftData
import SwiftUI

struct MyVerseListDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var verseListSyncCoordinator: VerseListSyncCoordinator

    let list: MyVerseList

    @Query(sort: \MyVerseListItem.createdAt, order: .forward) private var allItems: [MyVerseListItem]
    @State private var showingVersePicker = false
    @State private var showingEditSheet = false
    @State private var isManagingVerses = false
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var deletingItem: MyVerseListItem?
    @State private var deletingSection: ListVerseSection?
    @State private var deletingSelectedItems = false
    @State private var deletingList = false
    @State private var expandedSectionKeys: Set<String> = []
    @State private var isLoadingRemoteItems = false
    @State private var pendingDeletedItemIDs: Set<UUID> = []
    @State private var pendingDeleteEntireList = false
    @State private var isApplyingPendingChanges = false
    @State private var showingDiscardChangesAlert = false

    private let service = BibleDataService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard
                if isManagingVerses {
                    manageModeCard
                }

                Button {
                    showingVersePicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text("구절 추가")
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
                .disabled(isManagingVerses)
                .opacity(isManagingVerses ? 0.55 : 1)

                if isLoadingRemoteItems && listItems.isEmpty {
                    ProgressView("구절을 불러오는 중...")
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                } else if listItems.isEmpty {
                    ContentUnavailableView(
                        "아직 저장된 구절이 없습니다.",
                        systemImage: "bookmark",
                        description: Text("구절 추가 버튼을 눌러 리스트를 채워보세요.")
                    )
                    .padding(.top, 32)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(displaySections) { section in
                            if section.items.count == 1, let item = section.items.first, let verse = section.verses.first {
                                verseNavigationLink(item: item, verse: verse)
                            } else {
                                chapterFolderCard(section: section)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(list.title)
        .navigationBarBackButtonHidden(true)
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    handleBackNavigation()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("뒤로")
                    }
                }
                .disabled(isApplyingPendingChanges)
            }

            ToolbarItem(placement: .topBarTrailing) {
                if isManagingVerses {
                    Button("완료") {
                        applyManageChanges()
                    }
                    .disabled(isApplyingPendingChanges)
                } else {
                    Button("구절 편집") {
                        isManagingVerses = true
                    }

                    Button {
                        showingEditSheet = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }

                    Button(role: .destructive) {
                        deletingList = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
        }
        .sheet(isPresented: $showingVersePicker) {
            NavigationStack {
                BibleSelectView { verses in
                    addVersesToList(verses)
                    showingVersePicker = false
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                CreateMyVerseListView(list: list)
            }
        }
        .alert("구절을 삭제할까요?", isPresented: deleteItemAlertBinding) {
            Button("취소", role: .cancel) {
                deletingItem = nil
            }
            Button("삭제", role: .destructive) {
                confirmDeleteItem()
            }
        } message: {
            Text("리스트에서만 제거됩니다.")
        }
        .alert("선택한 구절을 삭제할까요?", isPresented: $deletingSelectedItems) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                deleteSelectedItems()
            }
        } message: {
            Text("선택한 구절이 리스트에서 제거됩니다.")
        }
        .alert("이 폴더를 삭제할까요?", isPresented: deleteSectionAlertBinding) {
            Button("취소", role: .cancel) {
                deletingSection = nil
            }
            Button("삭제", role: .destructive) {
                deleteSection()
            }
        } message: {
            Text("이 장에 묶인 구절이 리스트에서 한 번에 제거됩니다.")
        }
        .alert(isManagingVerses ? "리스트 안의 모든 구절을 삭제할까요?" : "리스트를 삭제할까요?", isPresented: $deletingList) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                deleteList()
            }
        } message: {
            Text(isManagingVerses ? "리스트 자체는 유지되고, 안에 있는 구절만 모두 삭제됩니다." : "리스트와 그 안의 구절이 함께 삭제됩니다.")
        }
        .alert("변경 사항이 적용되지 않았습니다", isPresented: $showingDiscardChangesAlert) {
            Button("취소", role: .cancel) {}
            Button("나가기", role: .destructive) {
                discardPendingChangesAndDismiss()
            }
        } message: {
            Text("완료 버튼을 누르지 않으면 삭제 예정 변경 사항은 적용되지 않습니다.")
        }
        .safeAreaInset(edge: .bottom) {
            if isManagingVerses && !listItems.isEmpty {
                manageBottomBar
            }
        }
        .task(id: list.remoteDocumentId) {
            await fetchRemoteItemsIfNeeded()
        }
    }

    private var listItems: [MyVerseListItem] {
        allItems
            .items(for: authViewModel.currentUser?.uid)
            .filter { $0.listId == list.id }
    }

    private var hasPendingManageChanges: Bool {
        pendingDeleteEntireList || !pendingDeletedItemIDs.isEmpty
    }

    private func isPendingDeletion(_ item: MyVerseListItem) -> Bool {
        pendingDeleteEntireList || pendingDeletedItemIDs.contains(item.id)
    }

    private var displaySections: [ListVerseSection] {
        let grouped = Dictionary(grouping: listItems) { item in
            ListVerseSectionKey(book: item.book, chapter: item.chapter)
        }

        return grouped
            .map { key, items in
                let sortedItems = items.sorted { $0.verse < $1.verse }
                let verses = sortedItems.compactMap {
                    service.getVerse(book: $0.book, chapter: $0.chapter, verse: $0.verse)
                }

                return ListVerseSection(
                    key: key,
                    items: sortedItems,
                    verses: verses,
                    totalChapterVerseCount: service.getVerses(book: key.book, chapter: key.chapter).count,
                    createdAt: sortedItems.map(\.createdAt).min() ?? .distantPast
                )
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(list.title)
                .font(.title3.bold())
            if !list.memo.isEmpty {
                Text(list.memo)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("\(listItems.count)개 구절")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
            if displaySections.contains(where: { $0.items.count > 1 }) {
                Text("같은 장의 구절은 폴더처럼 접어서 볼 수 있습니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var manageModeCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checklist")
                .font(.title3)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("구절 편집 중")
                    .font(.headline)
                Text(hasPendingManageChanges
                     ? "삭제 예정 항목이 표시되고 있습니다. 완료를 누르면 실제로 반영됩니다."
                     : "빼고 싶은 구절을 선택한 뒤 아래 삭제 버튼을 누르세요. 완료를 누르면 실제로 반영됩니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func verseNavigationLink(item: MyVerseListItem, verse: LocalBibleVerse) -> some View {
        Group {
            if isManagingVerses {
                Button {
                    toggleItemSelection(item.id)
                } label: {
                    itemCard(
                        verse: verse,
                        isSelectable: true,
                        isSelected: selectedItemIDs.contains(item.id),
                        isPendingDeletion: isPendingDeletion(item)
                    )
                }
                .buttonStyle(.plain)
            } else {
                NavigationLink {
                    WriteView(localVerse: verse, sourceType: .customList)
                } label: {
                    itemCard(
                        verse: verse,
                        isSelectable: false,
                        isSelected: false,
                        isPendingDeletion: false
                    )
                }
                .buttonStyle(PressableCardStyle())
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isManagingVerses {
                Button(role: .destructive) {
                    deletingItem = item
                } label: {
                    Label("삭제", systemImage: "trash")
                }
            }
        }
        .contextMenu {
            if !isManagingVerses {
                Button(role: .destructive) {
                    deletingItem = item
                } label: {
                    Label("구절 삭제", systemImage: "trash")
                }
            }
        }
    }

    private func itemCard(
        verse: LocalBibleVerse,
        isSelectable: Bool,
        isSelected: Bool,
        isPendingDeletion: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(iconBackgroundColor(isSelected: isSelected, isPendingDeletion: isPendingDeletion))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: iconName(isSelectable: isSelectable, isSelected: isSelected, isPendingDeletion: isPendingDeletion))
                        .foregroundStyle(iconForegroundColor(isPendingDeletion: isPendingDeletion))
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("\(verse.book) \(verse.chapter):\(verse.verse)")
                        .font(.headline)
                        .foregroundColor(isPendingDeletion ? .secondary : .primary)
                        .strikethrough(isPendingDeletion, color: .red.opacity(0.7))
                    if isPendingDeletion {
                        Text("삭제 예정")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }
                Text(versePreview(for: verse.text))
                    .font(.subheadline)
                    .foregroundColor(isPendingDeletion ? Color.secondary.opacity(0.75) : Color.secondary)
                    .lineLimit(2)
                    .strikethrough(isPendingDeletion, color: .red.opacity(0.6))
            }

            Spacer()

            Image(systemName: trailingIconName(isSelectable: isSelectable, isSelected: isSelected, isPendingDeletion: isPendingDeletion))
                .font(.subheadline.weight(.semibold))
                .foregroundColor(trailingIconColor(isSelected: isSelected, isPendingDeletion: isPendingDeletion))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(cardBackgroundColor(isPendingDeletion: isPendingDeletion))
        .overlay {
            if isPendingDeletion || isSelected {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(borderColor(isSelected: isSelected, isPendingDeletion: isPendingDeletion), lineWidth: 1.5)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(isPendingDeletion ? 0.78 : 1)
    }

    private func chapterFolderCard(section: ListVerseSection) -> some View {
        VStack(spacing: 0) {
            Button {
                toggleSection(section.key.id)
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: isExpanded(section.key.id) ? "folder.fill" : "folder")
                                .foregroundStyle(.green)
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(section.key.book) \(section.key.chapter)장")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text(folderSubtitle(for: section))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(isExpanded(section.key.id) ? "접기" : "펼쳐서 보기")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.green)
                        if section.items.allSatisfy({ isPendingDeletion($0) }) {
                            Text("이 폴더의 구절이 모두 삭제 예정입니다.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded(section.key.id) ? "chevron.down" : "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            }
            .buttonStyle(.plain)

            if isManagingVerses {
                HStack(spacing: 10) {
                    Button(allItemsSelected(in: section) ? "이 장 선택 해제" : "이 장 모두 선택") {
                        toggleSectionSelection(section)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .buttonStyle(.plain)

                    Button("이 폴더 삭제", role: .destructive) {
                        deletingSection = section
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
            }

            if isExpanded(section.key.id) {
                Divider()
                    .padding(.horizontal, 18)

                VStack(spacing: 10) {
                    ForEach(Array(zip(section.items, section.verses)), id: \.0.id) { pair in
                        verseNavigationLink(item: pair.0, verse: pair.1)
                    }
                }
                .padding([.horizontal, .bottom], 14)
                .padding(.top, 12)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var manageBottomBar: some View {
        VStack(spacing: 12) {
            Divider()

            HStack(spacing: 12) {
                Button(role: .destructive) {
                    deletingSelectedItems = true
                } label: {
                    Text(selectedItemIDs.isEmpty ? "선택한 구절 삭제" : "\(selectedItemIDs.count)개 구절 삭제 예약")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selectedItemIDs.isEmpty ? Color.gray : Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(selectedItemIDs.isEmpty)

                Button(role: .destructive) {
                    deletingList = true
                } label: {
                    Text("리스트 안 구절 전체 삭제")
                        .font(.headline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
        .background(.ultraThinMaterial)
    }

    private func versePreview(for text: String) -> String {
        if text.count <= 68 {
            return text
        }
        return String(text.prefix(68)) + "..."
    }

    private func iconBackgroundColor(isSelected: Bool, isPendingDeletion: Bool) -> Color {
        if isPendingDeletion { return Color.red.opacity(0.12) }
        return isSelected ? Color.green.opacity(0.18) : Color.green.opacity(0.12)
    }

    private func iconName(isSelectable: Bool, isSelected: Bool, isPendingDeletion: Bool) -> String {
        if isPendingDeletion { return "minus.circle.fill" }
        return isSelectable ? (isSelected ? "checkmark.circle.fill" : "circle") : "bookmark.fill"
    }

    private func iconForegroundColor(isPendingDeletion: Bool) -> Color {
        isPendingDeletion ? .red : .green
    }

    private func trailingIconName(isSelectable: Bool, isSelected: Bool, isPendingDeletion: Bool) -> String {
        if isPendingDeletion { return "clock.arrow.trianglehead.counterclockwise.rotate.90" }
        return isSelectable ? (isSelected ? "checkmark.circle.fill" : "circle") : "chevron.right"
    }

    private func trailingIconColor(isSelected: Bool, isPendingDeletion: Bool) -> Color {
        if isPendingDeletion { return .red }
        return isSelected ? .green : .secondary
    }

    private func cardBackgroundColor(isPendingDeletion: Bool) -> Color {
        isPendingDeletion ? Color.red.opacity(0.06) : Color(.secondarySystemBackground)
    }

    private func borderColor(isSelected: Bool, isPendingDeletion: Bool) -> Color {
        if isPendingDeletion { return Color.red.opacity(0.35) }
        return isSelected ? Color.green.opacity(0.45) : .clear
    }

    private func addVersesToList(_ verses: [LocalBibleVerse]) {
        var expandedKeysToOpen = Set<String>()

        for verse in verses {
            let alreadyExists = listItems.contains {
                $0.book == verse.book && $0.chapter == verse.chapter && $0.verse == verse.verse
            }
            guard !alreadyExists else { continue }

            let item = MyVerseListItem(
                listId: list.id,
                book: verse.book,
                chapter: verse.chapter,
                verse: verse.verse,
                ownerUserId: list.ownerUserId,
                updatedAt: Date()
            )

            modelContext.insert(item)
            expandedKeysToOpen.insert(ListVerseSectionKey(book: verse.book, chapter: verse.chapter).id)
        }
        try? modelContext.save()
        expandedSectionKeys.formUnion(expandedKeysToOpen)

        if authViewModel.currentUser != nil {
            Task {
                await verseListSyncCoordinator.uploadItemsIfNeeded(
                    for: list.id,
                    userID: authViewModel.currentUser?.uid,
                    modelContext: modelContext
                )
            }
        }
    }

    private func fetchRemoteItemsIfNeeded() async {
        guard authViewModel.currentUser != nil, list.remoteDocumentId != nil else { return }

        isLoadingRemoteItems = true
        await verseListSyncCoordinator.syncItemsForList(
            listID: list.id,
            userID: authViewModel.currentUser?.uid,
            modelContext: modelContext
        )
        isLoadingRemoteItems = false
    }

    private var deleteItemAlertBinding: Binding<Bool> {
        Binding(
            get: { deletingItem != nil },
            set: { isPresented in
                if !isPresented {
                    deletingItem = nil
                }
            }
        )
    }

    private func confirmDeleteItem() {
        guard let item = deletingItem else { return }
        deletingItem = nil

        Task {
            await verseListSyncCoordinator.deleteItemIfNeeded(
                localItemID: item.id,
                userID: authViewModel.currentUser?.uid,
                modelContext: modelContext
            )
        }
    }

    private func deleteList() {
        let listID = list.id
        if isManagingVerses {
            pendingDeleteEntireList = true
            pendingDeletedItemIDs = Set(
                allItems
                    .items(for: authViewModel.currentUser?.uid)
                    .filter { $0.listId == listID }
                    .map(\.id)
            )
            selectedItemIDs.removeAll()
            deletingList = false
            return
        }

        Task {
            await verseListSyncCoordinator.deleteListIfNeeded(
                localListID: listID,
                userID: authViewModel.currentUser?.uid,
                modelContext: modelContext
            )
            dismiss()
        }
    }

    private func deleteSelectedItems() {
        let itemsToDelete = listItems.filter { selectedItemIDs.contains($0.id) }
        pendingDeletedItemIDs.formUnion(itemsToDelete.map(\.id))
        selectedItemIDs.removeAll()
        deletingSelectedItems = false
    }

    private var deleteSectionAlertBinding: Binding<Bool> {
        Binding(
            get: { deletingSection != nil },
            set: { isPresented in
                if !isPresented {
                    deletingSection = nil
                }
            }
        )
    }

    private func deleteSection() {
        guard let section = deletingSection else { return }
        pendingDeletedItemIDs.formUnion(section.items.map(\.id))
        for item in section.items {
            selectedItemIDs.remove(item.id)
        }
        expandedSectionKeys.remove(section.key.id)
        deletingSection = nil
    }

    private func applyManageChanges() {
        if !hasPendingManageChanges {
            isManagingVerses = false
            selectedItemIDs.removeAll()
            return
        }

        isApplyingPendingChanges = true
        let pendingItemIDs = pendingDeletedItemIDs
        let shouldDeleteList = pendingDeleteEntireList
        let listID = list.id

        Task {
            if shouldDeleteList {
                let itemIDs = allItems
                    .items(for: authViewModel.currentUser?.uid)
                    .filter { $0.listId == listID }
                    .map(\.id)

                for itemID in itemIDs {
                    await verseListSyncCoordinator.deleteItemIfNeeded(
                        localItemID: itemID,
                        userID: authViewModel.currentUser?.uid,
                        modelContext: modelContext
                    )
                }
                await MainActor.run {
                    isApplyingPendingChanges = false
                    pendingDeletedItemIDs.removeAll()
                    pendingDeleteEntireList = false
                    selectedItemIDs.removeAll()
                    isManagingVerses = false
                }
                return
            }

            for itemID in pendingItemIDs {
                await verseListSyncCoordinator.deleteItemIfNeeded(
                    localItemID: itemID,
                    userID: authViewModel.currentUser?.uid,
                    modelContext: modelContext
                )
            }

            await MainActor.run {
                pendingDeletedItemIDs.removeAll()
                pendingDeleteEntireList = false
                selectedItemIDs.removeAll()
                isApplyingPendingChanges = false
                isManagingVerses = false
            }
        }
    }

    private func handleBackNavigation() {
        if isManagingVerses || hasPendingManageChanges {
            showingDiscardChangesAlert = true
        } else {
            dismiss()
        }
    }

    private func discardPendingChangesAndDismiss() {
        pendingDeletedItemIDs.removeAll()
        pendingDeleteEntireList = false
        selectedItemIDs.removeAll()
        deletingItem = nil
        deletingSection = nil
        deletingSelectedItems = false
        deletingList = false
        isManagingVerses = false
        dismiss()
    }

    private func folderSubtitle(for section: ListVerseSection) -> String {
        if section.items.count == section.totalChapterVerseCount {
            return "\(section.items.count)개 구절 · 이 장 전체"
        }

        let rangeText: String
        if let first = section.items.first?.verse, let last = section.items.last?.verse {
            rangeText = first == last ? "\(first)절" : "\(first)절-\(last)절"
        } else {
            rangeText = "여러 절"
        }

        return "\(section.items.count)개 구절 · \(rangeText)"
    }

    private func isExpanded(_ key: String) -> Bool {
        expandedSectionKeys.contains(key)
    }

    private func toggleSection(_ key: String) {
        if expandedSectionKeys.contains(key) {
            expandedSectionKeys.remove(key)
        } else {
            expandedSectionKeys.insert(key)
        }
    }

    private func toggleItemSelection(_ id: UUID) {
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }

    private func allItemsSelected(in section: ListVerseSection) -> Bool {
        !section.items.isEmpty && section.items.allSatisfy { selectedItemIDs.contains($0.id) }
    }

    private func toggleSectionSelection(_ section: ListVerseSection) {
        let ids = Set(section.items.map(\.id))
        if allItemsSelected(in: section) {
            selectedItemIDs.subtract(ids)
        } else {
            selectedItemIDs.formUnion(ids)
            expandedSectionKeys.insert(section.key.id)
        }
    }
}

private struct ListVerseSection: Identifiable {
    let key: ListVerseSectionKey
    let items: [MyVerseListItem]
    let verses: [LocalBibleVerse]
    let totalChapterVerseCount: Int
    let createdAt: Date

    var id: String { key.id }
}

private struct ListVerseSectionKey: Hashable {
    let book: String
    let chapter: Int

    var id: String { "\(book)-\(chapter)" }
}
