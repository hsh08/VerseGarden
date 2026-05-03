import FirebaseAuth
import SwiftData
import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WritingRecord.completedAt, order: .reverse) private var records: [WritingRecord]
    @State private var editingRecord: WritingRecord?
    @State private var deletingRecord: WritingRecord?
    @State private var selectedSourceFilter: HistorySourceFilter = .all
    @Binding var selectedDate: Date?

    private let calendar = Calendar.current
    private var currentUserRecords: [WritingRecord] {
        records.records(for: authViewModel.currentUser?.uid)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                filterSection

                if filteredRecords.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(groupedRecords, id: \.date) { group in
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader(for: group)

                                ForEach(group.records) { record in
                                    recordCard(record)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("기록")
        .background(Color(.systemGroupedBackground))
        .sheet(item: $editingRecord) { record in
            NavigationStack {
                EditRecordView(record: record)
            }
        }
        .alert("삭제하시겠습니까?", isPresented: deleteAlertBinding) {
            Button("취소", role: .cancel) {
                deletingRecord = nil
            }
            Button("삭제", role: .destructive) {
                confirmDelete()
            }
        } message: {
            Text("선택한 필사 기록이 삭제됩니다.")
        }
    }

    private var filteredRecords: [WritingRecord] {
        currentUserRecords.filter { record in
            let matchesDate = selectedDate.map { calendar.isDate(record.date, inSameDayAs: $0) } ?? true
            let matchesSource = selectedSourceFilter.matches(record: record)
            return matchesDate && matchesSource
        }
    }

    private var groupedRecords: [RecordGroup] {
        let grouped = Dictionary(grouping: filteredRecords) { record in
            calendar.startOfDay(for: record.date)
        }

        return grouped
            .map { date, records in
                RecordGroup(
                    date: date,
                    records: records.sorted { $0.completedAt > $1.completedAt }
                )
            }
            .sorted { $0.date > $1.date }
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedDate {
                filterBanner(for: selectedDate)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(HistorySourceFilter.allCases) { filter in
                        Button {
                            selectedSourceFilter = filter
                        } label: {
                            Text(filter.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selectedSourceFilter == filter ? Color.white : Color.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(selectedSourceFilter == filter ? Color.green : Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if selectedSourceFilter != .all {
                Text(selectedSourceFilter.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                emptyTitle,
                systemImage: "square.and.pencil",
                description: Text(emptyDescription)
            )

            if selectedDate != nil || selectedSourceFilter != .all {
                HStack(spacing: 10) {
                    if selectedDate != nil {
                        Button("전체 날짜 보기") {
                            selectedDate = nil
                        }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }

                    if selectedSourceFilter != .all {
                        Button("필터 해제") {
                            selectedSourceFilter = .all
                        }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(.top, 80)
    }

    private var emptyTitle: String {
        if selectedDate != nil && selectedSourceFilter != .all {
            return "선택한 조건의 기록이 없습니다"
        }
        if selectedDate != nil {
            return "선택한 날짜의 기록이 없습니다"
        }
        if selectedSourceFilter != .all {
            return "\(selectedSourceFilter.title) 기록이 없습니다"
        }
        return "아직 기록이 없습니다"
    }

    private var emptyDescription: String {
        if selectedDate != nil && selectedSourceFilter != .all {
            return "다른 날짜를 선택하거나 필터를 해제해 보세요."
        }
        if selectedDate != nil {
            return "다른 날짜를 선택하거나 전체 보기로 돌아가세요."
        }
        if selectedSourceFilter != .all {
            return "해당 유형으로 저장된 필사 기록이 아직 없습니다."
        }
        return "오늘의 구절을 필사하면 기록이 여기에 쌓입니다."
    }

    private func filterBanner(for date: Date) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("선택한 날짜")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(date.formatted(.dateTime.year().month().day()))
                    .font(.subheadline.weight(.semibold))
            }

            Spacer()

            Button("전체 보기") {
                selectedDate = nil
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sectionHeader(for group: RecordGroup) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(group.date.formatted(.dateTime.year().month().day()))
                .font(.headline)

            Text("\(group.records.count)회 필사")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.top, 4)
    }

    private func recordCard(_ record: WritingRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("\(record.book) \(record.chapter):\(record.verse)")
                            .font(.headline)
                        sourceBadge(for: record)
                    }
                    Text(record.completedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button("수정") {
                        editingRecord = record
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)

                    Button("삭제", role: .destructive) {
                        deletingRecord = record
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("원문")
                    .font(.subheadline.weight(.semibold))
                Text(record.originalText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("내가 쓴 내용")
                    .font(.subheadline.weight(.semibold))
                Text(record.userText)
                    .font(.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func sourceBadge(for record: WritingRecord) -> some View {
        let source = HistorySourceFilter.sourceType(for: record)

        return Text(source.shortTitle)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(source.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(source.tint.opacity(0.12))
            .clipShape(Capsule())
    }

    private func deleteRecord(_ record: WritingRecord) {
        modelContext.delete(record)
        try? modelContext.save()
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deletingRecord != nil },
            set: { isPresented in
                if !isPresented {
                    deletingRecord = nil
                }
            }
        )
    }

    private func confirmDelete() {
        guard let record = deletingRecord else { return }
        deleteRecord(record)
        deletingRecord = nil
    }
}

private struct RecordGroup {
    let date: Date
    let records: [WritingRecord]
}

private enum HistorySourceFilter: String, CaseIterable, Identifiable {
    case all
    case direct
    case theme
    case monthly
    case customList

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "전체"
        case .direct:
            return "직접"
        case .theme:
            return "테마"
        case .monthly:
            return "월간"
        case .customList:
            return "리스트"
        }
    }

    var shortTitle: String {
        switch self {
        case .all:
            return "전체"
        case .direct:
            return "직접"
        case .theme:
            return "테마"
        case .monthly:
            return "월간"
        case .customList:
            return "리스트"
        }
    }

    var description: String {
        switch self {
        case .all:
            return "모든 필사 기록을 표시합니다."
        case .direct:
            return "성경 직접 선택으로 시작한 필사 기록입니다."
        case .theme:
            return "테마별 말씀에서 시작한 필사 기록입니다."
        case .monthly:
            return "이번 달 필사 루틴에서 시작한 기록입니다."
        case .customList:
            return "나만의 리스트에서 시작한 필사 기록입니다."
        }
    }

    var tint: Color {
        switch self {
        case .all:
            return .green
        case .direct:
            return .green
        case .theme:
            return .mint
        case .monthly:
            return .teal
        case .customList:
            return .orange
        }
    }

    func matches(record: WritingRecord) -> Bool {
        self == .all || Self.sourceType(for: record) == self
    }

    static func sourceType(for record: WritingRecord) -> HistorySourceFilter {
        HistorySourceFilter(rawValue: record.sourceType ?? WritingSourceType.direct.rawValue) ?? .direct
    }
}
