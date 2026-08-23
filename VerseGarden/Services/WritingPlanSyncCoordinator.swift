import Combine
import FirebaseAuth
import SwiftData

@MainActor
final class WritingPlanSyncCoordinator: ObservableObject {
    @Published private(set) var isSyncing = false

    private let service = FirestoreWritingPlanService()
    private var activeUserId: String?
    private var syncingUserId: String?
    private var inFlightPlanUploads = Set<UUID>()
    private var inFlightAssignmentUploads = Set<UUID>()

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
            let remotePlans = try await service.fetchPlans(for: userID)
            try await reconcile(remotePlans: remotePlans, userID: userID, modelContext: modelContext)
            try await uploadPendingPlans(for: userID, modelContext: modelContext)
            try await uploadPendingAssignments(for: userID, modelContext: modelContext)
        } catch {}
    }

    func uploadPlanIfNeeded(localPlanID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }
        guard !inFlightPlanUploads.contains(localPlanID) else { return }

        do {
            guard let plan = try fetchAllPlans(modelContext: modelContext).first(where: { $0.id == localPlanID }) else {
                return
            }
            guard plan.ownerUserId == userID else { return }
            try await upload(plan: plan, userID: userID, modelContext: modelContext)
            try await uploadPendingAssignments(for: userID, planID: localPlanID, modelContext: modelContext)
        } catch {}
    }

    func updatePlanIfNeeded(localPlanID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }

        do {
            guard let plan = try fetchAllPlans(modelContext: modelContext).first(where: { $0.id == localPlanID }) else {
                return
            }
            guard plan.ownerUserId == userID else { return }
            if plan.remoteDocumentId == nil {
                try await upload(plan: plan, userID: userID, modelContext: modelContext)
                try await uploadPendingAssignments(for: userID, planID: localPlanID, modelContext: modelContext)
                return
            }
            try await service.updatePlan(plan, for: userID)
            plan.lastSyncedAt = Date()
            try modelContext.save()
        } catch {}
    }

    func syncPlanAndAssignments(localPlanID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }

        do {
            guard let plan = try fetchAllPlans(modelContext: modelContext).first(where: { $0.id == localPlanID }) else {
                return
            }
            guard plan.ownerUserId == userID else { return }

            if plan.remoteDocumentId == nil {
                try await upload(plan: plan, userID: userID, modelContext: modelContext)
            } else {
                try await service.updatePlan(plan, for: userID)
                plan.lastSyncedAt = Date()
                try modelContext.save()
            }

            guard let planRemoteId = plan.remoteDocumentId, !planRemoteId.isEmpty else { return }

            let remoteAssignments = try await service.fetchAssignments(
                for: userID,
                planRemoteId: planRemoteId,
                planLocalId: plan.id
            )
            try await syncLocalAssignments(
                for: plan,
                remoteAssignments: remoteAssignments,
                userID: userID,
                planRemoteId: planRemoteId,
                modelContext: modelContext
            )
        } catch {}
    }

    func updateAssignmentIfNeeded(localAssignmentID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }

        do {
            guard let assignment = try fetchAllAssignments(modelContext: modelContext).first(where: { $0.id == localAssignmentID }) else {
                return
            }
            guard assignment.ownerUserId == userID else { return }
            guard let plan = try fetchAllPlans(modelContext: modelContext).first(where: { $0.id == assignment.planLocalId }) else {
                return
            }

            if plan.remoteDocumentId == nil {
                try await upload(plan: plan, userID: userID, modelContext: modelContext)
            }
            guard let planRemoteId = plan.remoteDocumentId, !planRemoteId.isEmpty else { return }

            if assignment.remoteDocumentId == nil {
                try await upload(assignment: assignment, userID: userID, planRemoteId: planRemoteId, modelContext: modelContext)
                return
            }

            try await service.updateAssignment(assignment, for: userID, planRemoteId: planRemoteId)
            assignment.lastSyncedAt = Date()
            try modelContext.save()
        } catch {}
    }

    func updatePlanAndAssignmentIfNeeded(
        localPlanID: UUID,
        localAssignmentID: UUID,
        userID: String?,
        modelContext: ModelContext
    ) async {
        await updatePlanIfNeeded(localPlanID: localPlanID, userID: userID, modelContext: modelContext)
        await updateAssignmentIfNeeded(localAssignmentID: localAssignmentID, userID: userID, modelContext: modelContext)
    }

    func deletePlanIfNeeded(localPlanID: UUID, userID: String?, modelContext: ModelContext) async {
        guard let userID = validatedCurrentUserID(for: userID) else { return }

        do {
            guard let plan = try fetchAllPlans(modelContext: modelContext).first(where: { $0.id == localPlanID }) else {
                return
            }
            guard plan.ownerUserId == userID else { return }

            if let remoteDocumentId = plan.remoteDocumentId, !remoteDocumentId.isEmpty {
                try await service.deletePlan(remoteDocumentId: remoteDocumentId, for: userID)
            }

            let assignments = try fetchAllAssignments(modelContext: modelContext).filter { $0.planLocalId == plan.id }
            assignments.forEach { modelContext.delete($0) }
            modelContext.delete(plan)
            try modelContext.save()
        } catch {}
    }

    func stopSync() {
        activeUserId = nil
        syncingUserId = nil
        isSyncing = false
        inFlightPlanUploads.removeAll()
        inFlightAssignmentUploads.removeAll()
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
        remotePlans: [ScriptureWritingPlan],
        userID: String,
        modelContext: ModelContext
    ) async throws {
        let localPlans = try fetchAllPlans(modelContext: modelContext).filter {
            $0.ownerUserId == userID || $0.ownerUserId.isEmpty
        }
        var localByRemote: [String: ScriptureWritingPlan] = [:]
        var localById: [UUID: ScriptureWritingPlan] = [:]

        for plan in localPlans {
            if let remoteDocumentId = plan.remoteDocumentId, !remoteDocumentId.isEmpty {
                localByRemote[remoteDocumentId] = plan
            }
            localById[plan.id] = plan
        }

        var didChange = false
        var resolvedPlans: [(remote: ScriptureWritingPlan, local: ScriptureWritingPlan)] = []

        for remotePlan in remotePlans {
            guard let remoteDocumentId = remotePlan.remoteDocumentId, !remoteDocumentId.isEmpty else { continue }

            if let existing = localByRemote[remoteDocumentId] {
                didChange = merge(remote: remotePlan, into: existing, userID: userID) || didChange
                resolvedPlans.append((remotePlan, existing))
            } else if let existing = localById[remotePlan.id] {
                if existing.remoteDocumentId == nil {
                    existing.remoteDocumentId = remoteDocumentId
                    existing.ownerUserId = userID
                    existing.lastSyncedAt = Date()
                    didChange = true
                }
                didChange = merge(remote: remotePlan, into: existing, userID: userID) || didChange
                resolvedPlans.append((remotePlan, existing))
            } else {
                let newPlan = ScriptureWritingPlan(
                    id: remotePlan.id,
                    ownerUserId: userID,
                    remoteDocumentId: remoteDocumentId,
                    lastSyncedAt: Date(),
                    title: remotePlan.title,
                    book: remotePlan.book,
                    startChapter: remotePlan.startChapter,
                    endChapter: remotePlan.endChapter,
                    startVerse: remotePlan.startVerse,
                    endVerse: remotePlan.endVerse,
                    startDate: remotePlan.startDate,
                    endDate: remotePlan.endDate,
                    totalDays: remotePlan.totalDays,
                    totalVerses: remotePlan.totalVerses,
                    completedDays: remotePlan.completedDays,
                    folderColorRaw: remotePlan.folderColorRaw,
                    status: remotePlan.status,
                    createdAt: remotePlan.createdAt,
                    updatedAt: remotePlan.updatedAt
                )
                modelContext.insert(newPlan)
                localByRemote[remoteDocumentId] = newPlan
                localById[newPlan.id] = newPlan
                resolvedPlans.append((remotePlan, newPlan))
                didChange = true
            }
        }

        let remoteDocumentIds = Set(remotePlans.compactMap(\.remoteDocumentId))
        let orphanedPlans = localPlans.filter {
            guard let remoteDocumentId = $0.remoteDocumentId, !remoteDocumentId.isEmpty else { return false }
            return !remoteDocumentIds.contains(remoteDocumentId)
        }
        for orphanedPlan in orphanedPlans {
            let orphanedAssignments = try fetchAllAssignments(modelContext: modelContext).filter { $0.planLocalId == orphanedPlan.id }
            orphanedAssignments.forEach { modelContext.delete($0) }
            modelContext.delete(orphanedPlan)
            didChange = true
        }

        if didChange {
            try modelContext.save()
        }

        for pair in resolvedPlans {
            guard let planRemoteId = pair.remote.remoteDocumentId else { continue }
            let remoteAssignments = try await service.fetchAssignments(
                for: userID,
                planRemoteId: planRemoteId,
                planLocalId: pair.local.id
            )
            try reconcileAssignments(
                remoteAssignments: remoteAssignments,
                plan: pair.local,
                userID: userID,
                modelContext: modelContext
            )
        }
    }

    private func reconcileAssignments(
        remoteAssignments: [PlanDayAssignment],
        plan: ScriptureWritingPlan,
        userID: String,
        modelContext: ModelContext
    ) throws {
        let localAssignments = try fetchAllAssignments(modelContext: modelContext).filter {
            ($0.ownerUserId == userID || $0.ownerUserId.isEmpty) && $0.planLocalId == plan.id
        }
        var localByRemote: [String: PlanDayAssignment] = [:]
        var localById: [UUID: PlanDayAssignment] = [:]
        var localByDayIndex: [Int: PlanDayAssignment] = [:]

        for assignment in localAssignments {
            if let remoteDocumentId = assignment.remoteDocumentId, !remoteDocumentId.isEmpty {
                localByRemote[remoteDocumentId] = assignment
            }
            localById[assignment.id] = assignment
            localByDayIndex[assignment.dayIndex] = assignment
        }

        var didChange = false
        for remoteAssignment in remoteAssignments {
            guard let remoteDocumentId = remoteAssignment.remoteDocumentId, !remoteDocumentId.isEmpty else { continue }

            if let existing = localByRemote[remoteDocumentId] {
                didChange = merge(remote: remoteAssignment, into: existing, planID: plan.id, userID: userID) || didChange
            } else if let existing = localById[remoteAssignment.id] {
                if existing.remoteDocumentId == nil {
                    existing.remoteDocumentId = remoteDocumentId
                    existing.ownerUserId = userID
                    existing.lastSyncedAt = Date()
                    didChange = true
                }
                didChange = merge(remote: remoteAssignment, into: existing, planID: plan.id, userID: userID) || didChange
            } else if let existing = localByDayIndex[remoteAssignment.dayIndex], existing.remoteDocumentId == nil {
                existing.remoteDocumentId = remoteDocumentId
                existing.ownerUserId = userID
                existing.lastSyncedAt = Date()
                didChange = merge(remote: remoteAssignment, into: existing, planID: plan.id, userID: userID) || true
            } else {
                modelContext.insert(
                    PlanDayAssignment(
                        id: remoteAssignment.id,
                        planLocalId: plan.id,
                        ownerUserId: userID,
                        remoteDocumentId: remoteDocumentId,
                        lastSyncedAt: Date(),
                        dayIndex: remoteAssignment.dayIndex,
                        date: remoteAssignment.date,
                        book: remoteAssignment.book,
                        startChapter: remoteAssignment.startChapter,
                        startVerse: remoteAssignment.startVerse,
                        endChapter: remoteAssignment.endChapter,
                        endVerse: remoteAssignment.endVerse,
                        verseCount: remoteAssignment.verseCount,
                        state: remoteAssignment.state,
                        completedAt: remoteAssignment.completedAt,
                        completionRecordIds: remoteAssignment.completionRecordIds,
                        createdAt: remoteAssignment.createdAt,
                        updatedAt: remoteAssignment.updatedAt
                    )
                )
                didChange = true
            }
        }

        let remoteDocumentIds = Set(remoteAssignments.compactMap(\.remoteDocumentId))
        let orphanedAssignments = localAssignments.filter {
            guard let remoteDocumentId = $0.remoteDocumentId, !remoteDocumentId.isEmpty else { return false }
            return !remoteDocumentIds.contains(remoteDocumentId)
        }
        for orphanedAssignment in orphanedAssignments {
            modelContext.delete(orphanedAssignment)
            didChange = true
        }

        if didChange {
            try modelContext.save()
        }
    }

    private func merge(remote: ScriptureWritingPlan, into local: ScriptureWritingPlan, userID: String) -> Bool {
        var didChange = false
        if local.ownerUserId != userID {
            local.ownerUserId = userID
            didChange = true
        }

        if remote.updatedAt >= local.updatedAt {
            if local.title != remote.title { local.title = remote.title; didChange = true }
            if local.book != remote.book { local.book = remote.book; didChange = true }
            if local.startChapter != remote.startChapter { local.startChapter = remote.startChapter; didChange = true }
            if local.endChapter != remote.endChapter { local.endChapter = remote.endChapter; didChange = true }
            if local.startVerse != remote.startVerse { local.startVerse = remote.startVerse; didChange = true }
            if local.endVerse != remote.endVerse { local.endVerse = remote.endVerse; didChange = true }
            if local.startDate != remote.startDate { local.startDate = remote.startDate; didChange = true }
            if local.endDate != remote.endDate { local.endDate = remote.endDate; didChange = true }
            if local.totalDays != remote.totalDays { local.totalDays = remote.totalDays; didChange = true }
            if local.totalVerses != remote.totalVerses { local.totalVerses = remote.totalVerses; didChange = true }
            if local.completedDays != remote.completedDays { local.completedDays = remote.completedDays; didChange = true }
            if local.statusRaw != remote.statusRaw { local.statusRaw = remote.statusRaw; didChange = true }
            if local.folderColorRaw != remote.folderColorRaw { local.folderColorRaw = remote.folderColorRaw; didChange = true }
            if local.createdAt != remote.createdAt { local.createdAt = remote.createdAt; didChange = true }
            if local.updatedAt != remote.updatedAt { local.updatedAt = remote.updatedAt; didChange = true }
        }

        if local.lastSyncedAt == nil {
            didChange = true
        }
        local.lastSyncedAt = Date()
        return didChange
    }

    private func merge(remote: PlanDayAssignment, into local: PlanDayAssignment, planID: UUID, userID: String) -> Bool {
        var didChange = false
        if local.ownerUserId != userID {
            local.ownerUserId = userID
            didChange = true
        }
        if local.planLocalId != planID {
            local.planLocalId = planID
            didChange = true
        }

        if remote.updatedAt >= local.updatedAt {
            if local.dayIndex != remote.dayIndex { local.dayIndex = remote.dayIndex; didChange = true }
            if local.date != remote.date { local.date = remote.date; didChange = true }
            if local.book != remote.book { local.book = remote.book; didChange = true }
            if local.startChapter != remote.startChapter { local.startChapter = remote.startChapter; didChange = true }
            if local.startVerse != remote.startVerse { local.startVerse = remote.startVerse; didChange = true }
            if local.endChapter != remote.endChapter { local.endChapter = remote.endChapter; didChange = true }
            if local.endVerse != remote.endVerse { local.endVerse = remote.endVerse; didChange = true }
            if local.verseCount != remote.verseCount { local.verseCount = remote.verseCount; didChange = true }
            if local.stateRaw != remote.stateRaw { local.stateRaw = remote.stateRaw; didChange = true }
            if local.completedAt != remote.completedAt { local.completedAt = remote.completedAt; didChange = true }
            if local.completionRecordIds != remote.completionRecordIds { local.completionRecordIds = remote.completionRecordIds; didChange = true }
            if local.createdAt != remote.createdAt { local.createdAt = remote.createdAt; didChange = true }
            if local.updatedAt != remote.updatedAt { local.updatedAt = remote.updatedAt; didChange = true }
        }

        if local.lastSyncedAt == nil {
            didChange = true
        }
        local.lastSyncedAt = Date()
        return didChange
    }

    private func uploadPendingPlans(for userID: String, modelContext: ModelContext) async throws {
        let plans = try fetchAllPlans(modelContext: modelContext).filter {
            $0.ownerUserId == userID && $0.remoteDocumentId == nil && !inFlightPlanUploads.contains($0.id)
        }

        for plan in plans {
            try await upload(plan: plan, userID: userID, modelContext: modelContext)
        }
    }

    private func uploadPendingAssignments(for userID: String, modelContext: ModelContext) async throws {
        let assignments = try fetchAllAssignments(modelContext: modelContext).filter {
            $0.ownerUserId == userID && $0.remoteDocumentId == nil && !inFlightAssignmentUploads.contains($0.id)
        }

        for assignment in assignments {
            guard let plan = try fetchAllPlans(modelContext: modelContext).first(where: { $0.id == assignment.planLocalId }),
                  let planRemoteId = plan.remoteDocumentId,
                  !planRemoteId.isEmpty else {
                continue
            }
            try await upload(assignment: assignment, userID: userID, planRemoteId: planRemoteId, modelContext: modelContext)
        }
    }

    private func uploadPendingAssignments(
        for userID: String,
        planID: UUID,
        modelContext: ModelContext
    ) async throws {
        let assignments = try fetchAllAssignments(modelContext: modelContext).filter {
            $0.ownerUserId == userID && $0.planLocalId == planID && $0.remoteDocumentId == nil && !inFlightAssignmentUploads.contains($0.id)
        }
        guard let plan = try fetchAllPlans(modelContext: modelContext).first(where: { $0.id == planID }),
              let planRemoteId = plan.remoteDocumentId,
              !planRemoteId.isEmpty else {
            return
        }

        for assignment in assignments {
            try await upload(assignment: assignment, userID: userID, planRemoteId: planRemoteId, modelContext: modelContext)
        }
    }

    private func syncLocalAssignments(
        for plan: ScriptureWritingPlan,
        remoteAssignments: [PlanDayAssignment],
        userID: String,
        planRemoteId: String,
        modelContext: ModelContext
    ) async throws {
        let localAssignments = try fetchAllAssignments(modelContext: modelContext)
            .filter { $0.ownerUserId == userID && $0.planLocalId == plan.id }
            .sorted { $0.dayIndex < $1.dayIndex }

        var remoteByDocumentId: [String: PlanDayAssignment] = [:]
        var remoteByLocalId: [UUID: PlanDayAssignment] = [:]
        var remoteByDayIndex: [Int: PlanDayAssignment] = [:]

        for remoteAssignment in remoteAssignments {
            if let remoteDocumentId = remoteAssignment.remoteDocumentId, !remoteDocumentId.isEmpty {
                remoteByDocumentId[remoteDocumentId] = remoteAssignment
            }
            remoteByLocalId[remoteAssignment.id] = remoteAssignment
            remoteByDayIndex[remoteAssignment.dayIndex] = remoteAssignment
        }

        var retainedRemoteDocumentIds = Set<String>()

        for assignment in localAssignments {
            if let remoteDocumentId = assignment.remoteDocumentId,
               !remoteDocumentId.isEmpty,
               remoteByDocumentId[remoteDocumentId] != nil {
                try await service.updateAssignment(assignment, for: userID, planRemoteId: planRemoteId)
                assignment.lastSyncedAt = Date()
                retainedRemoteDocumentIds.insert(remoteDocumentId)
                continue
            }

            if let remoteAssignment = remoteByLocalId[assignment.id],
               let remoteDocumentId = remoteAssignment.remoteDocumentId,
               !remoteDocumentId.isEmpty {
                assignment.remoteDocumentId = remoteDocumentId
                try await service.updateAssignment(assignment, for: userID, planRemoteId: planRemoteId)
                assignment.lastSyncedAt = Date()
                retainedRemoteDocumentIds.insert(remoteDocumentId)
                continue
            }

            if let remoteAssignment = remoteByDayIndex[assignment.dayIndex],
               let remoteDocumentId = remoteAssignment.remoteDocumentId,
               !remoteDocumentId.isEmpty,
               assignment.remoteDocumentId == nil {
                assignment.remoteDocumentId = remoteDocumentId
                try await service.updateAssignment(assignment, for: userID, planRemoteId: planRemoteId)
                assignment.lastSyncedAt = Date()
                retainedRemoteDocumentIds.insert(remoteDocumentId)
                continue
            }

            try await upload(assignment: assignment, userID: userID, planRemoteId: planRemoteId, modelContext: modelContext)
            if let remoteDocumentId = assignment.remoteDocumentId, !remoteDocumentId.isEmpty {
                retainedRemoteDocumentIds.insert(remoteDocumentId)
            }
        }

        try modelContext.save()

        for remoteAssignment in remoteAssignments {
            guard let remoteDocumentId = remoteAssignment.remoteDocumentId, !remoteDocumentId.isEmpty else { continue }
            guard !retainedRemoteDocumentIds.contains(remoteDocumentId) else { continue }
            try await service.deleteAssignment(remoteDocumentId: remoteDocumentId, for: userID, planRemoteId: planRemoteId)
        }
    }

    private func upload(plan: ScriptureWritingPlan, userID: String, modelContext: ModelContext) async throws {
        guard plan.ownerUserId == userID else { return }
        guard !inFlightPlanUploads.contains(plan.id) else { return }

        inFlightPlanUploads.insert(plan.id)
        defer { inFlightPlanUploads.remove(plan.id) }

        if let remoteDocumentId = plan.remoteDocumentId, !remoteDocumentId.isEmpty {
            try await service.updatePlan(plan, for: userID)
            plan.lastSyncedAt = Date()
            try modelContext.save()
            return
        }

        let remoteId = try await service.createPlan(from: plan, for: userID)
        plan.remoteDocumentId = remoteId
        plan.lastSyncedAt = Date()
        try modelContext.save()
    }

    private func upload(
        assignment: PlanDayAssignment,
        userID: String,
        planRemoteId: String,
        modelContext: ModelContext
    ) async throws {
        guard assignment.ownerUserId == userID else { return }
        guard !inFlightAssignmentUploads.contains(assignment.id) else { return }

        inFlightAssignmentUploads.insert(assignment.id)
        defer { inFlightAssignmentUploads.remove(assignment.id) }

        if let remoteDocumentId = assignment.remoteDocumentId, !remoteDocumentId.isEmpty {
            try await service.updateAssignment(assignment, for: userID, planRemoteId: planRemoteId)
            assignment.lastSyncedAt = Date()
            try modelContext.save()
            return
        }

        let remoteId = try await service.createAssignment(assignment, for: userID, planRemoteId: planRemoteId)
        assignment.remoteDocumentId = remoteId
        assignment.lastSyncedAt = Date()
        try modelContext.save()
    }

    private func fetchAllPlans(modelContext: ModelContext) throws -> [ScriptureWritingPlan] {
        try modelContext.fetch(FetchDescriptor<ScriptureWritingPlan>())
    }

    private func fetchAllAssignments(modelContext: ModelContext) throws -> [PlanDayAssignment] {
        try modelContext.fetch(FetchDescriptor<PlanDayAssignment>())
    }
}
