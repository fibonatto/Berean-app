import Foundation

nonisolated enum AppGroup {
    static let identifier = "group.dev.fibonatto.Berean"
    static let snapshotFileName = "widget-snapshot.json"
}

nonisolated struct WidgetSnapshot: Codable, Sendable {
    struct Verse: Codable, Sendable {
        let day: String
        let reference: String
        let text: String
        let link: String
    }

    struct Reading: Codable, Sendable {
        let title: String
        let translation: String
        let link: String
    }

    var translation: String
    var verses: [Verse]
    var reading: Reading?
}

nonisolated enum WidgetSnapshotStore {
    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppGroup.identifier)?
            .appendingPathComponent(AppGroup.snapshotFileName)
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let url = fileURL else {
            #if DEBUG
            print("[Widget] App Group container unavailable for \(AppGroup.identifier). Check the App Groups capability on both targets.")
            #endif
            return
        }
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            #if DEBUG
            print("[Widget] Could not write snapshot: \(error)")
            #endif
        }
    }

    static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
