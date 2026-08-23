import Combine
import Foundation

final class WritingPlanSelectionStore: ObservableObject {
    @Published private(set) var selectedPlanId: String?
    var onSelectionChanged: ((String?) -> Void)?

    private let defaults: UserDefaults
    private let baseStorageKey = "versegarden_selected_writing_plan_id"
    private var activeUserID: String?
    private var isApplyingSync = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadSelection()
    }

    func setActiveUserID(_ userID: String?) {
        guard activeUserID != userID else { return }
        activeUserID = userID
        loadSelection()
    }

    func selectPlan(_ plan: ScriptureWritingPlan?) {
        setSelection(plan?.id.uuidString)
    }

    func applyRemoteSelection(_ planId: String?) {
        isApplyingSync = true
        setSelection(planId)
        isApplyingSync = false
    }

    private func loadSelection() {
        selectedPlanId = defaults.string(forKey: storageKey)
    }

    private func setSelection(_ planId: String?) {
        let normalizedPlanId = planId?.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedPlanId = normalizedPlanId?.isEmpty == true ? nil : normalizedPlanId
        persistSelection()
        notifySelectionChanged()
    }

    private func persistSelection() {
        if let selectedPlanId {
            defaults.set(selectedPlanId, forKey: storageKey)
        } else {
            defaults.removeObject(forKey: storageKey)
        }
    }

    private func notifySelectionChanged() {
        guard !isApplyingSync else { return }
        onSelectionChanged?(selectedPlanId)
    }

    private var storageKey: String {
        guard let activeUserID, !activeUserID.isEmpty else {
            return baseStorageKey
        }
        return "\(baseStorageKey)_\(activeUserID)"
    }
}
