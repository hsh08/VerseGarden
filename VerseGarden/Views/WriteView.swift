import FirebaseAuth
import SwiftData
import SwiftUI

struct WriteView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var syncCoordinator: WritingRecordSyncCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let verse: VersePayload?
    private let sourceType: WritingSourceType

    @State private var userText = ""

    init(verse: BibleVerse?, sourceType: WritingSourceType = .direct) {
        self.verse = verse.map { VersePayload(id: $0.id, book: $0.book, chapter: $0.chapter, verse: $0.verse, text: $0.text) }
        self.sourceType = sourceType
    }

    init(localVerse: LocalBibleVerse, sourceType: WritingSourceType = .direct) {
        self.verse = VersePayload(
            id: "local-\(localVerse.id)",
            book: localVerse.book,
            chapter: localVerse.chapter,
            verse: localVerse.verse,
            text: localVerse.text
        )
        self.sourceType = sourceType
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                verseSection
                inputSection
                completeButton
            }
            .padding()
        }
        .navigationTitle("필사하기")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
    }

    private var verseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("원문")
                .font(.headline)

            if let verse {
                Text(verse.text)
                    .font(.body)
                    .lineSpacing(6)

                Text("\(verse.book) \(verse.chapter):\(verse.verse)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("표시할 구절이 없습니다.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("직접 입력")
                .font(.headline)

            TextEditor(text: $userText)
                .frame(minHeight: 220)
                .padding(8)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.green.opacity(0.25), lineWidth: 1)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var completeButton: some View {
        Button {
            saveRecord()
        } label: {
            Text("완료")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSave ? Color.green : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .disabled(!canSave || verse == nil)
    }

    private var canSave: Bool {
        !userText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveRecord() {
        guard let verse else { return }

        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let now = Date()
        let record = WritingRecord(
            ownerUserId: authViewModel.currentUser?.uid ?? "",
            date: Calendar.current.startOfDay(for: now),
            verseId: verse.id,
            book: verse.book,
            chapter: verse.chapter,
            verse: verse.verse,
            originalText: verse.text,
            userText: trimmed,
            completedAt: now,
            sourceType: sourceType.rawValue
        )

        modelContext.insert(record)
        try? modelContext.save()

        if let userID = authViewModel.currentUser?.uid {
            Task { @MainActor in
                await syncCoordinator.uploadRecordIfNeeded(
                    localRecordID: record.id,
                    userID: userID,
                    modelContext: modelContext
                )
            }
        }

        dismiss()
    }
}

enum WritingSourceType: String {
    case direct
    case theme
    case monthly
    case customList
}

private struct VersePayload {
    let id: String
    let book: String
    let chapter: Int
    let verse: Int
    let text: String
}
