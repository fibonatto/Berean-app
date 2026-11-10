import Foundation

nonisolated struct Bible: Decodable, Sendable {
    let translation: String
    let source: String?
    let books: [Book]
}

nonisolated struct Book: Decodable, Identifiable, Sendable {
    let id: String
    let key: String
    let name: String
    let abbrev: String
    let aliases: [String]
    let chapters: [Chapter]

    enum CodingKeys: String, CodingKey {
        case id, name, abbrev, aliases, chapters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        key = Canon.key(forBookID: id)
        name = try container.decode(String.self, forKey: .name)
        abbrev = try container.decodeIfPresent(String.self, forKey: .abbrev) ?? id
        aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
        chapters = try container.decode([Chapter].self, forKey: .chapters)
    }
}

nonisolated struct Chapter: Decodable, Sendable {
    let chapter: Int
    let verses: [Verse]
}

nonisolated struct Verse: Decodable, Sendable {
    let verse: Int
    let text: String
}

extension String {
    nonisolated var normalized: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}

extension Bible {
    nonisolated static let newTestamentCount = 27

    nonisolated var oldTestament: [Book] { Array(books.dropLast(Self.newTestamentCount)) }
    nonisolated var newTestament: [Book] { Array(books.suffix(Self.newTestamentCount)) }

    nonisolated func book(key: String) -> Book? {
        books.first { $0.key == key }
    }
}

extension Book {
    nonisolated func chapter(_ number: Int) -> Chapter? {
        chapters.first { $0.chapter == number }
    }
}
