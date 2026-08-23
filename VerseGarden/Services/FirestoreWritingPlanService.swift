import FirebaseAuth
import FirebaseFirestore
import Foundation

struct FirestoreWritingPlanService {
    private var database: Firestore { Firestore.firestore() }

    func fetchPlans(for userID: String) async throws -> [ScriptureWritingPlan] {
        try validateUser(userID)

        let snapshot = try await getDocuments(
            database.collection("users")
                .document(userID)
                .collection("writingPlans")
        )

        return snapshot.documents.compactMap { makePlan(from: $0, userID: userID) }
    }

    func fetchAssignments(for userID: String, planRemoteId: String, planLocalId: UUID) async throws -> [PlanDayAssignment] {
        try validateUser(userID)
        guard !planRemoteId.isEmpty else { return [] }

        let snapshot = try await getDocuments(
            database.collection("users")
                .document(userID)
                .collection("writingPlans")
                .document(planRemoteId)
                .collection("days")
        )

        return snapshot.documents.compactMap {
            makeAssignment(from: $0, userID: userID, fallbackPlanLocalId: planLocalId)
        }
    }

    func createPlan(from plan: ScriptureWritingPlan, for userID: String) async throws -> String {
        try validateUser(userID)

        let reference = database.collection("users")
            .document(userID)
            .collection("writingPlans")
            .document()

        var data = planData(from: plan, userID: userID)
        data["remoteId"] = reference.documentID
        data["lastSyncedAt"] = FieldValue.serverTimestamp()

        try await setData(data, on: reference, merge: false)
        return reference.documentID
    }

    func updatePlan(_ plan: ScriptureWritingPlan, for userID: String) async throws {
        try validateUser(userID)
        guard let remoteDocumentId = plan.remoteDocumentId, !remoteDocumentId.isEmpty else {
            throw FirestoreSyncError.notAuthenticated
        }

        let reference = database.collection("users")
            .document(userID)
            .collection("writingPlans")
            .document(remoteDocumentId)

        var data = planData(from: plan, userID: userID)
        data["remoteId"] = remoteDocumentId
        data["lastSyncedAt"] = FieldValue.serverTimestamp()
        try await setData(data, on: reference, merge: true)
    }

    func deletePlan(remoteDocumentId: String, for userID: String) async throws {
        try validateUser(userID)
        guard !remoteDocumentId.isEmpty else { return }

        let planDocument = database.collection("users")
            .document(userID)
            .collection("writingPlans")
            .document(remoteDocumentId)

        let daysSnapshot = try await getDocuments(planDocument.collection("days"))
        let batch = database.batch()
        for dayDocument in daysSnapshot.documents {
            batch.deleteDocument(dayDocument.reference)
        }
        batch.deleteDocument(planDocument)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func createAssignment(_ assignment: PlanDayAssignment, for userID: String, planRemoteId: String) async throws -> String {
        try validateUser(userID)
        guard !planRemoteId.isEmpty else {
            throw FirestoreSyncError.notAuthenticated
        }

        let reference = database.collection("users")
            .document(userID)
            .collection("writingPlans")
            .document(planRemoteId)
            .collection("days")
            .document()

        var data = assignmentData(from: assignment, userID: userID)
        data["remoteId"] = reference.documentID
        data["lastSyncedAt"] = FieldValue.serverTimestamp()

        try await setData(data, on: reference, merge: false)
        return reference.documentID
    }

    func updateAssignment(_ assignment: PlanDayAssignment, for userID: String, planRemoteId: String) async throws {
        try validateUser(userID)
        guard !planRemoteId.isEmpty,
              let remoteDocumentId = assignment.remoteDocumentId,
              !remoteDocumentId.isEmpty else {
            throw FirestoreSyncError.notAuthenticated
        }

        let reference = database.collection("users")
            .document(userID)
            .collection("writingPlans")
            .document(planRemoteId)
            .collection("days")
            .document(remoteDocumentId)

        var data = assignmentData(from: assignment, userID: userID)
        data["remoteId"] = remoteDocumentId
        data["lastSyncedAt"] = FieldValue.serverTimestamp()

        try await setData(data, on: reference, merge: true)
    }

    func deleteAssignment(remoteDocumentId: String, for userID: String, planRemoteId: String) async throws {
        try validateUser(userID)
        guard !planRemoteId.isEmpty, !remoteDocumentId.isEmpty else { return }

        let reference = database.collection("users")
            .document(userID)
            .collection("writingPlans")
            .document(planRemoteId)
            .collection("days")
            .document(remoteDocumentId)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func validateUser(_ userID: String) throws {
        guard let currentUID = Auth.auth().currentUser?.uid,
              !userID.isEmpty,
              currentUID == userID else {
            throw FirestoreSyncError.notAuthenticated
        }
    }

    private func getDocuments(_ query: Query) async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            query.getDocuments { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: FirestoreSyncError.invalidSnapshot)
                }
            }
        }
    }

    private func setData(_ data: [String: Any], on document: DocumentReference, merge: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.setData(data, merge: merge) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func planData(from plan: ScriptureWritingPlan, userID: String) -> [String: Any] {
        var data: [String: Any] = [
            "localId": plan.id.uuidString,
            "ownerUserId": userID,
            "title": plan.title,
            "book": plan.book,
            "startChapter": plan.startChapter,
            "endChapter": plan.endChapter,
            "startDate": Timestamp(date: plan.startDate),
            "endDate": Timestamp(date: plan.endDate),
            "totalDays": plan.totalDays,
            "totalVerses": plan.totalVerses,
            "completedDays": plan.completedDays,
            "statusRaw": plan.statusRaw,
            "createdAt": Timestamp(date: plan.createdAt),
            "updatedAt": Timestamp(date: plan.updatedAt)
        ]

        if let startVerse = plan.startVerse {
            data["startVerse"] = startVerse
        }
        if let endVerse = plan.endVerse {
            data["endVerse"] = endVerse
        }
        if let folderColorRaw = plan.folderColorRaw, !folderColorRaw.isEmpty {
            data["folderColorRaw"] = folderColorRaw
        }

        return data
    }

    private func assignmentData(from assignment: PlanDayAssignment, userID: String) -> [String: Any] {
        var data: [String: Any] = [
            "localId": assignment.id.uuidString,
            "planLocalId": assignment.planLocalId.uuidString,
            "ownerUserId": userID,
            "dayIndex": assignment.dayIndex,
            "date": Timestamp(date: assignment.date),
            "book": assignment.book,
            "startChapter": assignment.startChapter,
            "startVerse": assignment.startVerse,
            "endChapter": assignment.endChapter,
            "endVerse": assignment.endVerse,
            "verseCount": assignment.verseCount,
            "stateRaw": assignment.stateRaw,
            "completionRecordIds": assignment.completionRecordIds,
            "createdAt": Timestamp(date: assignment.createdAt),
            "updatedAt": Timestamp(date: assignment.updatedAt)
        ]

        if let completedAt = assignment.completedAt {
            data["completedAt"] = Timestamp(date: completedAt)
        }

        return data
    }

    private func makePlan(from document: QueryDocumentSnapshot, userID: String) -> ScriptureWritingPlan? {
        let data = document.data()
        guard let title = data["title"] as? String,
              let book = data["book"] as? String,
              let startChapter = data["startChapter"] as? Int,
              let endChapter = data["endChapter"] as? Int,
              let startDate = (data["startDate"] as? Timestamp)?.dateValue(),
              let endDate = (data["endDate"] as? Timestamp)?.dateValue(),
              let totalDays = data["totalDays"] as? Int,
              let totalVerses = data["totalVerses"] as? Int,
              let completedDays = data["completedDays"] as? Int,
              let statusRaw = data["statusRaw"] as? String,
              let status = ScriptureWritingPlanStatus(rawValue: statusRaw),
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else {
            return nil
        }

        return ScriptureWritingPlan(
            id: (data["localId"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID(),
            ownerUserId: (data["ownerUserId"] as? String) ?? userID,
            remoteDocumentId: document.documentID,
            lastSyncedAt: (data["lastSyncedAt"] as? Timestamp)?.dateValue() ?? Date(),
            title: title,
            book: book,
            startChapter: startChapter,
            endChapter: endChapter,
            startVerse: data["startVerse"] as? Int,
            endVerse: data["endVerse"] as? Int,
            startDate: startDate,
            endDate: endDate,
            totalDays: totalDays,
            totalVerses: totalVerses,
            completedDays: completedDays,
            folderColorRaw: data["folderColorRaw"] as? String,
            status: status,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private func makeAssignment(
        from document: QueryDocumentSnapshot,
        userID: String,
        fallbackPlanLocalId: UUID
    ) -> PlanDayAssignment? {
        let data = document.data()
        guard let dayIndex = data["dayIndex"] as? Int,
              let date = (data["date"] as? Timestamp)?.dateValue(),
              let book = data["book"] as? String,
              let startChapter = data["startChapter"] as? Int,
              let startVerse = data["startVerse"] as? Int,
              let endChapter = data["endChapter"] as? Int,
              let endVerse = data["endVerse"] as? Int,
              let verseCount = data["verseCount"] as? Int,
              let stateRaw = data["stateRaw"] as? String,
              let state = PlanAssignmentState(rawValue: stateRaw),
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else {
            return nil
        }

        return PlanDayAssignment(
            id: (data["localId"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID(),
            planLocalId: (data["planLocalId"] as? String).flatMap(UUID.init(uuidString:)) ?? fallbackPlanLocalId,
            ownerUserId: (data["ownerUserId"] as? String) ?? userID,
            remoteDocumentId: document.documentID,
            lastSyncedAt: (data["lastSyncedAt"] as? Timestamp)?.dateValue() ?? Date(),
            dayIndex: dayIndex,
            date: date,
            book: book,
            startChapter: startChapter,
            startVerse: startVerse,
            endChapter: endChapter,
            endVerse: endVerse,
            verseCount: verseCount,
            state: state,
            completedAt: (data["completedAt"] as? Timestamp)?.dateValue(),
            completionRecordIds: data["completionRecordIds"] as? [String] ?? [],
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
