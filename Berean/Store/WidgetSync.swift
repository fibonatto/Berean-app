import Foundation
import WidgetKit

enum WidgetSync {
    private static let daysAhead = 30
    
    static func update(store: BibleStore) {
        guard let bible = store.bible else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let verses = (0..<daysAhead).compactMap { offset -> WidgetSnapshot.Verse? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return verse(on: day, store: store, bible: bible)
        }
        WidgetSnapshotStore.save(WidgetSnapshot(
            translation: store.translation.title,
            verses: verses,
            reading: reading(store: store, bible: bible)
        ))
#if DEBUG
        print("[Widget] saved \(verses.count) verses for \(store.translation.title)")
#endif
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    static func updateReading(store: BibleStore) {
        guard let bible = store.bible,
              let reading = reading(store: store, bible: bible)
                else { return }
        guard var snapshot = WidgetSnapshotStore.load() else {
            update(store: store)
            return
        }
        snapshot.reading = reading
        WidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: "ContinueReading")
    }
    
    private static func reading(store: BibleStore, bible: Bible) -> WidgetSnapshot.Reading? {
        guard let last = store.lastPosition, let book = bible.book(key: last.bookKey) else {
            return nil
        }
        let reference = Reference(bookKey: last.bookKey, chapter: last.chapter, verse: nil, endVerse: nil)
        return WidgetSnapshot.Reading(
            title: "\(book.name) \(last.chapter)",
            translation: store.translation.title,
            link: DeepLink.url(for: reference).absoluteString
        )
    }
    
    private static func verse(on day: Date, store: BibleStore, bible: Bible) -> WidgetSnapshot.Verse? {
        guard let resolved = DailyVerseResolver.resolve(on: day, store: store, bible: bible) else {
            return nil
        }
        return WidgetSnapshot.Verse(
            day: WidgetSnapshotStore.dayKey(for: day),
            reference: resolved.title,
            text: resolved.text,
            link: DeepLink.url(for: resolved.reference).absoluteString
        )
    }
}
