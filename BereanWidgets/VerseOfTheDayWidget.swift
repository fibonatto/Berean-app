//
//  VerseOfTheDayWidget.swift
//  Berean
//
//  Created by Sergio Bonatto on 12/11/26.
//

import SwiftUI
import WidgetKit

nonisolated struct VerseEntry: TimelineEntry {
    let date: Date
    let reference: String
    let text: String
    let translation: String
    let link: URL?
}

nonisolated struct VerseProvider: TimelineProvider {
    private static let fallback = VerseEntry(
        date: .now,
        reference: "Berean",
        text: "Open the app once to load the verse of the day.",
        translation: "",
        link: nil
    )

    func placeholder(in context: Context) -> VerseEntry {
        VerseEntry(
            date: .now,
            reference: "John 3:16",
            text: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.",
            translation: "KJV",
            link: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (VerseEntry) -> Void) {
        completion(Self.entries().first ?? Self.fallback)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VerseEntry>) -> Void) {
        let entries = Self.entries()
        completion(Timeline(entries: entries.isEmpty ? [Self.fallback] : entries, policy: .atEnd))
    }

    private static func entries() -> [VerseEntry] {
        guard let snapshot = WidgetSnapshotStore.load() else { return [] }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        return snapshot.verses.compactMap { verse in
            guard let day = formatter.date(from: verse.day), day >= startOfToday else { return nil }
            return VerseEntry(
                date: day <= now ? now : day,
                reference: verse.reference,
                text: verse.text,
                translation: snapshot.translation,
                link: URL(string: verse.link)
            )
        }
    }
}

struct VerseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VerseEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.reference).font(.headline)
                    Text(entry.text).font(.caption).lineLimit(3)
                }
            default:
                card
            }
        }
        .widgetURL(entry.link)
        .containerBackground(WidgetPalette.paper, for: .widget)
    }

    private var textStyle: Font.TextStyle {
        switch family {
        case .systemSmall: .footnote
        case .systemLarge: .title3
        default: .callout
        }
    }

    private var lineLimit: Int {
        switch family {
        case .systemSmall: 6
        case .systemLarge: 12
        default: 4
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            if family != .systemSmall {
                Text("VERSE OF THE DAY")
                    .font(.system(.caption2, design: .serif, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(WidgetPalette.inkSoft)
            }
            Text(entry.text)
                .font(.system(textStyle, design: .serif))
                .foregroundStyle(WidgetPalette.ink)
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
            HStack {
                Text(entry.reference)
                    .font(.system(.footnote, design: .serif, weight: .semibold))
                    .foregroundStyle(WidgetPalette.reference)
                Spacer()
                Text(entry.translation)
                    .font(.caption2)
                    .foregroundStyle(WidgetPalette.inkSoft)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VerseOfTheDayWidget: Widget {
    let kind = "VerseOfTheDay"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VerseProvider()) { entry in
            VerseWidgetView(entry: entry)
        }
        .configurationDisplayName("Verse of the Day")
        .description("A verse from your current translation, changing every day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}
