import Foundation
import Observation

@MainActor
@Observable
final class BibleStore {
    private(set) var translation: Translation
    private(set) var bible: Bible?
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var lastPosition: Position?

    private static let positionKey = "lastPosition"

    init(translation: Translation = .kjf) {
        self.translation = translation
        lastPosition = UserDefaults.standard.data(forKey: Self.positionKey)
            .flatMap { try? JSONDecoder().decode(Position.self, from: $0) }
    }

    func load(_ translation: Translation) async {
        self.translation = translation
        isLoading = true
        error = nil
        do {
            let loaded = try await Task.detached(priority: .userInitiated) {
                try BibleLoader.load(translation)
            }.value
            guard self.translation == translation else { return }
            bible = loaded
        } catch {
            guard self.translation == translation else { return }
            bible = nil
            self.error = String(describing: error)
        }
        isLoading = false
    }

    func remember(_ position: Position) {
        lastPosition = position
        UserDefaults.standard.set(try? JSONEncoder().encode(position), forKey: Self.positionKey)
    }
}
