import Observation

@MainActor
@Observable
final class BibleStore {
        private(set) var translation: Translation
        private(set) var bible: Bible?
        private(set) var isLoading = false
        private(set) var error: String?

        init(translation: Translation = .kjf) {
                self.translation = translation
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
}
