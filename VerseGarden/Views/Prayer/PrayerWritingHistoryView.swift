import FirebaseAuth
import SwiftData
import SwiftUI

struct PrayerWritingHistoryView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var prayerSyncCoordinator: PrayerSyncCoordinator
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PrayerWritingRecord.completedAt, order: .reverse) private var records: [PrayerWritingRecord]

    @State private var deletingRecord: PrayerWritingRecord?

    private var currentUserRecords: [PrayerWritingRecord] {
        records.records(for: authViewModel.currentUser?.uid)
    }

    var body: some View {
        List {
            ForEach(currentUserRecords) { record in
                NavigationLink {
                    PrayerComposerView(record: record)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(record.titleSnapshot)
                                .font(.headline)
                            Spacer()
                            Text(record.completedAt.formatted(.dateTime.month().day()))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(record.userText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(edge: .trailing) {
                    Button("삭제", role: .destructive) {
                        deletingRecord = record
                    }
                }
            }
        }
        .navigationTitle("기도 기록")
        .alert("기록을 삭제할까요?", isPresented: deleteAlertBinding) {
            Button("취소", role: .cancel) {
                deletingRecord = nil
            }
            Button("삭제", role: .destructive) {
                confirmDeleteRecord()
            }
        } message: {
            Text("기도 기록이 삭제됩니다.")
        }
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deletingRecord != nil },
            set: { if !$0 { deletingRecord = nil } }
        )
    }

    private func confirmDeleteRecord() {
        guard let deletingRecord else { return }
        self.deletingRecord = nil
        Task {
            await prayerSyncCoordinator.deleteRecordIfNeeded(
                localRecordID: deletingRecord.id,
                userID: authViewModel.currentUser?.uid,
                modelContext: modelContext
            )
        }
    }
}
