import FirebaseAuth
import SwiftData
import SwiftUI

struct PrayerTemplateListView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var prayerSyncCoordinator: PrayerSyncCoordinator
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PrayerTemplate.updatedAt, order: .reverse) private var templates: [PrayerTemplate]

    @State private var editingTemplate: PrayerTemplate?
    @State private var deletingTemplate: PrayerTemplate?

    private var userTemplates: [PrayerTemplate] { templates.userTemplates(for: authViewModel.currentUser?.uid) }
    private var defaultTemplates: [PrayerTemplate] { templates.defaultTemplates }

    var body: some View {
        List {
            if !userTemplates.isEmpty {
                Section("내 기도문") {
                    ForEach(userTemplates) { template in
                        NavigationLink {
                            PrayerComposerView(template: template)
                        } label: {
                            templateRow(template)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("수정") { editingTemplate = template }
                                .tint(GardenTheme.primary)
                            Button("삭제", role: .destructive) { deletingTemplate = template }
                        }
                    }
                }
            }

            Section("앱 제공 기도문") {
                ForEach(defaultTemplates) { template in
                    NavigationLink {
                        PrayerComposerView(template: template)
                    } label: {
                        templateRow(template)
                    }
                }
            }
        }
        .navigationTitle("기도문")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PrayerTemplateEditorView()
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editingTemplate) { template in
            NavigationStack {
                PrayerTemplateEditorView(template: template)
            }
        }
        .alert("기도문을 삭제할까요?", isPresented: deleteAlertBinding) {
            Button("취소", role: .cancel) { deletingTemplate = nil }
            Button("삭제", role: .destructive) {
                confirmDeleteTemplate()
            }
        } message: {
            Text("기도문 템플릿이 삭제됩니다.")
        }
    }

    private func templateRow(_ template: PrayerTemplate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(template.title)
                .font(.headline)
            Text(template.bodyText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deletingTemplate != nil },
            set: { if !$0 { deletingTemplate = nil } }
        )
    }

    private func confirmDeleteTemplate() {
        guard let template = deletingTemplate else { return }
        deletingTemplate = nil
        Task {
            await prayerSyncCoordinator.deleteTemplateIfNeeded(
                localTemplateID: template.id,
                userID: authViewModel.currentUser?.uid,
                modelContext: modelContext
            )
        }
    }
}
