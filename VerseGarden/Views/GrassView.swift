import FirebaseAuth
import SwiftData
import SwiftUI

struct GrassView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Query(sort: \WritingRecord.completedAt, order: .reverse) private var records: [WritingRecord]
    @State private var displayedMonth = Date()

    let onSelectDate: (Date) -> Void

    private let calendar: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }()

    private let monthColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)
    private var currentUserRecords: [WritingRecord] {
        records.records(for: authViewModel.currentUser?.uid)
    }

    private var currentStreak: Int {
        StreakCalculator.currentStreak(from: currentUserRecords, calendar: calendar)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCards
                monthCard
                legend
                shareCardEntry
                yearlyPlaceholder
            }
            .padding()
        }
        .navigationTitle("잔디")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
    }

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: displayedMonth) ?? DateInterval(start: displayedMonth, duration: 0)
    }

    private var countsByDate: [Date: Int] {
        Dictionary(grouping: currentUserRecords, by: { calendar.startOfDay(for: $0.date) })
            .mapValues(\.count)
    }

    private var monthDates: [Date] {
        let monthStart = calendar.startOfDay(for: monthInterval.start)
        let dayCount = calendar.dateComponents([.day], from: monthStart, to: monthInterval.end).day ?? 0

        return (0..<dayCount).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: monthStart)
        }
    }

    private var monthGridDates: [Date?] {
        guard let firstDate = monthDates.first else {
            return []
        }

        let leadingPadding = normalizedWeekday(for: firstDate) - 1
        let trailingPadding = 7 - ((leadingPadding + monthDates.count) % 7)
        let normalizedTrailingPadding = trailingPadding == 7 ? 0 : trailingPadding

        return Array(repeating: nil, count: leadingPadding)
            + monthDates
            + Array(repeating: nil, count: normalizedTrailingPadding)
    }

    private var monthTotalCount: Int {
        monthDates.reduce(0) { $0 + count(for: $1) }
    }

    private var monthActiveDays: Int {
        monthDates.filter { count(for: $0) > 0 }.count
    }

    private var todayCount: Int {
        count(for: Date())
    }

    private var isShowingCurrentMonth: Bool {
        calendar.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    private var monthTitle: String {
        monthInterval.start.formatted(.dateTime.year().month(.wide))
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let head = calendar.firstWeekday - 1
        return Array(symbols[head...] + symbols[..<head])
    }

    private func normalizedWeekday(for date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return ((weekday - calendar.firstWeekday + 7) % 7) + 1
    }

    private func count(for date: Date) -> Int {
        countsByDate[calendar.startOfDay(for: date), default: 0]
    }

    private func accessibilityText(for date: Date) -> String {
        let count = count(for: date)
        return "\(date.formatted(date: .abbreviated, time: .omitted)), \(count)회 기록. 탭하면 기록 탭에서 확인"
    }

    private var summaryCards: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                SummaryCard(title: "이 달 총 필사", value: "\(monthTotalCount)회", subtitle: monthTitle)
                SummaryCard(title: "활동일", value: "\(monthActiveDays)일", subtitle: "기록이 있는 날짜")
            }

            HStack(spacing: 12) {
                SummaryCard(
                    title: isShowingCurrentMonth ? "오늘 필사 수" : "선택한 달 기준",
                    value: isShowingCurrentMonth ? "\(todayCount)회" : "\(monthDates.count)일",
                    subtitle: isShowingCurrentMonth
                        ? (todayCount > 0 ? "오늘도 기록 중" : "오늘은 아직 비어 있음")
                        : "달력에 표시된 날짜 수"
                )

                SummaryCard(
                    title: "연속 필사",
                    value: "\(currentStreak)일",
                    subtitle: currentStreak > 0 ? "이어가고 있는 기록" : "연속 기록 없음"
                )
            }
        }
    }

    private var monthCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("월간 필사 기록")
                    .font(.headline)
                Text("월간 달력에서 날짜와 기록 밀도를 함께 확인합니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text(monthTitle)
                        .font(.title3.bold())
                    if isShowingCurrentMonth {
                        Text("현재 달")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(canMoveToNextMonth ? .primary : .secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(.systemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canMoveToNextMonth)
            }

            LazyVGrid(columns: monthColumns, spacing: 10) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(monthGridDates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        Button {
                            onSelectDate(calendar.startOfDay(for: date))
                        } label: {
                            MonthGrassCell(
                                dayNumber: calendar.component(.day, from: date),
                                count: count(for: date),
                                isToday: calendar.isDateInToday(date)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(accessibilityText(for: date))
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.clear)
                            .frame(maxWidth: .infinity, minHeight: 62, maxHeight: 62)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var yearlyPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("전체 365일 보기")
                .font(.headline)
            Text("월별 이동 구조는 열어두고, 연간 잔디 화면은 다음 단계에서 별도 화면으로 확장할 예정입니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("전체 365일 보기")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("준비 중")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(true)
        }
    }

    private var shareCardEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("공유용 카드")
                .font(.headline)
            Text("이번 달 잔디를 인스타 스토리 비율 카드로 저장하거나 공유할 수 있습니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            NavigationLink {
                MonthlyShareCardView(records: currentUserRecords)
            } label: {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.green.opacity(0.18), Color.mint.opacity(0.14)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .overlay {
                            Image(systemName: "square.and.arrow.up.fill")
                                .font(.title3)
                                .foregroundStyle(.green)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("공유용 카드 보기")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("이번 달 잔디와 요약을 이미지로 만들기")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Text("적음")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(0..<5, id: \.self) { level in
                GrassCell(count: level, size: 12)
            }

            Text("많음")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
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
}

private struct SummaryCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
