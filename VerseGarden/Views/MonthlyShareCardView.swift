import Photos
import SwiftData
import SwiftUI
import UIKit

struct MonthlyShareCardView: View {
    let records: [WritingRecord]

    @State private var shareImage: UIImage?
    @State private var showingShareSheet = false
    @State private var alertMessage: String?
    @State private var availableCardWidth: CGFloat = 360
    @Environment(\.displayScale) private var displayScale

    private let calendar: Calendar = {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }()

    private var cardWidth: CGFloat {
        max(min(availableCardWidth - 32, 360), 0)
    }

    private var cardHeight: CGFloat {
        cardWidth * (16 / 9)
    }

    private var currentMonth: Date {
        Date()
    }

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: currentMonth) ?? DateInterval(start: currentMonth, duration: 0)
    }

    private var countsByDate: [Date: Int] {
        Dictionary(grouping: records, by: { calendar.startOfDay(for: $0.date) })
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
        guard let firstDate = monthDates.first else { return [] }

        let leadingPadding = normalizedWeekday(for: firstDate) - 1
        let trailingPadding = 7 - ((leadingPadding + monthDates.count) % 7)
        let normalizedTrailingPadding = trailingPadding == 7 ? 0 : trailingPadding

        return Array(repeating: nil, count: leadingPadding)
            + monthDates
            + Array(repeating: nil, count: normalizedTrailingPadding)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let head = calendar.firstWeekday - 1
        return Array(symbols[head...] + symbols[..<head])
    }

    private var monthTitle: String {
        monthInterval.start.formatted(.dateTime.year().month(.wide))
    }

    private var monthTotalCount: Int {
        monthDates.reduce(0) { $0 + count(for: $1) }
    }

    private var todayCount: Int {
        count(for: Date())
    }

    private var currentStreak: Int {
        StreakCalculator.currentStreak(from: records, calendar: calendar)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    shareCardContent
                    actionButtons
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("공유용 카드")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showingShareSheet) {
                if let shareImage {
                    ActivityViewController(activityItems: [shareImage])
                }
            }
            .alert("안내", isPresented: alertBinding) {
                Button("확인", role: .cancel) {
                    alertMessage = nil
                }
            } message: {
                Text(alertMessage ?? "")
            }
            .onAppear {
                availableCardWidth = proxy.size.width
            }
            .onChange(of: proxy.size.width) { _, newWidth in
                availableCardWidth = newWidth
            }
        }
    }

    private var shareCardContent: some View {
        ShareCardLayout(
            monthTitle: monthTitle,
            weekdaySymbols: weekdaySymbols,
            monthGridDates: monthGridDates,
            todayCount: todayCount,
            currentStreak: currentStreak,
            monthTotalCount: monthTotalCount,
            countProvider: count(for:),
            isTodayProvider: calendar.isDateInToday(_:),
            dayProvider: { calendar.component(.day, from: $0) }
        )
        .frame(width: cardWidth, height: cardHeight)
        .shadow(color: Color.black.opacity(0.08), radius: 18, y: 8)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                saveImageToPhotos()
            } label: {
                Text("이미지 저장")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                shareCardImage()
            } label: {
                Text("공유하기")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func normalizedWeekday(for date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return ((weekday - calendar.firstWeekday + 7) % 7) + 1
    }

    private func count(for date: Date) -> Int {
        countsByDate[calendar.startOfDay(for: date), default: 0]
    }

    private func renderImage() -> UIImage? {
        let renderer = ImageRenderer(
            content: ShareCardLayout(
                monthTitle: monthTitle,
                weekdaySymbols: weekdaySymbols,
                monthGridDates: monthGridDates,
                todayCount: todayCount,
                currentStreak: currentStreak,
                monthTotalCount: monthTotalCount,
                countProvider: count(for:),
                isTodayProvider: calendar.isDateInToday(_:),
                dayProvider: { calendar.component(.day, from: $0) }
            )
            .frame(width: cardWidth, height: cardHeight)
        )
        renderer.scale = displayScale
        return renderer.uiImage
    }

    private func shareCardImage() {
        if let shareImage {
            self.shareImage = shareImage
            showingShareSheet = true
            return
        }

        guard let image = renderImage() else {
            alertMessage = "공유 이미지를 만드는 데 실패했습니다."
            return
        }

        shareImage = image
        showingShareSheet = true
    }

    private func saveImageToPhotos() {
        guard let image = shareImage ?? renderImage() else {
            alertMessage = "저장 이미지를 만드는 데 실패했습니다."
            return
        }

        shareImage = image

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    alertMessage = "사진 보관함에 저장했습니다."
                case .denied, .restricted:
                    alertMessage = "사진 저장 권한이 필요합니다. 설정에서 사진 접근을 허용해 주세요."
                case .notDetermined:
                    alertMessage = "사진 권한 확인 후 다시 시도해 주세요."
                @unknown default:
                    alertMessage = "사진 저장 권한 상태를 확인할 수 없습니다."
                }
            }
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    alertMessage = nil
                }
            }
        )
    }
}

private struct ShareCardLayout: View {
    let monthTitle: String
    let weekdaySymbols: [String]
    let monthGridDates: [Date?]
    let todayCount: Int
    let currentStreak: Int
    let monthTotalCount: Int
    let countProvider: (Date) -> Int
    let isTodayProvider: (Date) -> Bool
    let dayProvider: (Date) -> Int

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.94, green: 0.98, blue: 0.95), Color.white, Color(red: 0.90, green: 0.97, blue: 0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("VerseGarden")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text(monthTitle)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    ShareStatCard(title: "오늘 필사", value: "\(todayCount)회")
                    ShareStatCard(title: "연속 기록", value: "\(currentStreak)일")
                    ShareStatCard(title: "이 달 총 필사", value: "\(monthTotalCount)회")
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("이번 달 잔디")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))

                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                        }

                        ForEach(Array(monthGridDates.enumerated()), id: \.offset) { _, date in
                            if let date {
                                ShareGrassCell(
                                    dayNumber: dayProvider(date),
                                    count: countProvider(date),
                                    isToday: isTodayProvider(date)
                                )
                            } else {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.clear)
                                    .frame(height: 42)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.84))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 8) {
                    Text("오늘도 한 구절, 천천히.")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("조용히 이어가는 말씀 루틴")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

private struct ShareStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.84))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ShareGrassCell: View {
    let dayNumber: Int
    let count: Int
    let isToday: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(dayNumber)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(count == 0 ? Color.secondary : Color.primary)
                .frame(maxWidth: .infinity, alignment: .center)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(GrassCell.fillColor(for: count))
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(GrassCell.strokeColor(for: count), lineWidth: 0.6)
                }
                .frame(width: 18, height: 18)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, minHeight: 42, maxHeight: 42, alignment: .top)
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isToday ? Color.green.opacity(0.8) : Color.clear, lineWidth: 1.2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
