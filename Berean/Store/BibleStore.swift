import Foundation
import Observation

@MainActor
@Observable
final class BibleStore {
    private(set) var translation: Translation
    private(set) var bible: Bible?
    private(set) var resolver: ReferenceResolver?
    private(set) var isLoading = false
    private(set) var error: String?
    private(set) var lastPosition: Position?

    private enum Key {
        static let translation = "translation"
        static let position = "lastPosition"
    }

    init() {
        let defaults = UserDefaults.standard
        translation = defaults.string(forKey: Key.translation)
            .flatMap(Translation.init(rawValue:)) ?? .kjf
        lastPosition = defaults.data(forKey: Key.position)
            .flatMap { try? JSONDecoder().decode(Position.self, from: $0) }
    }

    func select(_ translation: Translation) async {
        guard translation != self.translation || bible == nil else { return }
        UserDefaults.standard.set(translation.rawValue, forKey: Key.translation)
        await load(translation)
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
            resolver = ReferenceResolver(bible: loaded)
            reconcilePosition(with: loaded)
        } catch {
            guard self.translation == translation else { return }
            bible = nil
            resolver = nil
            self.error = String(describing: error)
        }
        isLoading = false
    }

    func remember(_ position: Position) {
        lastPosition = position
        UserDefaults.standard.set(try? JSONEncoder().encode(position), forKey: Key.position)
    }

    func references(matching input: String) -> [Reference] {
        guard let bible, let resolver else { return [] }
        return resolver.matches(for: input).filter { reference in
            guard let chapter = reference.chapter else { return true }
            return bible.book(key: reference.bookKey)?.chapter(chapter) != nil
        }
    }

    private func reconcilePosition(with bible: Bible) {
        guard let last = lastPosition,
              let resolved = bible.resolve(last),
              resolved != last
        else { return }
        remember(resolved)
    }
}
