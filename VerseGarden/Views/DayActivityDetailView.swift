import FirebaseAuth
import SwiftData
import SwiftUI

struct DayActivityDetailView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var syncCoordinator: WritingRecordSyncCoordinator
    @EnvironmentObject private var prayerSyncCoordinator: PrayerSyncCoordinator
    @EnvironmentObject private var gardenActivityStore: GardenActivityStore
    @EnvironmentObject private var qtStore: QTStore
    @EnvironmentObject private var likedVerseStore: LikedVerseStore
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WritingRecord.completedAt, order: .reverse) private var records: [WritingRecord]
    @Query(sort: \PrayerWritingRecord.completedAt, order: .reverse) private var prayerRecords: [PrayerWritingRecord]
    @State private var editingBibleRecord: WritingRecord?
    @State private var deletingBibleRecord: WritingRecord?
    @State private var editingPrayerRecord: PrayerWritingRecord?
    @State private var deletingPrayerRecord: PrayerWritingRecord?
    @State private var expandedGroups: Set<DayRecordGroupKind> = []

    let date: Date

    private let calendar = Calendar.current

    private var bibleRecords: [WritingRecord] {
        deduplicatedBibleRecords(
            records.records(for: authViewModel.currentUser?.uid)
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
        )
    }

    private var dayPrayerRecords: [PrayerWritingRecord] {
        prayerRecords.records(for: authViewModel.currentUser?.uid)
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private var groupedBibleRecords: [DayBibleRecordGroup] {
        DayRecordGroupKind.bibleGroups.compactMap { kind in
            let items = bibleRecords.filter { classifyBibleRecord($0) == kind }
            guard !items.isEmpty else { return nil }
            return DayBibleRecordGroup(kind: kind, records: items)
        }
    }

    private var groupedPrayerRecords: [DayPrayerRecordGroup] {
        dayPrayerRecords.isEmpty ? [] : [DayPrayerRecordGroup(kind: .prayer, records: dayPrayerRecords)]
    }

    private var timelineActivities: [GardenActivity] {
        GardenActivityTimelineBuilder.mergedActivities(
            writingRecords: records.records(for: authViewModel.currentUser?.uid),
            prayerRecords: prayerRecords.records(for: authViewModel.currentUser?.uid),
            qtRecords: qtStore.records,
            likedVerseRecords: likedVerseStore.getLikedVerseRecords(),
            activityLog: gardenActivityStore.activities,
            calendar: calendar
        )
    }

    private var dayGardenActivities: [GardenActivity] {
        GardenActivityTimelineBuilder.activities(timelineActivities, on: date, calendar: calendar)
            .filter { $0.type == .qtCompleted || $0.type == .verseLiked }
    }

    private var groupedGardenActivities: [DayGardenActivityGroup] {
        [
            DayGardenActivityGroup(
                kind: .qt,
                activities: dayGardenActivities.filter { $0.type == .qtCompleted }
            ),
            DayGardenActivityGroup(
                kind: .savedVerse,
                activities: dayGardenActivities.filter { $0.type == .verseLiked }
            )
        ]
        .filter { !$0.activities.isEmpty }
    }

    private var totalRecordCount: Int {
        bibleRecords.count + dayPrayerRecords.count + dayGardenActivities.count
    }

    private var planRecordCount: Int {
        bibleRecords.filter { classifyBibleRecord($0) == .plan }.count
    }

    private var summaryStats: [(String, String)] {
        var stats: [(String, String)] = [
            ("총 기록 수", "\(totalRecordCount)개"),
            ("말씀 기록 수", "\(bibleRecords.count)개"),
            ("기도 기록 수", "\(dayPrayerRecords.count)개"),
            ("QT 기록 수", "\(dayGardenActivities.filter { $0.type == .qtCompleted }.count)개"),
            ("말씀 저장 수", "\(dayGardenActivities.filter { $0.type == .verseLiked }.count)개")
        ]
        if planRecordCount > 0 {
            stats.append(("플랜 기록 수", "\(planRecordCount)개"))
        }
        return stats
    }

    private var groupSignature: String {
        let bible = bibleRecords.map { "\($0.id.uuidString)-\($0.sourceType ?? "")" }.joined(separator: "|")
        let prayer = dayPrayerRecords.map(\.id.uuidString).joined(separator: "|")
        let garden = dayGardenActivities.map { "\($0.id)-\($0.type.rawValue)-\($0.createdAt.timeIntervalSince1970)" }.joined(separator: "|")
        return "\(bible)#\(prayer)#\(garden)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("하루 기록")
                        .font(.largeTitle.bold())
                    Text("기록을 눌러 수정하거나 삭제할 수 있습니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                GardenCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(date.formatted(.dateTime.year().month().day()))
                            .font(.title3.bold())
                        Text("말씀, QT, 기도 기록을 함께 확인합니다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                summaryCard

                if groupedBibleRecords.isEmpty && groupedPrayerRecords.isEmpty && groupedGardenActivities.isEmpty {
                    GardenCard {
                        Text("이 날 저장된 기록이 없습니다.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(groupedBibleRecords) { group in
                            collapsibleBibleSection(group)
                        }

                        ForEach(groupedPrayerRecords) { group in
                            collapsiblePrayerSection(group)
                        }

                        ForEach(groupedGardenActivities) { group in
                            collapsibleGardenActivitySection(group)
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .background(GardenTheme.background)
        .sheet(item: $editingBibleRecord) { record in
            NavigationStack {
                EditRecordView(record: record)
            }
        }
        .sheet(item: $editingPrayerRecord) { record in
            NavigationStack {
                PrayerComposerView(record: record)
            }
        }
        .alert("말씀 기록을 삭제하시겠습니까?", isPresented: deleteBibleAlertBinding) {
            Button("취소", role: .cancel) {
                deletingBibleRecord = nil
            }
            Button("삭제", role: .destructive) {
                confirmBibleDelete()
            }
        } message: {
            Text("선택한 필사 기록이 삭제됩니다.")
        }
        .alert("기도 기록을 삭제하시겠습니까?", isPresented: deletePrayerAlertBinding) {
            Button("취소", role: .cancel) {
                deletingPrayerRecord = nil
            }
            Button("삭제", role: .destructive) {
                confirmPrayerDelete()
            }
        } message: {
            Text("선택한 기도 기록이 삭제됩니다.")
        }
        .onAppear {
            initializeExpandedGroupsIfNeeded()
        }
        .onChange(of: groupSignature) { _, _ in
            initializeExpandedGroupsIfNeeded()
        }
    }

    private var summaryCard: some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 14) {
                GardenSectionHeader("기록 요약")

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2),
                    spacing: 10
                ) {
                    ForEach(summaryStats, id: \.0) { stat in
                        GardenStatCard(title: stat.0, value: stat.1, subtitle: nil)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func collapsibleBibleSection(_ group: DayBibleRecordGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: group.kind.title, count: group.records.count, isExpanded: isExpanded(group.kind)) {
                toggle(group.kind)
            }

            if isExpanded(group.kind) {
                VStack(spacing: 12) {
                    ForEach(group.records) { record in
                        bibleRecordRow(record, sourceTitle: group.kind.shortLabel)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func collapsiblePrayerSection(_ group: DayPrayerRecordGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: group.kind.title, count: group.records.count, isExpanded: isExpanded(group.kind)) {
                toggle(group.kind)
            }

            if isExpanded(group.kind) {
                VStack(spacing: 12) {
                    ForEach(group.records) { record in
                        prayerRecordRow(record)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func collapsibleGardenActivitySection(_ group: DayGardenActivityGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: group.kind.title, count: group.activities.count, isExpanded: isExpanded(group.kind)) {
                toggle(group.kind)
            }

            if isExpanded(group.kind) {
                VStack(spacing: 12) {
                    ForEach(group.activities) { activity in
                        gardenActivityRow(activity, sourceTitle: group.kind.shortLabel)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func sectionHeader(title: String, count: Int, isExpanded: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(count)개 기록")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .background(AppColors.cardTint)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func bibleRecordRow(_ record: WritingRecord, sourceTitle: String) -> some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(record.book) \(record.chapter):\(record.verse)")
                            .font(.headline)
                        Text(record.completedAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(sourceTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(sourceBadgeColor(for: classifyBibleRecord(record)))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(sourceBadgeColor(for: classifyBibleRecord(record)).opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(record.userText.isEmpty ? record.originalText : record.userText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingBibleRecord = record
        }
        .contextMenu {
            Button("수정") {
                editingBibleRecord = record
            }
            Button("삭제", role: .destructive) {
                deletingBibleRecord = record
            }
        }
    }

    private func prayerRecordRow(_ record: PrayerWritingRecord) -> some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.titleSnapshot)
                            .font(.headline)
                        Text(record.completedAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text("기도")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(GardenTheme.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(GardenTheme.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(record.userText.isEmpty ? record.originalText : record.userText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingPrayerRecord = record
        }
        .contextMenu {
            Button("수정") {
                editingPrayerRecord = record
            }
            Button("삭제", role: .destructive) {
                deletingPrayerRecord = record
            }
        }
    }

    private func gardenActivityRow(_ activity: GardenActivity, sourceTitle: String) -> some View {
        let tint = activityColor(for: activity.type)
        return GardenCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: activity.type.iconName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 34, height: 34)
                        .background(tint.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.reference ?? activity.title)
                            .font(.headline)
                        Text(activity.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(sourceTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(tint.opacity(0.12))
                        .clipShape(Capsule())
                }

                if let preview = activity.contentPreview, !preview.isEmpty {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }
            }
        }
    }

    private func classifyBibleRecord(_ record: WritingRecord) -> DayRecordGroupKind {
        switch record.sourceType {
        case WritingSourceType.plan.rawValue:
            return .plan
        case WritingSourceType.customList.rawValue:
            return .verseList
        case WritingSourceType.theme.rawValue:
            return .theme
        default:
            return .freeBible
        }
    }

    private func deduplicatedBibleRecords(_ records: [WritingRecord]) -> [WritingRecord] {
        var seenKeys = Set<String>()
        return records
            .sorted { $0.completedAt > $1.completedAt }
            .filter { record in
                let key = record.verseId.isEmpty
                    ? "\(record.book)-\(record.chapter)-\(record.verse)"
                    : record.verseId
                return seenKeys.insert(key.normalizedDayRecordKey).inserted
            }
    }

    private func sourceBadgeColor(for kind: DayRecordGroupKind) -> Color {
        switch kind {
        case .plan:
            return GardenTheme.primary
        case .verseList:
            return .orange
        case .theme:
            return GardenTheme.secondary
        case .freeBible:
            return GardenTheme.tertiary
        case .prayer:
            return GardenTheme.secondary
        case .qt:
            return GardenTheme.primary
        case .savedVerse:
            return .pink
        }
    }

    private func activityColor(for type: GardenActivityType) -> Color {
        switch type {
        case .qtCompleted:
            return GardenTheme.primary
        case .verseLiked:
            return .pink
        case .scriptureCopy:
            return GardenTheme.primary
        case .prayer:
            return GardenTheme.secondary
        case .verseRead:
            return GardenTheme.tertiary
        }
    }

    private func isExpanded(_ kind: DayRecordGroupKind) -> Bool {
        expandedGroups.contains(kind)
    }

    private func toggle(_ kind: DayRecordGroupKind) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if expandedGroups.contains(kind) {
                expandedGroups.remove(kind)
            } else {
                expandedGroups.insert(kind)
            }
        }
    }

    private func initializeExpandedGroupsIfNeeded() {
        guard expandedGroups.isEmpty else { return }

        if groupedBibleRecords.contains(where: { $0.kind == .plan }) {
            expandedGroups.insert(.plan)
        } else if let firstBibleGroup = groupedBibleRecords.first {
            expandedGroups.insert(firstBibleGroup.kind)
        }

        if groupedBibleRecords.isEmpty && !groupedPrayerRecords.isEmpty {
            expandedGroups.insert(.prayer)
        }

        if groupedBibleRecords.isEmpty && groupedPrayerRecords.isEmpty, let firstGardenGroup = groupedGardenActivities.first {
            expandedGroups.insert(firstGardenGroup.kind)
        }
    }

    private var deleteBibleAlertBinding: Binding<Bool> {
        Binding(
            get: { deletingBibleRecord != nil },
            set: { isPresented in
                if !isPresented {
                    deletingBibleRecord = nil
                }
            }
        )
    }

    private var deletePrayerAlertBinding: Binding<Bool> {
        Binding(
            get: { deletingPrayerRecord != nil },
            set: { isPresented in
                if !isPresented {
                    deletingPrayerRecord = nil
                }
            }
        )
    }

    private func confirmBibleDelete() {
        guard let record = deletingBibleRecord else { return }
        let remoteDocumentId = record.remoteDocumentId
        let ownerUserId = record.ownerUserId
        deletingBibleRecord = nil

        Task {
            let didDeleteRemote = await syncCoordinator.deleteRecordIfNeeded(
                remoteDocumentId: remoteDocumentId,
                ownerUserId: ownerUserId,
                userID: authViewModel.currentUser?.uid
            )
            guard didDeleteRemote else { return }
            modelContext.delete(record)
            try? modelContext.save()
        }
    }

    private func confirmPrayerDelete() {
        guard let record = deletingPrayerRecord else { return }
        deletingPrayerRecord = nil

        Task {
            await prayerSyncCoordinator.deleteRecordIfNeeded(
                localRecordID: record.id,
                userID: authViewModel.currentUser?.uid,
                modelContext: modelContext
            )
        }
    }
}

private struct DayBibleRecordGroup: Identifiable {
    let kind: DayRecordGroupKind
    let records: [WritingRecord]

    var id: DayRecordGroupKind { kind }
}

private struct DayPrayerRecordGroup: Identifiable {
    let kind: DayRecordGroupKind
    let records: [PrayerWritingRecord]

    var id: DayRecordGroupKind { kind }
}

private struct DayGardenActivityGroup: Identifiable {
    let kind: DayRecordGroupKind
    let activities: [GardenActivity]

    var id: DayRecordGroupKind { kind }
}

private enum DayRecordGroupKind: String, Hashable, Identifiable {
    case plan
    case verseList
    case theme
    case freeBible
    case prayer
    case qt
    case savedVerse

    static let bibleGroups: [DayRecordGroupKind] = [.plan, .verseList, .theme, .freeBible]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .plan:
            return "필사 플랜"
        case .verseList:
            return "나만의 리스트"
        case .theme:
            return "테마별 말씀"
        case .freeBible:
            return "자유 말씀 필사"
        case .prayer:
            return "기도 기록"
        case .qt:
            return "QT 기록"
        case .savedVerse:
            return "말씀 저장"
        }
    }

    var shortLabel: String {
        switch self {
        case .plan:
            return "플랜"
        case .verseList:
            return "리스트"
        case .theme:
            return "테마"
        case .freeBible:
            return "자유"
        case .prayer:
            return "기도"
        case .qt:
            return "QT"
        case .savedVerse:
            return "저장"
        }
    }
}

private extension String {
    var normalizedDayRecordKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
    }
}
