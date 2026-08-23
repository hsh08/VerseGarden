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
                Text("원문")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(record.originalText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(5)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardTint)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("내가 쓴 내용")
                    .font(.subheadline.weight(.semibold))

                TextEditor(text: $draftText)
                    .frame(minHeight: 220)
                    .padding(8)
                    .background(GardenTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(GardenTheme.primary.opacity(0.25), lineWidth: 1)
                    }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardTint)
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
        }
        .safeAreaInset(edge: .bottom) {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("삭제")
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.12))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.red.opacity(0.28), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .foregroundStyle(.red)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(GardenTheme.background)
        }
        .background(GardenTheme.background)
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

        if let userID = authViewModel.currentUser?.uid {
            Task {
                await syncCoordinator.updateRecordIfNeeded(
                    localRecordID: record.id,
                    userID: userID,
                    modelContext: modelContext
                )
            }
        }

        dismiss()
    }

    private func deleteRecord() {
        let remoteDocumentId = record.remoteDocumentId
        let ownerUserId = record.ownerUserId
        let record = record

        Task {
            let didDeleteRemote = await syncCoordinator.deleteRecordIfNeeded(
                remoteDocumentId: remoteDocumentId,
                ownerUserId: ownerUserId,
                userID: authViewModel.currentUser?.uid
            )
            guard didDeleteRemote else { return }
            modelContext.delete(record)
            try? modelContext.save()
            dismiss()
        }
    }
}
