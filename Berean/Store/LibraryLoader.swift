import Foundation

nonisolated struct LibraryContents: Sendable {
    var documents: [LibraryDocument] = []
    var categories: [LibraryCategory] = []
}

nonisolated enum LibraryLoader {
    static let categoriesFileName = "library.categories.json"

    static func loadAll() -> LibraryContents {
        guard let enumerator = FileManager.default.enumerator(
            at: Bundle.main.bundleURL,
            includingPropertiesForKeys: nil
        ) else { return LibraryContents() }

        var contents = LibraryContents()
        for case let url as URL in enumerator where url.pathExtension == "json" {
            let name = url.lastPathComponent
            do {
                if name == categoriesFileName {
                    let data = try Data(contentsOf: url)
                    contents.categories = try JSONDecoder().decode([LibraryCategory].self, from: data)
                } else if name.hasPrefix("library-") {
                    let data = try Data(contentsOf: url)
                    contents.documents.append(try JSONDecoder().decode(LibraryDocument.self, from: data))
                }
            } catch {
                assertionFailure("Invalid library file \(name): \(error)")
            }
        }
        return contents
    }
}
