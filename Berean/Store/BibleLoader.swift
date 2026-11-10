import Foundation

nonisolated enum BibleLoaderError: Error {
    case fileNotFound(String)
}

nonisolated enum BibleLoader {
    static func load(_ translation: Translation) throws -> Bible {
        let bundle = Bundle.main
        guard let url = bundle.url(forResource: translation.fileName, withExtension: "json")
            ?? bundle.url(forResource: translation.fileName, withExtension: "json", subdirectory: "Bibles")
        else {
            throw BibleLoaderError.fileNotFound(translation.fileName)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Bible.self, from: data)
    }
}