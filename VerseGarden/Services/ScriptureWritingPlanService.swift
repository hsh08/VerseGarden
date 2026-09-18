import Foundation
import SwiftData

enum ScriptureWritingPlanService {
    private static let service = BibleDataService.shared

    struct PlanStatusSections {
        let active: [ScriptureWritingPlan]
        let paused: [ScriptureWritingPlan]
        let completed: [ScriptureWritingPlan]
        let cancelled: [ScriptureWritingPlan]
    }

    static func activePlan(from plans: [ScriptureWritingPlan], userID: String?) -> ScriptureWritingPlan? {
        plans
            .plans(for: userID)
            .filter { $0.status == .active }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    static func pausedPlan(from plans: [ScriptureWritingPlan], userID: String?) -> ScriptureWritingPlan? {
        plans
            .plans(for: userID)
            .filter { $0.status == .paused }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    static func blockingPlan(from plans: [ScriptureWritingPlan], userID: String?) -> ScriptureWritingPlan? {
        plans
            .plans(for: userID)
            .filter { !$0.status.isTerminal }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    static func groupedPlans(from plans: [ScriptureWritingPlan], userID: String?) -> PlanStatusSections {
        let filtered = plans.plans(for: userID).sorted { lhs, rhs in
            if lhs.status == rhs.status {
                return lhs.updatedAt > rhs.updatedAt
            }
            return lhs.createdAt > rhs.createdAt
        }

        return PlanStatusSections(
            active: filtered.filter { $0.status == .active },
            paused: filtered.filter { $0.status == .paused },
            completed: filtered.filter { $0.status == .completed },
            cancelled: filtered.filter { $0.status == .cancelled }
        )
    }

    static func assignments(
        for plan: ScriptureWritingPlan,
        from assignments: [PlanDayAssignment],
        userID: String?
    ) -> [PlanDayAssignment] {
        assignments
            .assignments(for: userID)
            .filter { $0.planLocalId == plan.id }
            .sorted { $0.dayIndex < $1.dayIndex }
    }

    static func todayAssignment(
        for plan: ScriptureWritingPlan,
        assignments: [PlanDayAssignment],
        userID: String?,
        calendar: Calendar = .current
    ) -> PlanDayAssignment? {
        let today = calendar.startOfDay(for: Date())
        return self.assignments(for: plan, from: assignments, userID: userID)
            .first { calendar.isDate($0.date, inSameDayAs: today) }
    }

    static func latestMissedAssignment(
        for plan: ScriptureWritingPlan,
        assignments: [PlanDayAssignment],
        userID: String?
    ) -> PlanDayAssignment? {
        self.assignments(for: plan, from: assignments, userID: userID)
            .filter { $0.state == .missed }
            .sorted { $0.date > $1.date }
            .first
    }

    static func nextIncompleteAssignment(
        for plan: ScriptureWritingPlan,
        assignments: [PlanDayAssignment],
        userID: String?
    ) -> PlanDayAssignment? {
        self.assignments(for: plan, from: assignments, userID: userID)
            .first { $0.state != .completed }
    }

    static func missedCount(
        for plan: ScriptureWritingPlan,
        assignments: [PlanDayAssignment],
        userID: String?
    ) -> Int {
        self.assignments(for: plan, from: assignments, userID: userID)
            .filter { $0.state == .missed }
            .count
    }

    static func verses(for assignment: PlanDayAssignment) -> [LocalBibleVerse] {
        var resolved: [LocalBibleVerse] = []

        if assignment.startChapter == assignment.endChapter {
            resolved = service.getVerses(book: assignment.book, chapter: assignment.startChapter)
                .filter { $0.verse >= assignment.startVerse && $0.verse <= assignment.endVerse }
        } else {
            for chapter in assignment.startChapter...assignment.endChapter {
                let verses = service.getVerses(book: assignment.book, chapter: chapter).filter { verse in
                    if chapter == assignment.startChapter {
                        return verse.verse >= assignment.startVerse
                    }
                    if chapter == assignment.endChapter {
                        return verse.verse <= assignment.endVerse
                    }
                    return true
                }
                resolved.append(contentsOf: verses)
            }
        }

        return resolved
    }

    static func rangeText(for assignment: PlanDayAssignment) -> String {
        if assignment.startChapter == assignment.endChapter {
            if assignment.startVerse == assignment.endVerse {
                return "\(assignment.book) \(assignment.startChapter):\(assignment.startVerse)"
            }
            return "\(assignment.book) \(assignment.startChapter):\(assignment.startVerse)–\(assignment.endVerse)"
        }

        return "\(assignment.book) \(assignment.startChapter):\(assignment.startVerse)–\(assignment.endChapter):\(assignment.endVerse)"
    }

    static func planRangeText(for plan: ScriptureWritingPlan) -> String {
        plan.startChapter == plan.endChapter
            ? "\(plan.book) \(plan.startChapter)장"
            : "\(plan.book) \(plan.startChapter)–\(plan.endChapter)장"
    }

    static func displayDayIndex(
        for plan: ScriptureWritingPlan,
        assignments: [PlanDayAssignment],
        userID: String?,
        calendar: Calendar = .current
    ) -> Int {
        if let today = todayAssignment(for: plan, assignments: assignments, userID: userID, calendar: calendar) {
            return today.dayIndex
        }
        if let next = nextIncompleteAssignment(for: plan, assignments: assignments, userID: userID) {
            return next.dayIndex
        }
        return min(max(plan.completedDays, 1), max(plan.totalDays, 1))
    }

    static func nextAssignmentDisplayText(
        for plan: ScriptureWritingPlan,
        assignments: [PlanDayAssignment],
        userID: String?,
        calendar: Calendar = .current
    ) -> String? {
        if let today = todayAssignment(for: plan, assignments: assignments, userID: userID, calendar: calendar) {
            return "오늘: \(rangeText(for: today))"
        }
        if let next = nextIncompleteAssignment(for: plan, assignments: assignments, userID: userID) {
            let dateText = next.date.formatted(.dateTime.month().day())
            return "\(dateText) · \(rangeText(for: next))"
        }
        return nil
    }

    static func canStartAssignment(_ assignment: PlanDayAssignment, in plan: ScriptureWritingPlan) -> Bool {
        plan.status == .active && assignment.state != .completed
    }

    static func createPlan(
        preview: ScriptureWritingPlanPreview,
        userID: String,
        existingPlans: [ScriptureWritingPlan],
        modelContext: ModelContext,
        folderColorRaw: String? = nil
    ) throws -> UUID {
        let (plan, assignments) = ScriptureWritingPlanBuilder.createPlan(
            ownerUserId: userID,
            preview: preview,
            folderColorRaw: folderColorRaw
        )
        modelContext.insert(plan)
        assignments.forEach { modelContext.insert($0) }
        try modelContext.save()
        return plan.id
    }

    static func recordSavedVerse(
        planID: UUID,
        assignmentID: UUID,
        recordID: UUID,
        isFinalVerse: Bool,
        modelContext: ModelContext
    ) throws {
        let assignmentDescriptor = FetchDescriptor<PlanDayAssignment>(
            predicate: #Predicate { $0.id == assignmentID }
        )
        guard let assignment = try modelContext.fetch(assignmentDescriptor).first else { return }

        let recordIDString = recordID.uuidString
        var completionRecordIds = assignment.completionRecordIds
        if !completionRecordIds.contains(recordIDString) {
            completionRecordIds.append(recordIDString)
            assignment.completionRecordIds = completionRecordIds
            assignment.updatedAt = Date()
        }

        if isFinalVerse && assignment.state != .completed {
            assignment.state = .completed
            assignment.completedAt = Date()
            assignment.updatedAt = Date()
        }

        let planDescriptor = FetchDescriptor<ScriptureWritingPlan>(
            predicate: #Predicate { $0.id == planID }
        )
        guard let plan = try modelContext.fetch(planDescriptor).first else {
            try modelContext.save()
            return
        }

        let allAssignmentsDescriptor = FetchDescriptor<PlanDayAssignment>(
            predicate: #Predicate { $0.planLocalId == planID }
        )
        let allAssignments = try modelContext.fetch(allAssignmentsDescriptor)
        let completedCount = allAssignments.filter { $0.state == .completed }.count
        plan.completedDays = completedCount
        if completedCount == plan.totalDays {
            plan.status = .completed
        }
        plan.updatedAt = Date()

        try modelContext.save()
    }

    static func pausePlan(_ plan: ScriptureWritingPlan, modelContext: ModelContext) throws {
        guard plan.status == .active else { return }
        plan.status = .paused
        plan.updatedAt = Date()
        try modelContext.save()
    }

    static func resumePlan(
        _ plan: ScriptureWritingPlan,
        userID: String?,
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws {
        guard plan.status == .paused else { return }
        plan.status = .active
        plan.updatedAt = Date()
        try modelContext.save()
        PlanAssignmentStateEvaluator.refreshStates(userID: userID, modelContext: modelContext, calendar: calendar)
    }

    static func deletePlan(
        _ plan: ScriptureWritingPlan,
        userID: String?,
        modelContext: ModelContext
    ) throws {
        let assignments = try fetchAssignments(for: plan, userID: userID, modelContext: modelContext)
        assignments.forEach { modelContext.delete($0) }
        modelContext.delete(plan)
        try modelContext.save()
    }

    static func assignmentCounts(for plan: ScriptureWritingPlan, assignments: [PlanDayAssignment], userID: String?) -> (completed: Int, missed: Int, pending: Int) {
        let items = self.assignments(for: plan, from: assignments, userID: userID)
        return (
            completed: items.filter { $0.state == .completed }.count,
            missed: items.filter { $0.state == .missed }.count,
            pending: items.filter { $0.state == .pending }.count
        )
    }

    static func launchContext(
        for assignment: PlanDayAssignment,
        plan: ScriptureWritingPlan
    ) -> (verse: LocalBibleVerse, context: WritingContext)? {
        let verses = verses(for: assignment)
        guard !verses.isEmpty else { return nil }
        let completedVerseCount = assignment.completionRecordIds.count
        let safeStartIndex = min(completedVerseCount, max(verses.count - 1, 0))
        guard let verse = verses[safe: safeStartIndex] else { return nil }
        return (
            verse,
            .plan(
                planId: plan.id,
                assignmentId: assignment.id,
                verses: verses,
                currentIndex: safeStartIndex
            )
        )
    }

    static func updatePlanTitle(
        _ plan: ScriptureWritingPlan,
        title: String,
        modelContext: ModelContext
    ) throws {
        plan.title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? plan.title : title.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.updatedAt = Date()
        try modelContext.save()
    }

    /// A saved verse is user content even when its day has not yet reached the
    /// completed state. Regenerating such an assignment would orphan its record.
    static func hasWritingHistory(
        for plan: ScriptureWritingPlan,
        assignments: [PlanDayAssignment],
        userID: String?
    ) -> Bool {
        self.assignments(for: plan, from: assignments, userID: userID)
            .contains { $0.state == .completed || !$0.completionRecordIds.isEmpty }
    }

    static func canModifyRangeOrStartDate(
        for plan: ScriptureWritingPlan,
        assignments: [PlanDayAssignment],
        userID: String?
    ) -> Bool {
        !hasWritingHistory(for: plan, assignments: assignments, userID: userID)
    }

    static func canExtendDuration(
        for plan: ScriptureWritingPlan,
        assignments: [PlanDayAssignment],
        userID: String?
    ) -> Bool {
        (plan.status == .active || plan.status == .paused)
            && !hasWritingHistory(for: plan, assignments: assignments, userID: userID)
    }

    static func minimumAllowedDuration(
        for plan: ScriptureWritingPlan,
        assignments: [PlanDayAssignment],
        userID: String?,
        calendar: Calendar = .current
    ) -> Int {
        guard hasWritingHistory(for: plan, assignments: assignments, userID: userID) else {
            return 1
        }
        let completedCount = self.assignments(for: plan, from: assignments, userID: userID)
            .filter { $0.state == .completed }
            .count
        let currentDayIndex = displayDayIndex(
            for: plan,
            assignments: assignments,
            userID: userID,
            calendar: calendar
        )
        return max(completedCount, currentDayIndex, 1)
    }

    static func hasCompletedAssignments(
        for plan: ScriptureWritingPlan,
        assignments: [PlanDayAssignment],
        userID: String?
    ) -> Bool {
        self.assignments(for: plan, from: assignments, userID: userID)
            .contains { $0.state == .completed }
    }

    static func endPlan(_ plan: ScriptureWritingPlan, modelContext: ModelContext) throws {
        guard !plan.status.isTerminal else { return }
        plan.status = .cancelled
        plan.updatedAt = Date()
        try modelContext.save()
    }

    static func applyEdits(
        to plan: ScriptureWritingPlan,
        userID: String?,
        newTitle: String,
        newStartDate: Date,
        newBook: String,
        newStartChapter: Int,
        newEndChapter: Int,
        newTotalDays: Int,
        newFolderColorRaw: String?,
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) throws {
        let userID = userID ?? plan.ownerUserId
        let assignments = try fetchAssignments(for: plan, userID: userID, modelContext: modelContext)
        let hasWritingHistory = hasWritingHistory(for: plan, assignments: assignments, userID: userID)
        let isRangeChanged = plan.book != newBook || plan.startChapter != newStartChapter || plan.endChapter != newEndChapter
        let isStartDateChanged = !calendar.isDate(plan.startDate, inSameDayAs: newStartDate)
        let isDurationChanged = plan.totalDays != newTotalDays
        let minimumDuration = minimumAllowedDuration(
            for: plan,
            assignments: assignments,
            userID: userID,
            calendar: calendar
        )

        plan.title = newTitle
        plan.folderColorRaw = newFolderColorRaw

        if !isRangeChanged && !isStartDateChanged && !isDurationChanged {
            plan.updatedAt = Date()
            try modelContext.save()
            return
        }

        if newTotalDays < minimumDuration {
            throw ScriptureWritingPlanLocalError.durationReductionBlocked
        }

        if hasWritingHistory {
            if isRangeChanged || isStartDateChanged || isDurationChanged {
                throw ScriptureWritingPlanLocalError.unsafeRegeneration
            }
            plan.updatedAt = Date()
            try modelContext.save()
            return
        }

        let preview = try ScriptureWritingPlanBuilder.buildPreview(
            book: newBook,
            startChapter: newStartChapter,
            endChapter: newEndChapter,
            startDate: calendar.startOfDay(for: newStartDate),
            totalDays: newTotalDays
        )

        assignments.forEach { modelContext.delete($0) }
        plan.title = newTitle
        plan.book = preview.book
        plan.startChapter = preview.startChapter
        plan.endChapter = preview.endChapter
        plan.startDate = preview.startDate
        plan.endDate = preview.endDate
        plan.totalDays = preview.totalDays
        plan.totalVerses = preview.totalVerses
        plan.completedDays = 0
        plan.updatedAt = Date()

        preview.verseSlices.forEach { slice in
            modelContext.insert(
                PlanDayAssignment(
                    planLocalId: plan.id,
                    ownerUserId: userID,
                    dayIndex: slice.dayIndex,
                    date: slice.date,
                    book: preview.book,
                    startChapter: slice.startChapter,
                    startVerse: slice.startVerse,
                    endChapter: slice.endChapter,
                    endVerse: slice.endVerse,
                    verseCount: slice.verseCount,
                    state: .pending
                )
            )
        }

        try modelContext.save()
    }

    private static func extendPlanDuration(
        _ plan: ScriptureWritingPlan,
        assignments: [PlanDayAssignment],
        userID: String,
        newTotalDays: Int,
        modelContext: ModelContext,
        calendar: Calendar
    ) throws {
        guard canExtendDuration(for: plan, assignments: assignments, userID: userID) else {
            throw ScriptureWritingPlanLocalError.durationExtensionBlocked
        }

        let sortedAssignments = assignments.sorted { $0.dayIndex < $1.dayIndex }
        let completedAssignments = sortedAssignments.filter { $0.state == .completed }
        let completedDayCount = completedAssignments.count
        let expectedCompletedIndexes = Array(1...completedDayCount)
        let actualCompletedIndexes = completedAssignments.map(\.dayIndex)
        guard actualCompletedIndexes == expectedCompletedIndexes else {
            throw ScriptureWritingPlanLocalError.unsafeRegeneration
        }

        let allVerses = try ScriptureWritingPlanBuilder.verses(
            book: plan.book,
            startChapter: plan.startChapter,
            endChapter: plan.endChapter
        )
        let completedVerseCount = completedAssignments.reduce(0) { $0 + $1.verseCount }
        let remainingVerses = Array(allVerses.dropFirst(completedVerseCount))
        let remainingDayCount = newTotalDays - completedDayCount
        guard remainingDayCount > 0, remainingDayCount <= remainingVerses.count else {
            throw ScriptureWritingPlanLocalError.durationExtensionBlocked
        }

        sortedAssignments
            .filter { $0.state != .completed }
            .forEach { modelContext.delete($0) }

        let remainingStartDate = calendar.date(byAdding: .day, value: completedDayCount, to: calendar.startOfDay(for: plan.startDate)) ?? plan.startDate
        let rebuilt = ScriptureWritingPlanBuilder.slices(
            from: remainingVerses,
            startDate: remainingStartDate,
            totalDays: remainingDayCount,
            calendar: calendar
        )

        rebuilt.slices.forEach { slice in
            modelContext.insert(
                PlanDayAssignment(
                    planLocalId: plan.id,
                    ownerUserId: userID,
                    dayIndex: completedDayCount + slice.dayIndex,
                    date: slice.date,
                    book: plan.book,
                    startChapter: slice.startChapter,
                    startVerse: slice.startVerse,
                    endChapter: slice.endChapter,
                    endVerse: slice.endVerse,
                    verseCount: slice.verseCount,
                    state: .pending
                )
            )
        }

        plan.totalDays = newTotalDays
        plan.endDate = calendar.date(byAdding: .day, value: max(newTotalDays - 1, 0), to: calendar.startOfDay(for: plan.startDate)) ?? plan.endDate
    }

    private static func fetchAssignments(
        for plan: ScriptureWritingPlan,
        userID: String?,
        modelContext: ModelContext
    ) throws -> [PlanDayAssignment] {
        try modelContext.fetch(FetchDescriptor<PlanDayAssignment>())
            .assignments(for: userID)
            .filter { $0.planLocalId == plan.id }
            .sorted { $0.dayIndex < $1.dayIndex }
    }
}

enum ScriptureWritingPlanLocalError: LocalizedError {
    case blockingPlanExists
    case unsafeRegeneration
    case durationReductionBlocked
    case durationExtensionBlocked

    var errorDescription: String? {
        switch self {
        case .blockingPlanExists:
            return "진행 중인 필사 플랜이 있습니다."
        case .unsafeRegeneration:
            return "이미 진행한 기록이 있어 이 항목은 수정할 수 없습니다."
        case .durationReductionBlocked:
            return "진행 중인 플랜은 기간을 줄일 수 없습니다."
        case .durationExtensionBlocked:
            return "현재 진행 상태에서는 기간 연장이 안전하지 않습니다."
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
