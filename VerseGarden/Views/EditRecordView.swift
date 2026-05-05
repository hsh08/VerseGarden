import FirebaseAuth
import SwiftData
import SwiftUI

struct EditRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var syncCoordinator: WritingRecordSyncCoordinator

    let record: WritingRecord

    @State private var draftText: String
    @State private var showingDeleteConfirmation = false

    init(record: WritingRecord) {
        self.record = record
        _draftText = State(initialValue: record.userText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(record.book) \(record.chapter):\(record.verse)")
                    .font(.headline)
                Text("원문은 유지하고 내가 쓴 내용만 수정합니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("원문")
                    .font(.subheadline.weight(.semibold))
                Text(record.originalText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("내가 쓴 내용")
                    .font(.subheadline.weight(.semibold))

                TextEditor(text: $draftText)
                    .frame(minHeight: 220)
                    .padding(8)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.green.opacity(0.25), lineWidth: 1)
                    }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Spacer()
        }
        .padding()
        .navigationTitle("기록 수정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("취소") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button("저장") {
                    save()
                }
                .disabled(trimmedText.isEmpty)
            }

            ToolbarItem(placement: .bottomBar) {
                Button("삭제", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .alert("삭제하시겠습니까?", isPresented: $showingDeleteConfirmation) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                deleteRecord()
            }
        } message: {
            Text("선택한 필사 기록이 삭제됩니다.")
        }
    }

    private var trimmedText: String {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmedText.isEmpty else { return }

        record.userText = trimmedText
        try? modelContext.save()
        dismiss()
    }

    private func deleteRecord() {
        let remoteDocumentId = record.remoteDocumentId
        let ownerUserId = record.ownerUserId

        modelContext.delete(record)
        try? modelContext.save()
        dismiss()

        Task {
            await syncCoordinator.deleteRecordIfNeeded(
                remoteDocumentId: remoteDocumentId,
                ownerUserId: ownerUserId,
                userID: authViewModel.currentUser?.uid
            )
        }
    }
}
