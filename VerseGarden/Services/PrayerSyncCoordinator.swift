import Combine
import FirebaseAuth
import SwiftData

@MainActor
final class PrayerSyncCoordinator: ObservableObject {
    @Published private(set) var isSyncing = false

    private let service = FirestorePrayerService()
    private var activeUserId: String?
    private var syncingUserId: String?
    private var inFlightTemplateUploads = Set<UUID>()
    private var inFlightRecordUploads = Set<UUID>()

    func seedDefaultTemplatesIfNeeded(modelContext: ModelContext) {
        let seeds = DefaultPrayerLibrary.load()
        let existing = (try? fetchAllTemplates(modelContext: modelContext)) ?? []

        var didChange = false
        for seed in seeds {
            if let template = existing.first(where: { $0.defaultTemplateID == seed.id }) {
                if template.title != seed.title || template.bodyText != seed.bodyText || template.category != seed.category || !template.isDefaultTemplate {
                    template.title = seed.title
                    template.bodyText = seed.bodyText
                    template.category = seed.category
                    template.isDefaultTemplate = true
                    template.ownerUserId = ""
                    template.updatedAt = Date()
                    didChange = true
                }
            } else {
                modelContext.insert(
                    PrayerTemplate(
                        ownerUserId: "",
                        title: seed.title,
                        bodyText: seed.bodyText,
                        category: seed.category,
                        isDefaultTemplate: true,
                        defaultTemplateID: seed.id
                    )
                )
                didChange = true
            }
        }

        if didChange {
            try? modelContext.save()
        }
    }

    func syncForAuthenticatedUser(userID: String?, modelContext: ModelContext) async {
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
            let remoteTemplates = try await service.fetchPrayerTemplates(for: userID)
            try reconcileTemplates(remoteTemplates: remoteTemplates, userID: userID, modelContext: modelContext)
        } catch {}

        do {
            let remoteRecords = try await service.fetchPrayerWritingRecords(for: userID)
            try reconcileRecords(remoteRecords: remoteRecords, userID: userID, modelContext: modelContext)
        } catch {}

        do {
            try await uploadPendingTemplates(for: userID, modelContext: modelContext)
        } catch {}

        do {
            try await uploadPendingRecords(for: userID, modelContext: modelContext)
        } catch {}
    }

    func uploadTemplateIfNeeded(localTemplateID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }
        guard !inFlightTemplateUploads.contains(localTemplateID) else { return }
        do {
            guard let template = try fetchAllTemplates(modelContext: modelContext).first(where: { $0.id == localTemplateID }) else { return }
            guard !template.isDefaultTemplate, template.ownerUserId == userID, template.remoteDocumentId == nil else { return }
            try await upload(template: template, userID: userID, modelContext: modelContext)
        } catch {}
    }

    func updateTemplateIfNeeded(localTemplateID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }
        do {
            guard let template = try fetchAllTemplates(modelContext: modelContext).first(where: { $0.id == localTemplateID }) else { return }
            guard !template.isDefaultTemplate, template.ownerUserId == userID, template.remoteDocumentId != nil else { return }
            try await service.updatePrayerTemplate(template, for: userID)
            template.lastSyncedAt = Date()
            try modelContext.save()
        } catch {}
    }

    func deleteTemplateIfNeeded(localTemplateID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }
        do {
            guard let template = try fetchAllTemplates(modelContext: modelContext).first(where: { $0.id == localTemplateID }) else { return }
            guard !template.isDefaultTemplate, template.ownerUserId == userID else { return }
            if let remoteDocumentId = template.remoteDocumentId, !remoteDocumentId.isEmpty {
                try await service.deletePrayerTemplate(remoteDocumentId: remoteDocumentId, for: userID)
            }
            modelContext.delete(template)
            try modelContext.save()
        } catch {}
    }

    func uploadRecordIfNeeded(localRecordID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }
        guard !inFlightRecordUploads.contains(localRecordID) else { return }
        do {
            guard let record = try fetchAllRecords(modelContext: modelContext).first(where: { $0.id == localRecordID }) else { return }
            guard record.ownerUserId == userID, record.remoteDocumentId == nil else { return }
            try await upload(record: record, userID: userID, modelContext: modelContext)
        } catch {}
    }

    func updateRecordIfNeeded(localRecordID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }
        do {
            guard let record = try fetchAllRecords(modelContext: modelContext).first(where: { $0.id == localRecordID }) else { return }
            guard record.ownerUserId == userID, record.remoteDocumentId != nil else { return }
            try await service.updatePrayerWritingRecord(record, for: userID)
            record.lastSyncedAt = Date()
            try modelContext.save()
        } catch {}
    }

    func deleteRecordIfNeeded(localRecordID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }
        do {
            guard let record = try fetchAllRecords(modelContext: modelContext).first(where: { $0.id == localRecordID }) else { return }
            guard record.ownerUserId == userID else { return }
            if let remoteDocumentId = record.remoteDocumentId, !remoteDocumentId.isEmpty {
                try await service.deletePrayerWritingRecord(remoteDocumentId: remoteDocumentId, for: userID)
            }
            modelContext.delete(record)
            try modelContext.save()
        } catch {}
    }

    func stopSync() {
        activeUserId = nil
        syncingUserId = nil
        isSyncing = false
        inFlightTemplateUploads.removeAll()
        inFlightRecordUploads.removeAll()
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

    private func reconcileTemplates(remoteTemplates: [PrayerTemplate], userID: String, modelContext: ModelContext) throws {
        let localTemplates = try fetchAllTemplates(modelContext: modelContext).filter { !$0.isDefaultTemplate && ($0.ownerUserId == userID || $0.ownerUserId.isEmpty) }
        var localByRemote: [String: PrayerTemplate] = [:]
        var localById: [UUID: PrayerTemplate] = [:]
        var localByDuplicate: [String: PrayerTemplate] = [:]

        for template in localTemplates {
            if let remote = template.remoteDocumentId { localByRemote[remote] = template }
            localById[template.id] = template
            localByDuplicate[templateDuplicateKey(for: template, userID: template.ownerUserId.isEmpty ? userID : template.ownerUserId)] = template
        }

        var didChange = false
        for remoteTemplate in remoteTemplates {
            guard let remoteId = remoteTemplate.remoteDocumentId else { continue }
            if let existing = localByRemote[remoteId] {
                didChange = merge(remote: remoteTemplate, into: existing, userID: userID) || didChange
            } else if let existing = localById[remoteTemplate.id] {
                if existing.remoteDocumentId == nil {
                    existing.remoteDocumentId = remoteId
                    existing.ownerUserId = userID
                    existing.lastSyncedAt = Date()
                    didChange = true
                }
                didChange = merge(remote: remoteTemplate, into: existing, userID: userID) || didChange
            } else if let existing = localByDuplicate[templateDuplicateKey(for: remoteTemplate, userID: userID)] {
                if existing.remoteDocumentId == nil {
                    existing.remoteDocumentId = remoteId
                    existing.ownerUserId = userID
                    existing.lastSyncedAt = Date()
                    didChange = true
                }
                didChange = merge(remote: remoteTemplate, into: existing, userID: userID) || didChange
            } else {
                modelContext.insert(
                    PrayerTemplate(
                        id: remoteTemplate.id,
                        ownerUserId: userID,
                        remoteDocumentId: remoteId,
                        lastSyncedAt: Date(),
                        createdAt: remoteTemplate.createdAt,
                        updatedAt: remoteTemplate.updatedAt,
                        title: remoteTemplate.title,
                        bodyText: remoteTemplate.bodyText,
                        category: remoteTemplate.category,
                        isDefaultTemplate: false,
                        defaultTemplateID: nil,
                        isArchived: remoteTemplate.isArchived
                    )
                )
                didChange = true
            }
        }

        let remoteIds = Set(remoteTemplates.compactMap(\.remoteDocumentId))
        let orphanedTemplates = localTemplates.filter {
            guard let remoteId = $0.remoteDocumentId, !remoteId.isEmpty else { return false }
            return !remoteIds.contains(remoteId)
        }
        orphanedTemplates.forEach { modelContext.delete($0) ; didChange = true }

        if didChange {
            try modelContext.save()
        }
    }

    private func reconcileRecords(remoteRecords: [PrayerWritingRecord], userID: String, modelContext: ModelContext) throws {
        let localRecords = try fetchAllRecords(modelContext: modelContext).filter { $0.ownerUserId == userID || $0.ownerUserId.isEmpty }
        var localByRemote: [String: PrayerWritingRecord] = [:]
        var localById: [UUID: PrayerWritingRecord] = [:]
        var localByDuplicate: [String: PrayerWritingRecord] = [:]

        for record in localRecords {
            if let remote = record.remoteDocumentId { localByRemote[remote] = record }
            localById[record.id] = record
            localByDuplicate[recordDuplicateKey(for: record, userID: record.ownerUserId.isEmpty ? userID : record.ownerUserId)] = record
        }

        var didChange = false
        for remoteRecord in remoteRecords {
            guard let remoteId = remoteRecord.remoteDocumentId else { continue }
            if let existing = localByRemote[remoteId] {
                didChange = merge(remote: remoteRecord, into: existing, userID: userID) || didChange
            } else if let existing = localById[remoteRecord.id] {
                if existing.remoteDocumentId == nil {
                    existing.remoteDocumentId = remoteId
                    existing.ownerUserId = userID
                    existing.lastSyncedAt = Date()
                    didChange = true
                }
                didChange = merge(remote: remoteRecord, into: existing, userID: userID) || didChange
            } else if let existing = localByDuplicate[recordDuplicateKey(for: remoteRecord, userID: userID)] {
                if existing.remoteDocumentId == nil {
                    existing.remoteDocumentId = remoteId
                    existing.ownerUserId = userID
                    existing.lastSyncedAt = Date()
                    didChange = true
                }
                didChange = merge(remote: remoteRecord, into: existing, userID: userID) || didChange
            } else {
                modelContext.insert(
                    PrayerWritingRecord(
                        id: remoteRecord.id,
                        ownerUserId: userID,
                        remoteDocumentId: remoteId,
                        lastSyncedAt: Date(),
                        createdAt: remoteRecord.createdAt,
                        updatedAt: remoteRecord.updatedAt,
                        date: remoteRecord.date,
                        completedAt: remoteRecord.completedAt,
                        sourceType: remoteRecord.sourceType,
                        templateLocalId: remoteRecord.templateLocalId,
                        templateRemoteId: remoteRecord.templateRemoteId,
                        titleSnapshot: remoteRecord.titleSnapshot,
                        originalText: remoteRecord.originalText,
                        userText: remoteRecord.userText
                    )
                )
                didChange = true
            }
        }

        let remoteIds = Set(remoteRecords.compactMap(\.remoteDocumentId))
        let orphanedRecords = localRecords.filter {
            guard let remoteId = $0.remoteDocumentId, !remoteId.isEmpty else { return false }
            return !remoteIds.contains(remoteId)
        }
        orphanedRecords.forEach { modelContext.delete($0); didChange = true }

        if didChange {
            try modelContext.save()
        }
    }

    private func merge(remote: PrayerTemplate, into local: PrayerTemplate, userID: String) -> Bool {
        var didChange = false
        local.ownerUserId = userID
        if local.title != remote.title && remote.updatedAt >= local.updatedAt {
            local.title = remote.title
            didChange = true
        }
        if local.bodyText != remote.bodyText && remote.updatedAt >= local.updatedAt {
            local.bodyText = remote.bodyText
            didChange = true
        }
        if local.category != remote.category && remote.updatedAt >= local.updatedAt {
            local.category = remote.category
            didChange = true
        }
        if local.updatedAt != remote.updatedAt && remote.updatedAt >= local.updatedAt {
            local.updatedAt = remote.updatedAt
            didChange = true
        }
        local.lastSyncedAt = Date()
        return didChange
    }

    private func merge(remote: PrayerWritingRecord, into local: PrayerWritingRecord, userID: String) -> Bool {
        var didChange = false
        local.ownerUserId = userID
        if remote.updatedAt >= local.updatedAt {
            if local.titleSnapshot != remote.titleSnapshot { local.titleSnapshot = remote.titleSnapshot; didChange = true }
            if local.originalText != remote.originalText { local.originalText = remote.originalText; didChange = true }
            if local.userText != remote.userText { local.userText = remote.userText; didChange = true }
            if local.templateLocalId != remote.templateLocalId { local.templateLocalId = remote.templateLocalId; didChange = true }
            if local.templateRemoteId != remote.templateRemoteId { local.templateRemoteId = remote.templateRemoteId; didChange = true }
            if local.updatedAt != remote.updatedAt { local.updatedAt = remote.updatedAt; didChange = true }
            if local.completedAt != remote.completedAt { local.completedAt = remote.completedAt; didChange = true }
            if local.date != remote.date { local.date = remote.date; didChange = true }
        }
        local.lastSyncedAt = Date()
        return didChange
    }

    private func uploadPendingTemplates(for userID: String, modelContext: ModelContext) async throws {
        let templates = try fetchAllTemplates(modelContext: modelContext)
            .userTemplates(for: userID)
            .filter { $0.remoteDocumentId == nil && !inFlightTemplateUploads.contains($0.id) }
        for template in templates {
            try await upload(template: template, userID: userID, modelContext: modelContext)
        }
    }

    private func uploadPendingRecords(for userID: String, modelContext: ModelContext) async throws {
        let records = try fetchAllRecords(modelContext: modelContext).records(for: userID).filter {
            $0.remoteDocumentId == nil && !inFlightRecordUploads.contains($0.id)
        }
        for record in records {
            try await upload(record: record, userID: userID, modelContext: modelContext)
        }
    }

    private func upload(template: PrayerTemplate, userID: String, modelContext: ModelContext) async throws {
        guard !template.isDefaultTemplate, template.ownerUserId == userID else { return }
        guard !inFlightTemplateUploads.contains(template.id) else { return }

        inFlightTemplateUploads.insert(template.id)
        defer {
            inFlightTemplateUploads.remove(template.id)
        }

        if let remoteDocumentId = template.remoteDocumentId, !remoteDocumentId.isEmpty {
            try await service.updatePrayerTemplate(template, for: userID)
            template.lastSyncedAt = Date()
            try modelContext.save()
            return
        }

        let remoteId = try await service.createPrayerTemplate(from: template, for: userID)
        template.remoteDocumentId = remoteId
        template.lastSyncedAt = Date()
        try modelContext.save()
    }

    private func upload(record: PrayerWritingRecord, userID: String, modelContext: ModelContext) async throws {
        guard record.ownerUserId == userID, record.remoteDocumentId == nil else { return }
        guard !inFlightRecordUploads.contains(record.id) else { return }

        inFlightRecordUploads.insert(record.id)
        defer {
            inFlightRecordUploads.remove(record.id)
        }

        let remoteId = try await service.createPrayerWritingRecord(from: record, for: userID)
        record.remoteDocumentId = remoteId
        record.lastSyncedAt = Date()
        try modelContext.save()
    }

    private func fetchAllTemplates(modelContext: ModelContext) throws -> [PrayerTemplate] {
        try modelContext.fetch(FetchDescriptor<PrayerTemplate>())
    }

    private func fetchAllRecords(modelContext: ModelContext) throws -> [PrayerWritingRecord] {
        try modelContext.fetch(FetchDescriptor<PrayerWritingRecord>())
    }

    private func templateDuplicateKey(for template: PrayerTemplate, userID: String) -> String {
        [userID, template.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), String(Int(template.createdAt.timeIntervalSince1970))].joined(separator: "|")
    }

    private func recordDuplicateKey(for record: PrayerWritingRecord, userID: String) -> String {
        [userID, record.sourceType, record.titleSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), String(Int(record.completedAt.timeIntervalSince1970))].joined(separator: "|")
    }
}
