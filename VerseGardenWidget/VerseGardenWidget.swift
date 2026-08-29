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

    private var verseURL: URL? {
        URL(string: entry.data.verseDeepLinkURLString)
    }

    private var writingURL: URL? {
        entry.data.writingDeepLinkURLString.flatMap(URL.init(string:))
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
        .widgetURL(verseURL)
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
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 10) {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.09, green: 0.39, blue: 0.20))
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    Link(destination: verseURL ?? URL(string: AppGroupKeys.todayVerseURL)!) {
                        widgetActionLabel("말씀 보기", icon: "book.pages", size: .medium)
                    }
                    .accessibilityLabel("오늘의 말씀 보기")

                    if let writingURL {
                        Link(destination: writingURL) {
                            widgetActionLabel("필사하기", icon: "pencil.line", size: .medium)
                        }
                        .accessibilityLabel("오늘의 말씀 필사하기")
                    }
                }
            }
            .frame(width: 122, alignment: .trailing)
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

            VStack(alignment: .leading, spacing: 12) {
                Text(entry.data.text)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(Color(red: 0.07, green: 0.12, blue: 0.09))
                    .lineSpacing(3)
                    .lineLimit(5)
                    .minimumScaleFactor(0.76)

                HStack(spacing: 8) {
                    Text(entry.data.reference)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.09, green: 0.39, blue: 0.20))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.94, green: 0.97, blue: 0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Spacer(minLength: 0)
                }

                VStack(spacing: 5) {
                    paperRule
                    paperRule
                }
                .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(red: 0.99, green: 0.99, blue: 0.96).opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(red: 0.09, green: 0.39, blue: 0.20).opacity(0.12), lineWidth: 1)
            }

            HStack(spacing: 12) {
                Link(destination: verseURL ?? URL(string: AppGroupKeys.todayVerseURL)!) {
                    widgetActionLabel("말씀 보기", icon: "book.pages", size: .large)
                }
                .accessibilityLabel("오늘의 말씀 보기")

                if let writingURL {
                    Link(destination: writingURL) {
                        widgetActionLabel("필사하기", icon: "pencil.line", size: .large)
                    }
                    .accessibilityLabel("오늘의 말씀 필사하기")
                }
            }

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

    private var paperRule: some View {
        Rectangle()
            .fill(Color(red: 0.09, green: 0.39, blue: 0.20).opacity(0.08))
            .frame(height: 1)
    }

    private func widgetActionLabel(
        _ title: String,
        icon: String,
        size: WidgetActionSize
    ) -> some View {
        Label(title, systemImage: icon)
            .font(size.font)
            .foregroundStyle(Color(red: 0.09, green: 0.39, blue: 0.20))
            .lineLimit(1)
            .labelStyle(.titleAndIcon)
            .imageScale(size.imageScale)
            .frame(maxWidth: .infinity, minHeight: size.minimumHeight)
            .padding(.horizontal, size.horizontalPadding)
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .stroke(Color(red: 0.09, green: 0.39, blue: 0.20).opacity(0.12), lineWidth: 1)
            }
    }

}

private enum WidgetActionSize {
    case medium
    case large

    var font: Font {
        switch self {
        case .medium:
            .subheadline.weight(.semibold)
        case .large:
            .subheadline.weight(.semibold)
        }
    }

    var imageScale: Image.Scale {
        switch self {
        case .medium:
            .medium
        case .large:
            .large
        }
    }

    var minimumHeight: CGFloat {
        switch self {
        case .medium:
            46
        case .large:
            50
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .medium:
            8
        case .large:
            10
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .medium:
            13
        case .large:
            15
        }
    }
}

struct VerseGardenWidget: Widget {
    let kind = AppGroupKeys.widgetKind

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
