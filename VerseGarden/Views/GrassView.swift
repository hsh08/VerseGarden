import FirebaseAuth
import SwiftData
import SwiftUI

struct GrassView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @EnvironmentObject private var gardenActivityStore: GardenActivityStore
    @EnvironmentObject private var qtStore: QTStore
    @EnvironmentObject private var likedVerseStore: LikedVerseStore
    @Query(sort: \WritingRecord.completedAt, order: .reverse) private var records: [WritingRecord]
    @Query(sort: \PrayerWritingRecord.completedAt, order: .reverse) private var prayerRecords: [PrayerWritingRecord]

    @State private var displayedMonth = Date()
    @State private var selectedDay: SelectedDay?
    @State private var metrics = GrassMetrics.empty

    private let calendar: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }()

    private let heatmapColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: displayedMonth) ?? DateInterval(start: displayedMonth, duration: 0)
    }

    private var monthDates: [Date] { metrics.monthDates }
    private var monthGridDates: [Date?] { metrics.monthGridDates }
    private var currentStreak: Int { metrics.currentStreak }
    private var totalActivityCount: Int { metrics.totalActivityCount }
    private var monthTotalCount: Int { metrics.monthTotalCount }
    private var monthActiveDays: Int { metrics.monthActiveDays }
    private var monthTitle: String { metrics.monthTitle }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let head = calendar.firstWeekday - 1
        return Array(symbols[head...] + symbols[..<head])
    }

    private var shareCardStats: ShareCardStats { metrics.shareCardStats }
    private var shareHeatmap: [ShareCardDayData] { metrics.shareHeatmap }
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GardenTheme.sectionSpacing) {
                heatmapSection
                if let selectedDay {
                    selectedDaySummaryCard(for: selectedDay.date)
                }
                legendSection
                statsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, AppSpacing.tabBarBottomPadding)
        }
        .navigationTitle("잔디")
        .background(GardenTheme.background)
        .task(id: activitySignature) {
            refreshMetrics()
        }
        .task(id: displayedMonth) {
            refreshMetrics()
        }
    }

    private var heatmapSection: some View {
        GardenCard(
            accentGradient: LinearGradient(
                colors: [GardenTheme.primary.opacity(0.16), GardenTheme.secondary.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("나의 가든")
                            .font(.title3.bold())
                            .foregroundStyle(AppColors.primaryText)
                        Text("이번 달에 심은 기록")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GardenTheme.primary)
                        Text(monthTitle)
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryText)
                    }
                    Spacer()
                    NavigationLink {
                        MonthlyShareCardView(
                            stats: shareCardStats,
                            weekdaySymbols: weekdaySymbols,
                            heatmap: shareHeatmap
                        )
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(GardenTheme.primary)
                            .padding(10)
                            .background(GardenTheme.softFill)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    monthSwitcher
                }

                HStack(spacing: 8) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColors.secondaryText)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: heatmapColumns, spacing: 8) {
                    ForEach(Array(monthGridDates.enumerated()), id: \.offset) { _, date in
                        if let date {
                            let normalizedDate = calendar.startOfDay(for: date)
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    if selectedDay?.date == normalizedDate {
                                        selectedDay = nil
                                    } else {
                                        selectedDay = SelectedDay(date: normalizedDate)
                                    }
                                }
                            } label: {
                                GardenDayCell(
                                    day: calendar.component(.day, from: date),
                                    count: count(for: date),
                                    isToday: calendar.isDateInToday(date),
                                    isSelected: selectedDay?.date == normalizedDate
                                )
                            }
                            .buttonStyle(.plain)
                        } else {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.clear)
                                .frame(height: 42)
                        }
                    }
                }
            }
        }
    }

    private var monthSwitcher: some View {
        HStack(spacing: 10) {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(canMoveToNextMonth ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canMoveToNextMonth)
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            GardenSectionHeader("루틴 요약", subtitle: "말씀 읽기, 저장, 필사, 기도, QT 활동이 함께 집계됩니다.")

            HStack(spacing: 12) {
                gardenStatTile(title: "연속 루틴", value: "\(currentStreak)일", accent: GardenTheme.primary)
                gardenStatTile(title: "총 기록", value: "\(totalActivityCount)회", accent: GardenTheme.secondary)
            }

            HStack(spacing: 12) {
                gardenStatTile(title: "활동일", value: "\(monthActiveDays)일", accent: GardenTheme.tertiary)
                gardenStatTile(title: "이번 달 기록", value: "\(monthTotalCount)회", accent: GardenTheme.primary)
            }
        }
    }

    private func selectedDaySummaryCard(for date: Date) -> some View {
        GardenCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dayTitle(for: date))
                            .font(.title3.bold())
                            .foregroundStyle(AppColors.primaryText)
                        Text("하루의 신앙 기록을 돌아봅니다.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                    }

                    Spacer()

                    Image(systemName: hasActivities(on: date) ? "leaf.fill" : "tray")
                        .font(.headline)
                        .foregroundStyle(hasActivities(on: date) ? GardenTheme.primary : AppColors.subtleText)
                        .frame(width: 38, height: 38)
                        .background((hasActivities(on: date) ? GardenTheme.primary : AppColors.border).opacity(0.12))
                        .clipShape(Circle())
                }

                if hasActivities(on: date) {
                    VStack(spacing: 12) {
                        VStack(spacing: 8) {
                            ForEach(dayActivitySummaryItems(for: date)) { item in
                                dayActivitySummaryRow(item)
                            }
                        }

                        NavigationLink {
                            DayActivityDetailView(date: date)
                        } label: {
                            HStack {
                                Text("자세히 보기")
                                    .font(.subheadline.weight(.bold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(GardenTheme.primary)
                            .frame(minHeight: 48)
                            .padding(.horizontal, 14)
                            .background(GardenTheme.softFill)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.button, style: .continuous)
                                    .stroke(GardenTheme.primary.opacity(0.16), lineWidth: 0.8)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("아직 심은 기록이 없어요")
                            .font(.headline)
                            .foregroundStyle(AppColors.primaryText)
                        Text("말씀이나 기도를 기록하면 이곳에 하루의 정원이 채워집니다.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func dayActivitySummaryItems(for date: Date) -> [GardenDayActivitySummaryItem] {
        let dayActivities = activities(on: date)
        let types: [GardenActivityType] = [.qtCompleted, .scriptureCopy, .prayer, .verseLiked]

        return types.compactMap { type in
            let count = dayActivities.filter { $0.type == type }.count
            guard count > 0 else { return nil }
            return GardenDayActivitySummaryItem(
                type: type,
                title: summaryTitle(for: type),
                count: count,
                icon: type.iconName,
                tint: activityTint(for: type)
            )
        }
    }

    private func summaryTitle(for type: GardenActivityType) -> String {
        switch type {
        case .qtCompleted:
            return "QT"
        case .scriptureCopy:
            return "필사"
        case .prayer:
            return "기도"
        case .verseLiked:
            return "말씀 저장"
        case .verseRead:
            return "말씀 읽기"
        }
    }

    private func dayActivitySummaryRow(_ item: GardenDayActivitySummaryItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(item.tint)
                .frame(width: 34, height: 34)
                .background(item.tint.opacity(0.12))
                .clipShape(Circle())

            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColors.primaryText)

            Spacer()

            Text("\(item.count)개")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(item.tint)
        }
        .padding(12)
        .background(Color.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(item.tint.opacity(0.14), lineWidth: 0.8)
        }
    }

    private func activityRecordRow(_ activity: GardenActivity) -> some View {
        let tint = activityTint(for: activity.type)
        let value = activity.reference ?? activity.contentPreview ?? activity.title

        return HStack(spacing: 12) {
            Image(systemName: activity.type.iconName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.type.displayTitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.primaryText)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 0.8)
        }
    }

    private func gardenStatTile(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.secondaryText)
            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous)
                .stroke(accent.opacity(0.12), lineWidth: 0.8)
        }
    }

    private var legendSection: some View {
        HStack(spacing: 8) {
            Text("적음")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color(for: level))
                    .frame(width: 14, height: 14)
            }

            Text("많음")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func normalizedWeekday(for date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return ((weekday - calendar.firstWeekday + 7) % 7) + 1
    }

    private func count(for date: Date) -> Int {
        metrics.daySummaries[calendar.startOfDay(for: date)]?.totalCount ?? 0
    }

    private func activities(on date: Date) -> [GardenActivity] {
        GardenActivityTimelineBuilder.gardenGrowthActivities(timelineActivities, on: date, calendar: calendar)
    }

    private func hasActivities(on date: Date) -> Bool {
        !activities(on: date).isEmpty
    }

    private func dayTitle(for date: Date) -> String {
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        let weekday = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
        return "\(month)월 \(day)일 (\(weekday))"
    }

    private var canMoveToNextMonth: Bool {
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else {
            return false
        }
        return nextMonth <= Date()
    }

    private func moveMonth(by value: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) else {
            return
        }

        if value > 0, nextMonth > Date() {
            displayedMonth = Date()
        } else {
            displayedMonth = nextMonth
        }
    }

    private var activitySignature: String {
        let uid = authViewModel.currentUser?.uid ?? ""
        let writing = records
            .map { "\($0.id.uuidString)-\($0.ownerUserId)-\($0.completedAt.timeIntervalSince1970)-\($0.verseId)" }
            .joined(separator: "|")
        let prayer = prayerRecords
            .map { "\($0.id.uuidString)-\($0.ownerUserId)-\($0.completedAt.timeIntervalSince1970)-\($0.titleSnapshot)" }
            .joined(separator: "|")
        let qt = qtStore.records
            .map { "\($0.id)-\($0.completedAt?.timeIntervalSince1970 ?? 0)-\($0.updatedAt.timeIntervalSince1970)" }
            .joined(separator: "|")
        let liked = likedVerseStore.getLikedVerseRecords()
            .map { "\($0.verseId)-\($0.createdAt.timeIntervalSince1970)" }
            .joined(separator: "|")
        let log = gardenActivityStore.activities
            .map { "\($0.id)-\($0.type.rawValue)-\($0.createdAt.timeIntervalSince1970)" }
            .joined(separator: "|")
        return "\(uid)#\(writing)#\(prayer)#\(qt)#\(liked)#\(log)"
    }

    private func refreshMetrics() {
        let activities = timelineActivities
        let daySummaries = GardenActivityTimelineBuilder.daySummaries(from: activities, calendar: calendar)
        let monthStart = calendar.startOfDay(for: monthInterval.start)
        let dayCount = calendar.dateComponents([.day], from: monthStart, to: monthInterval.end).day ?? 0
        let monthDates = (0..<dayCount).compactMap { calendar.date(byAdding: .day, value: $0, to: monthStart) }
        let monthGridDates: [Date?]
        if let firstDate = monthDates.first {
            let leadingPadding = normalizedWeekday(for: firstDate) - 1
            let trailingPadding = 7 - ((leadingPadding + monthDates.count) % 7)
            let normalizedTrailingPadding = trailingPadding == 7 ? 0 : trailingPadding
            monthGridDates = Array(repeating: nil, count: leadingPadding) + monthDates + Array(repeating: nil, count: normalizedTrailingPadding)
        } else {
            monthGridDates = []
        }
        let monthTitle = monthInterval.start.formatted(.dateTime.year().month(.wide))
        let monthTotalCount = monthDates.reduce(0) { $0 + (daySummaries[calendar.startOfDay(for: $1)]?.totalCount ?? 0) }
        let monthActiveDays = monthDates.filter { (daySummaries[calendar.startOfDay(for: $0)]?.totalCount ?? 0) > 0 }.count
        let currentStreak = GardenActivityTimelineBuilder.currentStreak(from: activities, calendar: calendar)
        let totalActivityCount = GardenActivityTimelineBuilder.gardenGrowthActivities(from: activities).count
        let shareCardStats = ShareCardStats(
            monthTitle: monthTitle,
            todayCount: daySummaries[calendar.startOfDay(for: Date())]?.totalCount ?? 0,
            streak: currentStreak,
            monthTotalCount: monthTotalCount
        )
        let shareHeatmap = monthGridDates.enumerated().map { index, date in
            if let date {
                return ShareCardDayData(
                    id: "day-\(calendar.startOfDay(for: date).timeIntervalSince1970)",
                    dayNumber: calendar.component(.day, from: date),
                    count: daySummaries[calendar.startOfDay(for: date)]?.totalCount ?? 0,
                    isToday: calendar.isDateInToday(date),
                    isPlaceholder: false
                )
            } else {
                return ShareCardDayData(
                    id: "placeholder-\(index)",
                    dayNumber: nil,
                    count: 0,
                    isToday: false,
                    isPlaceholder: true
                )
            }
        }

        metrics = GrassMetrics(
            daySummaries: daySummaries,
            monthDates: monthDates,
            monthGridDates: monthGridDates,
            currentStreak: currentStreak,
            totalActivityCount: totalActivityCount,
            monthTotalCount: monthTotalCount,
            monthActiveDays: monthActiveDays,
            monthTitle: monthTitle,
            shareCardStats: shareCardStats,
            shareHeatmap: shareHeatmap
        )
    }

    private func color(for count: Int) -> Color {
        GrassCell.fillColor(for: count)
    }

    private func activityTint(for type: GardenActivityType) -> Color {
        switch type {
        case .verseRead:
            return GardenTheme.primary
        case .verseLiked:
            return GardenTheme.tertiary
        case .scriptureCopy:
            return GardenTheme.secondary
        case .prayer:
            return GardenTheme.tertiary
        case .qtCompleted:
            return GardenTheme.primary
        }
    }
}

private struct GrassMetrics {
    let daySummaries: [Date: HabitDaySummary]
    let monthDates: [Date]
    let monthGridDates: [Date?]
    let currentStreak: Int
    let totalActivityCount: Int
    let monthTotalCount: Int
    let monthActiveDays: Int
    let monthTitle: String
    let shareCardStats: ShareCardStats
    let shareHeatmap: [ShareCardDayData]

    static let empty = GrassMetrics(
        daySummaries: [:],
        monthDates: [],
        monthGridDates: [],
        currentStreak: 0,
        totalActivityCount: 0,
        monthTotalCount: 0,
        monthActiveDays: 0,
        monthTitle: "",
        shareCardStats: ShareCardStats(monthTitle: "", todayCount: 0, streak: 0, monthTotalCount: 0),
        shareHeatmap: []
    )
}

private struct GardenDayCell: View {
    let day: Int
    let count: Int
    let isToday: Bool
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(fillColor)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(borderColor, lineWidth: isSelected ? 1.6 : isToday ? 1.1 : 0.6)
                }
                .overlay {
                    if count > 0 {
                        Circle()
                            .fill(dotColor)
                            .frame(width: 5, height: 5)
                            .padding(5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                }
                .frame(height: 28)

            Text("\(day)")
                .font(.caption2.weight(isSelected || isToday ? .bold : .regular))
                .foregroundStyle(isSelected ? GardenTheme.primary : isToday ? AppColors.primaryText : AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(isSelected ? GardenTheme.primary.opacity(0.08) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var fillColor: Color {
        GrassCell.fillColor(for: min(count, 4))
    }

    private var borderColor: Color {
        if isSelected {
            return GardenTheme.primary.opacity(0.75)
        }
        if isToday {
            return GardenTheme.secondary.opacity(0.45)
        }
        return GrassCell.strokeColor(for: count)
    }

    private var dotColor: Color {
        count >= 3 ? Color.white.opacity(0.92) : GardenTheme.secondary.opacity(0.72)
    }
}

private struct SelectedDay: Identifiable {
    let id = UUID()
    let date: Date
}

private struct GardenDayActivitySummaryItem: Identifiable {
    let type: GardenActivityType
    let title: String
    let count: Int
    let icon: String
    let tint: Color

    var id: GardenActivityType { type }
}
