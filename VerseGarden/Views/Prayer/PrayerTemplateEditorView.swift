import FirebaseAuth
import SwiftData
import SwiftUI

struct PrayerTemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var prayerSyncCoordinator: PrayerSyncCoordinator

    private let template: PrayerTemplate?
    @State private var title: String
    @State private var bodyText: String
    @State private var category: String

    init(template: PrayerTemplate? = nil) {
        self.template = template
        _title = State(initialValue: template?.title ?? "")
        _bodyText = State(initialValue: template?.bodyText ?? "")
        _category = State(initialValue: template?.category ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                GardenCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("기도문 정보")
                            .font(.headline)
                        TextField("제목", text: $title)
                            .textFieldStyle(.roundedBorder)
                        TextField("카테고리 (선택)", text: $category)
                            .textFieldStyle(.roundedBorder)
                        TextEditor(text: $bodyText)
                            .frame(minHeight: 220)
                            .padding(10)
                            .background(GardenTheme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle(template == nil ? "기도문 만들기" : "기도문 수정")
        .background(GardenTheme.background)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") { save() }
                    .disabled(trimmedTitle.count < 2 || trimmedBody.count < 2)
            }
        }
    }

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedBody: String { bodyText.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func save() {
        guard trimmedTitle.count >= 2, trimmedBody.count >= 2 else { return }
        if let template {
            template.title = trimmedTitle
            template.bodyText = trimmedBody
            template.category = category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : category.trimmingCharacters(in: .whitespacesAndNewlines)
            template.updatedAt = Date()
            try? modelContext.save()
            if let userID = authViewModel.currentUser?.uid {
                Task {
                    await prayerSyncCoordinator.updateTemplateIfNeeded(
                        localTemplateID: template.id,
                        userID: userID,
                        modelContext: modelContext
                    )
                }
            }
        } else {
            let newTemplate = PrayerTemplate(
                ownerUserId: authViewModel.currentUser?.uid ?? "",
                title: trimmedTitle,
                bodyText: trimmedBody,
                category: category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : category.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            modelContext.insert(newTemplate)
            try? modelContext.save()
            if let userID = authViewModel.currentUser?.uid {
                Task {
                    await prayerSyncCoordinator.uploadTemplateIfNeeded(
                        localTemplateID: newTemplate.id,
                        userID: userID,
                        modelContext: modelContext
                    )
                }
            }
        }
        dismiss()
    }
}
