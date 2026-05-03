import FirebaseAuth
import SwiftData
import SwiftUI

struct CreateMyVerseListView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var verseListSyncCoordinator: VerseListSyncCoordinator

    private let list: MyVerseList?
    @State private var title = ""
    @State private var memo = ""

    init(list: MyVerseList? = nil) {
        self.list = list
        _title = State(initialValue: list?.title ?? "")
        _memo = State(initialValue: list?.memo ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                inputCard
            }
            .padding()
        }
        .navigationTitle(list == nil ? "리스트 만들기" : "리스트 수정")
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
                .disabled(trimmedTitle.isEmpty)
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("리스트 정보")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("제목")
                    .font(.subheadline.weight(.semibold))
                TextField("예: 시험기간 암송 구절", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("메모")
                    .font(.subheadline.weight(.semibold))
                TextField("리스트 설명을 남겨보세요", text: $memo, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...5)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedMemo: String {
        memo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmedTitle.isEmpty else { return }

        if let list {
            list.title = trimmedTitle
            list.memo = trimmedMemo
            list.updatedAt = Date()
        } else {
            let newList = MyVerseList(
                title: trimmedTitle,
                memo: trimmedMemo,
                ownerUserId: authViewModel.currentUser?.uid ?? "",
                updatedAt: Date()
            )
            modelContext.insert(newList)
            try? modelContext.save()

            if authViewModel.currentUser != nil {
                Task {
                    await verseListSyncCoordinator.uploadListIfNeeded(
                        localListID: newList.id,
                        userID: authViewModel.currentUser?.uid,
                        modelContext: modelContext
                    )
                }
            }
            dismiss()
            return
        }
        try? modelContext.save()
        dismiss()
    }
}
