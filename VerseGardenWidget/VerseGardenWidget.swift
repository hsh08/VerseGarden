import SwiftUI
import WidgetKit

struct VerseGardenWidgetEntry: TimelineEntry {
    let date: Date
    let data: VerseWidgetData
}

struct VerseGardenWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> VerseGardenWidgetEntry {
        VerseGardenWidgetEntry(date: Date(), data: VerseWidgetData.fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (VerseGardenWidgetEntry) -> Void) {
        completion(VerseGardenWidgetEntry(date: Date(), data: SharedVerseProvider.currentWidgetData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VerseGardenWidgetEntry>) -> Void) {
        let entry = VerseGardenWidgetEntry(date: Date(), data: SharedVerseProvider.currentWidgetData())
        completion(Timeline(entries: [entry], policy: .after(nextRefreshDate())))
    }

    private func nextRefreshDate() -> Date {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86_400)
        return calendar.startOfDay(for: tomorrow).addingTimeInterval(60)
    }
}

struct VerseGardenWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VerseGardenWidgetEntry

    private var widgetURL: URL? {
        URL(string: entry.data.deepLinkURLString)
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemLarge:
                largeView
            default:
                mediumView
            }
        }
        .widgetURL(widgetURL)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.98, blue: 0.94),
                    Color(red: 0.90, green: 0.95, blue: 0.89)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            label(entry.data.label)

            Text(entry.data.text)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundStyle(Color(red: 0.07, green: 0.12, blue: 0.09))
                .lineLimit(4)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 0)

            Text(entry.data.reference)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(red: 0.09, green: 0.39, blue: 0.20))
                .lineLimit(1)
        }
        .padding(4)
    }

    private var mediumView: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 9) {
                label(entry.data.label)

                Text(entry.data.text)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color(red: 0.07, green: 0.12, blue: 0.09))
                    .lineLimit(3)
                    .minimumScaleFactor(0.74)

                Text(entry.data.reference)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.09, green: 0.39, blue: 0.20))
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.09, green: 0.39, blue: 0.20))
                Spacer(minLength: 0)
                Text("앱에서 기록하기")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(red: 0.36, green: 0.42, blue: 0.37))
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(4)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                label(entry.data.label)
                Spacer()
                Image(systemName: "book.closed.fill")
                    .font(.headline)
                    .foregroundStyle(Color(red: 0.09, green: 0.39, blue: 0.20))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(entry.data.text)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color(red: 0.07, green: 0.12, blue: 0.09))
                    .lineSpacing(4)
                    .lineLimit(6)
                    .minimumScaleFactor(0.72)

                Text(entry.data.reference)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.09, green: 0.39, blue: 0.20))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Spacer(minLength: 0)

            HStack {
                Text("VerseGarden")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color(red: 0.36, green: 0.42, blue: 0.37))
                Spacer()
                Text("오늘도 한 구절")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.36, green: 0.42, blue: 0.37))
            }
        }
        .padding(4)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color(red: 0.09, green: 0.39, blue: 0.20))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.78))
            .clipShape(Capsule())
    }
}

struct VerseGardenWidget: Widget {
    let kind = "VerseGardenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseGardenWidgetProvider()) { entry in
            VerseGardenWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("VerseGarden 말씀")
        .description("홈 화면에서 오늘 가까이할 말씀을 확인합니다.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    VerseGardenWidget()
} timeline: {
    VerseGardenWidgetEntry(date: Date(), data: .fallback)
}
