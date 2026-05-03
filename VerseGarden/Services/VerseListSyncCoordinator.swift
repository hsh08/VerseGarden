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

    func syncForAuthenticatedUser(userID: String?, modelContext: ModelContext) async {
        guard let userID, !userID.isEmpty else {
            return
        }

        guard let userID = validatedCurrentUserID(for: userID) else {
            stopSync()
            return
        }

        activeUserId = userID
        isSyncing = true

        do {
            let remoteBundles = try await service.fetchLists(for: userID)
            try reconcile(remoteBundles: remoteBundles, userID: userID, modelContext: modelContext)
            try await uploadPendingLists(for: userID, modelContext: modelContext)
            try await uploadPendingItems(for: userID, modelContext: modelContext)
        } catch {}

        isSyncing = false
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

    func stopSync() {
        activeUserId = nil
        isSyncing = false
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
        remoteBundles: [RemoteVerseListBundle],
        userID: String,
        modelContext: ModelContext
    ) throws {
        let localLists = try fetchAllLists(modelContext: modelContext).filter { list in
            list.ownerUserId == userID || list.ownerUserId.isEmpty
        }
        let localItems = try fetchAllItems(modelContext: modelContext).filter { item in
            item.ownerUserId == userID || item.ownerUserId.isEmpty
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

        var localItemsByRemoteDocumentId: [String: MyVerseListItem] = [:]
        var localItemsByLocalId: [UUID: MyVerseListItem] = [:]
        var localItemsByDuplicateKey: [String: MyVerseListItem] = [:]

        for item in localItems {
            if let remoteDocumentId = item.remoteDocumentId {
                localItemsByRemoteDocumentId[remoteDocumentId] = item
            }
            localItemsByLocalId[item.id] = item
            localItemsByDuplicateKey[itemDuplicateKey(for: item, userID: item.ownerUserId.isEmpty ? userID : item.ownerUserId)] = item
        }

        var didChange = false

        for bundle in remoteBundles {
            let remoteList = bundle.list
            guard let remoteListDocumentId = remoteList.remoteDocumentId else { continue }

            let localList: MyVerseList
            if let existing = localListsByRemoteDocumentId[remoteListDocumentId] {
                localList = existing
                didChange = merge(remote: remoteList, into: existing, userID: userID) || didChange
            } else if let existing = localListsByLocalId[remoteList.id] {
                localList = existing
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
                    localList = existing
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
                    localList = newList
                    didChange = true
                }
            }

            localListsByRemoteDocumentId[remoteListDocumentId] = localList
            localListsByLocalId[localList.id] = localList
            localListsByDuplicateKey[listDuplicateKey(for: localList, userID: userID)] = localList

            for remoteItem in bundle.items {
                let normalizedRemoteItem = MyVerseListItem(
                    id: remoteItem.id,
                    listId: localList.id,
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
                    didChange = merge(remote: normalizedRemoteItem, into: existing, listId: localList.id, userID: userID) || didChange
                    continue
                }

                if let existing = localItemsByLocalId[normalizedRemoteItem.id] {
                    if existing.remoteDocumentId == nil {
                        existing.remoteDocumentId = remoteItemDocumentId
                        existing.lastSyncedAt = Date()
                        if existing.ownerUserId.isEmpty {
                            existing.ownerUserId = userID
                        }
                        existing.listId = localList.id
                        didChange = true
                    }
                    didChange = merge(remote: normalizedRemoteItem, into: existing, listId: localList.id, userID: userID) || didChange
                    localItemsByRemoteDocumentId[remoteItemDocumentId] = existing
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
                        existing.listId = localList.id
                        didChange = true
                    }
                    didChange = merge(remote: normalizedRemoteItem, into: existing, listId: localList.id, userID: userID) || didChange
                    localItemsByRemoteDocumentId[remoteItemDocumentId] = existing
                    continue
                }

                let newItem = MyVerseListItem(
                    id: normalizedRemoteItem.id,
                    listId: localList.id,
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
                localItemsByLocalId[newItem.id] = newItem
                localItemsByDuplicateKey[itemDuplicateKey(for: newItem, userID: userID)] = newItem
                didChange = true
            }
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
            $0.ownerUserId == userID && $0.remoteDocumentId == nil
        }

        for list in pendingLists {
            try await upload(list: list, userID: userID, modelContext: modelContext)
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
            $0.ownerUserId == userID && $0.listId == listID && $0.remoteDocumentId == nil
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

        let remoteDocumentId = try await service.createList(from: list, for: userID)
        list.remoteDocumentId = remoteDocumentId
        list.lastSyncedAt = Date()
        try modelContext.save()
    }

    private func upload(item: MyVerseListItem, userID: String, remoteListDocumentId: String, modelContext: ModelContext) async throws {
        guard item.remoteDocumentId == nil else { return }

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
        guard let userID, !userID.isEmpty else {
            return filter { $0.ownerUserId.isEmpty }
        }

        return filter { $0.ownerUserId == userID || $0.ownerUserId.isEmpty }
    }
}

extension Array where Element == MyVerseListItem {
    func items(for userID: String?) -> [MyVerseListItem] {
        guard let userID, !userID.isEmpty else {
            return filter { $0.ownerUserId.isEmpty }
        }

        return filter { $0.ownerUserId == userID || $0.ownerUserId.isEmpty }
    }
}
