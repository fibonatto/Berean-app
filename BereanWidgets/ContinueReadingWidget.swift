import SwiftUI
import WidgetKit

nonisolated struct ReadingEntry: TimelineEntry {
    let date: Date
    let title: String
    let translation: String
    let link: URL?
}

nonisolated struct ReadingProvider: TimelineProvider {
    private static let fallback = ReadingEntry(
        date: .now,
        title: "Open Berean",
        translation: "",
        link: nil
    )

    func placeholder(in context: Context) -> ReadingEntry {
        ReadingEntry(date: .now, title: "John 3", translation: "KJV", link: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadingEntry) -> Void) {
        completion(Self.entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadingEntry>) -> Void) {
        completion(Timeline(entries: [Self.entry()], policy: .never))
    }

    private static func entry() -> ReadingEntry {
        guard let reading = WidgetSnapshotStore.load()?.reading else { return fallback }
        return ReadingEntry(
            date: .now,
            title: reading.title,
            translation: reading.translation,
            link: URL(string: reading.link)
        )
    }
}

struct ReadingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ReadingEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text(entry.translation.isEmpty ? entry.title : "\(entry.title) · \(entry.translation)")
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text("Continue reading").font(.caption)
                    Text(entry.title).font(.headline)
                }
            default:
                card
            }
        }
        .widgetURL(entry.link)
        .containerBackground(WidgetPalette.paper, for: .widget)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CONTINUE READING")
                .font(.system(.caption2, design: .serif, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(WidgetPalette.inkSoft)
            Spacer(minLength: 0)
            Text(entry.title)
                .font(.system(family == .systemSmall ? .title2 : .largeTitle, design: .serif))
                .foregroundStyle(WidgetPalette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Rectangle()
                .fill(WidgetPalette.border)
                .frame(width: 28, height: 1)
            Text(entry.translation)
                .font(.system(.footnote, design: .serif))
                .foregroundStyle(WidgetPalette.reference)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ContinueReadingWidget: Widget {
    let kind = "ContinueReading"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadingProvider()) { entry in
            ReadingWidgetView(entry: entry)
        }
        .configurationDisplayName("Continue Reading")
        .description("Jump back to the last chapter you were reading.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryRectangular])
    }
}
