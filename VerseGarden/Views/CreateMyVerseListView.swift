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
    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case memo
    }

    init(list: MyVerseList? = nil) {
        self.list = list
        _title = State(initialValue: list?.title ?? "")
        _memo = State(initialValue: list?.memo ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                    introCard
                    inputCard
                    previewCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 120)
            }
            bottomCTA
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
        .background(GardenTheme.background)
    }

    private var introCard: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.84), GardenTheme.secondary.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Image(systemName: "bookmark.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text("나만의 말씀 리스트")
                        .font(.title3.bold())
                    Text("위로, 시험기간, 기도, 좌우명 등\n원하는 주제로 말씀을 모아보세요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
            }
        }
        .shadow(color: GardenTheme.primary.opacity(0.08), radius: 18, y: 8)
    }

    private var inputCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 16) {
                GardenSectionHeader("리스트 정보", subtitle: "언제든 새로운 말씀을 추가할 수 있어요.")

                VStack(alignment: .leading, spacing: 8) {
                    labelRow("제목", icon: "textformat")
                    TextField("예: 시험기간 암송 말씀", text: $title)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .title)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .background(fieldBackground(isFocused: focusedField == .title))
                }

                VStack(alignment: .leading, spacing: 8) {
                    labelRow("메모", icon: "quote.bubble")
                    TextField("리스트에 담고 싶은 마음이나 설명을 남겨보세요", text: $memo, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .memo)
                        .lineLimit(4...6)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .background(fieldBackground(isFocused: focusedField == .memo))
                }
            }
        }
    }

    @ViewBuilder
    private var previewCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                GardenSectionHeader("미리보기", subtitle: trimmedTitle.isEmpty ? "이 리스트는 아직 비어 있어요." : "이름만 정해도 차분하게 시작할 수 있어요.")

                if trimmedTitle.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "bookmark")
                            .foregroundStyle(.secondary)
                        Text("제목을 입력하면 리스트 이름이 여기에도 보여요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack {
                        Text(trimmedTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GardenTheme.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(GardenTheme.primary.opacity(0.1))
                            .clipShape(Capsule())
                        Spacer()
                    }

                    if !trimmedMemo.isEmpty {
                        Text(trimmedMemo)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }
                }
            }
        }
    }

    private var bottomCTA: some View {
        VStack(spacing: 0) {
            Divider()
                .opacity(0.4)

            Button {
                save()
            } label: {
                HStack {
                    Image(systemName: trimmedTitle.isEmpty ? "bookmark" : "bookmark.fill")
                        .font(.title3)
                    Text(list == nil ? "리스트 저장하기" : "리스트 수정하기")
                        .font(.headline)
                    Spacer()
                }
                .foregroundStyle(trimmedTitle.isEmpty ? Color.secondary : .white)
                .padding()
                .background(
                    Group {
                        if trimmedTitle.isEmpty {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(AppColors.cardTint)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(GardenTheme.primary.opacity(0.14), lineWidth: 1)
                                }
                        } else {
                            LinearGradient(
                                colors: [GardenTheme.primary, GardenTheme.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(GardenAccentButtonStyle())
            .disabled(trimmedTitle.isEmpty)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 18)
            .background(.ultraThinMaterial)
        }
    }

    private func labelRow(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(GardenTheme.primary)
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func fieldBackground(isFocused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(GardenTheme.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isFocused ? GardenTheme.primary.opacity(0.34) : GardenTheme.primary.opacity(0.12),
                        lineWidth: isFocused ? 1.4 : 1
                    )
            }
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
            try? modelContext.save()

            if authViewModel.currentUser != nil {
                Task {
                    await verseListSyncCoordinator.updateListIfNeeded(
                        localListID: list.id,
                        userID: authViewModel.currentUser?.uid,
                        modelContext: modelContext
                    )
                }
            }
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
        dismiss()
    }
}
