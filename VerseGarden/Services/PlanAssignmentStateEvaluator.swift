import Foundation
import SwiftData

enum PlanAssignmentStateEvaluator {
    static func refreshStates(
        userID: String?,
        modelContext: ModelContext,
        calendar: Calendar = .current
    ) {
        guard let userID else { return }

        let plansDescriptor = FetchDescriptor<ScriptureWritingPlan>()
        let assignmentsDescriptor = FetchDescriptor<PlanDayAssignment>()

        guard let plans = try? modelContext.fetch(plansDescriptor).plans(for: userID),
              let assignments = try? modelContext.fetch(assignmentsDescriptor).assignments(for: userID) else {
            return
        }

        let today = calendar.startOfDay(for: Date())
        var didChange = false

        for plan in plans {
            let planAssignments = assignments.filter { $0.planLocalId == plan.id }

            for assignment in planAssignments where assignment.state != .completed {
                if plan.status == .active {
                    let shouldBeMissed = assignment.date < today
                    if shouldBeMissed && assignment.state != .missed {
                        assignment.state = .missed
                        assignment.updatedAt = Date()
                        didChange = true
                    } else if !shouldBeMissed && assignment.state != .pending {
                        assignment.state = .pending
                        assignment.updatedAt = Date()
                        didChange = true
                    }
                }
            }

            let completedCount = planAssignments.filter { $0.state == .completed }.count
            if plan.completedDays != completedCount {
                plan.completedDays = completedCount
                plan.updatedAt = Date()
                didChange = true
            }

            if plan.status == .active && completedCount == plan.totalDays {
                plan.status = .completed
                plan.updatedAt = Date()
                didChange = true
            }
        }

        if didChange {
            try? modelContext.save()
        }
    }
}
