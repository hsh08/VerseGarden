import Combine
import FirebaseAuth
import SwiftData
import SwiftUI

@MainActor
final class VerseListSyncCoordinator: ObservableObject {
    @Published private(set) var isSyncing = false

    private let service = FirestoreVerseListService()
    private let bibleService = BibleDataService.shared
    private var activeUserId: String?
    private var syncingUserId: String?
    private var inFlightListUploads = Set<UUID>()
    private var inFlightItemUploads = Set<UUID>()

    func syncForAuthenticatedUser(userID: String?, modelContext: ModelContext) async {
        guard let userID, !userID.isEmpty else {
            return
        }

        guard let userID = validatedCurrentUserID(for: userID) else {
            stopSync()
            return
        }

        guard syncingUserId != userID else { return }

        activeUserId = userID
        syncingUserId = userID
        isSyncing = true
        defer {
            syncingUserId = nil
            isSyncing = false
        }

        do {
            let remoteLists = try await service.fetchLists(for: userID)
            try reconcile(remoteLists: remoteLists, userID: userID, modelContext: modelContext)
            try await uploadPendingLists(for: userID, modelContext: modelContext)
            try await reconcileItemsForSyncedLists(for: userID, modelContext: modelContext)
            try await uploadPendingItems(for: userID, modelContext: modelContext)
        } catch {}
    }

    func uploadListIfNeeded(localListID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }
        guard activeUserId == userID else { return }

        do {
            guard let list = try fetchAllLists(modelContext: modelContext).first(where: { $0.id == localListID }) else {
                return
            }
            guard list.ownerUserId == userID, list.remoteDocumentId == nil else { return }
            try await upload(list: list, userID: userID, modelContext: modelContext)
        } catch {}
    }

    func uploadItemsIfNeeded(for listID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }
        guard activeUserId == userID else { return }

        do {
            guard let list = try fetchAllLists(modelContext: modelContext).first(where: { $0.id == listID }) else {
                return
            }
            guard list.ownerUserId == userID else { return }

            if list.remoteDocumentId == nil {
                try await upload(list: list, userID: userID, modelContext: modelContext)
            }

            try await uploadPendingItems(for: userID, listID: listID, modelContext: modelContext)
        } catch {}
    }

    func updateListIfNeeded(localListID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }
        guard activeUserId == userID else { return }

        do {
            guard let list = try fetchAllLists(modelContext: modelContext).first(where: { $0.id == localListID }) else {
                return
            }
            guard list.ownerUserId == userID, let remoteDocumentId = list.remoteDocumentId, !remoteDocumentId.isEmpty else { return }

            try await service.updateList(
                listRemoteId: remoteDocumentId,
                title: list.title,
                memo: list.memo,
                for: userID
            )
            list.lastSyncedAt = Date()
            try modelContext.save()
        } catch {}
    }

    func deleteListIfNeeded(localListID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }

        do {
            guard let list = try fetchAllLists(modelContext: modelContext).first(where: { $0.id == localListID }) else {
                return
            }
            guard list.ownerUserId == userID else { return }

            let resolvedRemoteDocumentId = try await resolveRemoteDocumentIdIfNeeded(for: list, userID: userID, modelContext: modelContext)

            if let resolvedRemoteDocumentId, !resolvedRemoteDocumentId.isEmpty {
                try await service.deleteList(listRemoteId: resolvedRemoteDocumentId, for: userID)
            }

            let items = try fetchAllItems(modelContext: modelContext).filter { $0.listId == list.id }
            for item in items {
                modelContext.delete(item)
            }
            modelContext.delete(list)
            try modelContext.save()
        } catch {}
    }

    func deleteItemIfNeeded(localItemID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }

        do {
            guard let item = try fetchAllItems(modelContext: modelContext).first(where: { $0.id == localItemID }) else {
                return
            }
            guard item.ownerUserId == userID else { return }
            guard let list = try fetchAllLists(modelContext: modelContext).first(where: { $0.id == item.listId }) else {
                return
            }
            guard list.ownerUserId == userID else { return }

            let listRemoteDocumentId = try await resolveRemoteDocumentIdIfNeeded(for: list, userID: userID, modelContext: modelContext)
            let itemRemoteDocumentId = item.remoteDocumentId

            if let listRemoteDocumentId,
               let itemRemoteDocumentId,
               !listRemoteDocumentId.isEmpty,
               !itemRemoteDocumentId.isEmpty {
                try await service.deleteItem(listId: listRemoteDocumentId, itemId: itemRemoteDocumentId, for: userID)
            }

            modelContext.delete(item)
            try modelContext.save()
        } catch {}
    }

    func syncItemsForList(listID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }
        guard activeUserId == userID else { return }

        do {
            guard let list = try fetchAllLists(modelContext: modelContext).first(where: { $0.id == listID }) else {
                return
            }
            guard list.ownerUserId == userID, let remoteDocumentId = list.remoteDocumentId else { return }

            let remoteItems = try await service.fetchItems(
                userId: userID,
                listRemoteId: remoteDocumentId,
                localListId: list.id
            )
            try reconcileItems(
                remoteItems: remoteItems,
                list: list,
                userID: userID,
                modelContext: modelContext
            )
            try await uploadPendingItems(for: userID, listID: list.id, modelContext: modelContext)
        } catch {}
    }

    func stopSync() {
        activeUserId = nil
        syncingUserId = nil
        isSyncing = false
        inFlightListUploads.removeAll()
        inFlightItemUploads.removeAll()
    }

    private func validatedCurrentUserID(for userID: String?) -> String? {
        guard let currentUID = Auth.auth().currentUser?.uid,
              let userID,
              !userID.isEmpty,
              currentUID == userID else {
            return nil
        }

        return userID
    }

    private func reconcile(
        remoteLists: [MyVerseList],
        userID: String,
        modelContext: ModelContext
    ) throws {
        let localLists = try fetchAllLists(modelContext: modelContext).filter { list in
            list.ownerUserId == userID || list.ownerUserId.isEmpty
        }

        var localListsByRemoteDocumentId: [String: MyVerseList] = [:]
        var localListsByLocalId: [UUID: MyVerseList] = [:]
        var localListsByDuplicateKey: [String: MyVerseList] = [:]

        for list in localLists {
            if let remoteDocumentId = list.remoteDocumentId {
                localListsByRemoteDocumentId[remoteDocumentId] = list
            }
            localListsByLocalId[list.id] = list
            localListsByDuplicateKey[listDuplicateKey(for: list, userID: list.ownerUserId.isEmpty ? userID : list.ownerUserId)] = list
        }

        var didChange = false

        for remoteList in remoteLists {
            guard let remoteListDocumentId = remoteList.remoteDocumentId else { continue }

            if let existing = localListsByRemoteDocumentId[remoteListDocumentId] {
                didChange = merge(remote: remoteList, into: existing, userID: userID) || didChange
            } else if let existing = localListsByLocalId[remoteList.id] {
                if existing.remoteDocumentId == nil {
                    existing.remoteDocumentId = remoteListDocumentId
                    existing.lastSyncedAt = Date()
                    if existing.ownerUserId.isEmpty {
                        existing.ownerUserId = userID
                    }
                    didChange = true
                }
                didChange = merge(remote: remoteList, into: existing, userID: userID) || didChange
            } else {
                let remoteKey = listDuplicateKey(for: remoteList, userID: userID)
                if let existing = localListsByDuplicateKey[remoteKey] {
                    if existing.remoteDocumentId == nil {
                        existing.remoteDocumentId = remoteListDocumentId
                        existing.lastSyncedAt = Date()
                        if existing.ownerUserId.isEmpty {
                            existing.ownerUserId = userID
                        }
                        didChange = true
                    }
                    didChange = merge(remote: remoteList, into: existing, userID: userID) || didChange
                } else {
                    let newList = MyVerseList(
                        id: remoteList.id,
                        title: remoteList.title,
                        memo: remoteList.memo,
                        ownerUserId: userID,
                        remoteDocumentId: remoteListDocumentId,
                        updatedAt: remoteList.updatedAt,
                        lastSyncedAt: Date(),
                        createdAt: remoteList.createdAt
                    )
                    modelContext.insert(newList)
                    localListsByRemoteDocumentId[remoteListDocumentId] = newList
                    localListsByLocalId[newList.id] = newList
                    localListsByDuplicateKey[listDuplicateKey(for: newList, userID: userID)] = newList
                    didChange = true
                }
            }
        }

        let remoteDocumentIds = Set(remoteLists.compactMap(\.remoteDocumentId))
        let orphanedLists = localLists.filter {
            guard let remoteDocumentId = $0.remoteDocumentId, !remoteDocumentId.isEmpty else { return false }
            return !remoteDocumentIds.contains(remoteDocumentId)
        }

        for orphanedList in orphanedLists {
            let orphanedItems = try fetchAllItems(modelContext: modelContext).filter { $0.listId == orphanedList.id }
            for orphanedItem in orphanedItems {
                modelContext.delete(orphanedItem)
            }
            modelContext.delete(orphanedList)
            didChange = true
        }

        if didChange {
            try modelContext.save()
        }
    }

    private func reconcileItems(
        remoteItems: [MyVerseListItem],
        list: MyVerseList,
        userID: String,
        modelContext: ModelContext
    ) throws {
        let localItems = try fetchAllItems(modelContext: modelContext).filter { item in
            (item.ownerUserId == userID || item.ownerUserId.isEmpty) && item.listId == list.id
        }

        var localItemsByRemoteDocumentId: [String: MyVerseListItem] = [:]
        var localItemsByDuplicateKey: [String: MyVerseListItem] = [:]

        for item in localItems {
            if let remoteDocumentId = item.remoteDocumentId {
                localItemsByRemoteDocumentId[remoteDocumentId] = item
            }
            localItemsByDuplicateKey[itemDuplicateKey(for: item, userID: userID)] = item
        }

        var didChange = false

        for remoteItem in remoteItems {
            let normalizedRemoteItem = MyVerseListItem(
                id: remoteItem.id,
                listId: list.id,
                book: remoteItem.book,
                chapter: remoteItem.chapter,
                verse: remoteItem.verse,
                ownerUserId: userID,
                remoteDocumentId: remoteItem.remoteDocumentId,
                updatedAt: remoteItem.updatedAt,
                lastSyncedAt: remoteItem.lastSyncedAt,
                createdAt: remoteItem.createdAt
            )

            guard let remoteItemDocumentId = normalizedRemoteItem.remoteDocumentId else { continue }

            if let existing = localItemsByRemoteDocumentId[remoteItemDocumentId] {
                didChange = merge(remote: normalizedRemoteItem, into: existing, listId: list.id, userID: userID) || didChange
                continue
            }

            let remoteKey = itemDuplicateKey(for: normalizedRemoteItem, userID: userID)
            if let existing = localItemsByDuplicateKey[remoteKey] {
                if existing.remoteDocumentId == nil {
                    existing.remoteDocumentId = remoteItemDocumentId
                    existing.lastSyncedAt = Date()
                    if existing.ownerUserId.isEmpty {
                        existing.ownerUserId = userID
                    }
                    existing.listId = list.id
                    didChange = true
                }
                didChange = merge(remote: normalizedRemoteItem, into: existing, listId: list.id, userID: userID) || didChange
                localItemsByRemoteDocumentId[remoteItemDocumentId] = existing
                continue
            }

            let newItem = MyVerseListItem(
                id: normalizedRemoteItem.id,
                listId: list.id,
                book: normalizedRemoteItem.book,
                chapter: normalizedRemoteItem.chapter,
                verse: normalizedRemoteItem.verse,
                ownerUserId: userID,
                remoteDocumentId: remoteItemDocumentId,
                updatedAt: normalizedRemoteItem.updatedAt,
                lastSyncedAt: Date(),
                createdAt: normalizedRemoteItem.createdAt
            )
            modelContext.insert(newItem)
            localItemsByRemoteDocumentId[remoteItemDocumentId] = newItem
            localItemsByDuplicateKey[remoteKey] = newItem
            didChange = true
        }

        let remoteItemDocumentIds = Set(remoteItems.compactMap(\.remoteDocumentId))
        let orphanedItems = localItems.filter {
            guard let remoteDocumentId = $0.remoteDocumentId, !remoteDocumentId.isEmpty else { return false }
            return !remoteItemDocumentIds.contains(remoteDocumentId)
        }

        for orphanedItem in orphanedItems {
            modelContext.delete(orphanedItem)
            didChange = true
        }

        if didChange {
            try modelContext.save()
        }
    }

    private func merge(remote: MyVerseList, into local: MyVerseList, userID: String) -> Bool {
        var didChange = false

        if local.ownerUserId.isEmpty {
            local.ownerUserId = userID
            didChange = true
        }

        if remote.updatedAt > local.updatedAt {
            if local.title != remote.title {
                local.title = remote.title
                didChange = true
            }
            if local.memo != remote.memo {
                local.memo = remote.memo
                didChange = true
            }
            if local.createdAt != remote.createdAt {
                local.createdAt = remote.createdAt
                didChange = true
            }
            if local.updatedAt != remote.updatedAt {
                local.updatedAt = remote.updatedAt
                didChange = true
            }
        }

        if local.lastSyncedAt == nil {
            local.lastSyncedAt = Date()
            didChange = true
        }

        return didChange
    }

    private func merge(remote: MyVerseListItem, into local: MyVerseListItem, listId: UUID, userID: String) -> Bool {
        var didChange = false

        if local.ownerUserId.isEmpty {
            local.ownerUserId = userID
            didChange = true
        }
        if local.listId != listId {
            local.listId = listId
            didChange = true
        }

        if remote.updatedAt > local.updatedAt {
            if local.book != remote.book {
                local.book = remote.book
                didChange = true
            }
            if local.chapter != remote.chapter {
                local.chapter = remote.chapter
                didChange = true
            }
            if local.verse != remote.verse {
                local.verse = remote.verse
                didChange = true
            }
            if local.createdAt != remote.createdAt {
                local.createdAt = remote.createdAt
                didChange = true
            }
            if local.updatedAt != remote.updatedAt {
                local.updatedAt = remote.updatedAt
                didChange = true
            }
        }

        if local.lastSyncedAt == nil {
            local.lastSyncedAt = Date()
            didChange = true
        }

        return didChange
    }

    private func uploadPendingLists(for userID: String, modelContext: ModelContext) async throws {
        let pendingLists = try fetchAllLists(modelContext: modelContext).filter {
            $0.ownerUserId == userID && $0.remoteDocumentId == nil && !inFlightListUploads.contains($0.id)
        }

        for list in pendingLists {
            try await upload(list: list, userID: userID, modelContext: modelContext)
        }
    }

    private func reconcileItemsForSyncedLists(for userID: String, modelContext: ModelContext) async throws {
        let syncedLists = try fetchAllLists(modelContext: modelContext).filter {
            $0.ownerUserId == userID && ($0.remoteDocumentId?.isEmpty == false)
        }

        for list in syncedLists {
            guard let remoteDocumentId = list.remoteDocumentId, !remoteDocumentId.isEmpty else { continue }
            let remoteItems = try await service.fetchItems(
                userId: userID,
                listRemoteId: remoteDocumentId,
                localListId: list.id
            )
            try reconcileItems(
                remoteItems: remoteItems,
                list: list,
                userID: userID,
                modelContext: modelContext
            )
        }
    }

    private func uploadPendingItems(for userID: String, modelContext: ModelContext) async throws {
        let lists = try fetchAllLists(modelContext: modelContext).filter { $0.ownerUserId == userID }
        for list in lists {
            try await uploadPendingItems(for: userID, listID: list.id, modelContext: modelContext)
        }
    }

    private func uploadPendingItems(for userID: String, listID: UUID, modelContext: ModelContext) async throws {
        guard let list = try fetchAllLists(modelContext: modelContext).first(where: { $0.id == listID }) else { return }
        guard list.ownerUserId == userID else { return }

        if list.remoteDocumentId == nil {
            try await upload(list: list, userID: userID, modelContext: modelContext)
        }

        guard let remoteListDocumentId = list.remoteDocumentId else { return }

        let pendingItems = try fetchAllItems(modelContext: modelContext).filter {
            $0.ownerUserId == userID && $0.listId == listID && $0.remoteDocumentId == nil && !inFlightItemUploads.contains($0.id)
        }

        var uploadedKeys = Set<String>()

        for item in pendingItems {
            let key = itemDuplicateKey(for: item, userID: userID)
            guard !uploadedKeys.contains(key) else { continue }
            try await upload(item: item, userID: userID, remoteListDocumentId: remoteListDocumentId, modelContext: modelContext)
            uploadedKeys.insert(key)
        }
    }

    private func upload(list: MyVerseList, userID: String, modelContext: ModelContext) async throws {
        guard list.remoteDocumentId == nil else { return }
        guard !inFlightListUploads.contains(list.id) else { return }

        inFlightListUploads.insert(list.id)
        defer {
            inFlightListUploads.remove(list.id)
        }

        let remoteDocumentId = try await service.createList(from: list, for: userID)
        list.remoteDocumentId = remoteDocumentId
        list.lastSyncedAt = Date()
        try modelContext.save()
    }

    private func upload(item: MyVerseListItem, userID: String, remoteListDocumentId: String, modelContext: ModelContext) async throws {
        guard item.remoteDocumentId == nil else { return }
        guard !inFlightItemUploads.contains(item.id) else { return }

        inFlightItemUploads.insert(item.id)
        defer {
            inFlightItemUploads.remove(item.id)
        }

        let verseText = bibleService.getVerse(book: item.book, chapter: item.chapter, verse: item.verse)?.text
        let remoteDocumentId = try await service.createItem(
            from: item,
            for: userID,
            listRemoteDocumentId: remoteListDocumentId,
            verseText: verseText
        )
        item.remoteDocumentId = remoteDocumentId
        item.lastSyncedAt = Date()
        try modelContext.save()
    }

    private func fetchAllLists(modelContext: ModelContext) throws -> [MyVerseList] {
        try modelContext.fetch(FetchDescriptor<MyVerseList>())
    }

    private func fetchAllItems(modelContext: ModelContext) throws -> [MyVerseListItem] {
        try modelContext.fetch(FetchDescriptor<MyVerseListItem>())
    }

    private func resolveRemoteDocumentIdIfNeeded(
        for list: MyVerseList,
        userID: String,
        modelContext: ModelContext
    ) async throws -> String? {
        if let remoteDocumentId = list.remoteDocumentId, !remoteDocumentId.isEmpty {
            return remoteDocumentId
        }

        let remoteLists = try await service.fetchLists(for: userID)

        if let matchedByLocalId = remoteLists.first(where: { $0.id == list.id }),
           let remoteDocumentId = matchedByLocalId.remoteDocumentId {
            list.remoteDocumentId = remoteDocumentId
            list.lastSyncedAt = Date()
            try modelContext.save()
            return remoteDocumentId
        }

        let localDuplicateKey = listDuplicateKey(for: list, userID: userID)
        if let matchedByDuplicateKey = remoteLists.first(where: {
            listDuplicateKey(for: $0, userID: userID) == localDuplicateKey
        }), let remoteDocumentId = matchedByDuplicateKey.remoteDocumentId {
            list.remoteDocumentId = remoteDocumentId
            list.lastSyncedAt = Date()
            try modelContext.save()
            return remoteDocumentId
        }

        return nil
    }

    private func listDuplicateKey(for list: MyVerseList, userID: String) -> String {
        "\(userID)|\(normalizedTitle(for: list.title))|\(list.createdAt.timeIntervalSince1970)"
    }

    private func itemDuplicateKey(for item: MyVerseListItem, userID: String) -> String {
        "\(userID)|\(item.listId.uuidString)|\(item.book)|\(item.chapter)|\(item.verse)"
    }

    private func normalizedTitle(for title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension Array where Element == MyVerseList {
    func lists(for userID: String?) -> [MyVerseList] {
        guard let userID, !userID.isEmpty else { return [] }

        return filter {
            $0.ownerUserId == userID &&
            !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

extension Array where Element == MyVerseListItem {
    func items(for userID: String?) -> [MyVerseListItem] {
        guard let userID, !userID.isEmpty else { return [] }

        return filter { $0.ownerUserId == userID }
    }
}
