import Foundation
import Observation

@MainActor
@Observable
final class LibraryStore {
    private(set) var documents: [LibraryDocument] = []
    private(set) var declaredCategories: [LibraryCategory] = []
    private(set) var isLoaded = false

    var categories: [LibraryCategory] {
        Set(documents.map(\.kind))
            .map(category(for:))
            .sorted { ($0.order, $0.title) < ($1.order, $1.title) }
    }

    func load() async {
        guard !isLoaded else { return }
        let contents = await Task.detached(priority: .userInitiated) {
            LibraryLoader.loadAll()
        }.value
        documents = contents.documents
        declaredCategories = contents.categories
        isLoaded = true
    }

    func document(id: String) -> LibraryDocument? {
        documents.first { $0.id == id }
    }

    func category(for kind: String) -> LibraryCategory {
        declaredCategories.first { $0.id == kind }
            ?? LibraryCategory(
                id: kind,
                title: kind.capitalized,
                singularTitle: kind.capitalized,
                order: 1000
            )
    }

    func documents(of kind: String, language: String?) -> [LibraryDocument] {
        documents
            .filter { $0.kind == kind && $0.matches(language: language) }
            .sorted { lhs, rhs in
                (lhs.order ?? 1000, lhs.slug, lhs.language)
                    < (rhs.order ?? 1000, rhs.slug, rhs.language)
            }
    }
}
