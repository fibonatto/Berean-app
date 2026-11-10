import Foundation

nonisolated struct Bible: Codable, Sendable {
        let translation: String
        let source: String?
        let books: [Book]
}

nonisolated struct Book: Codable, Identifiable, Sendable {
        let id: String
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
                name = try container.decode(String.self, forKey: .name)
                abbrev = try container.decodeIfPresent(String.self, forKey: .abbrev) ?? id
                aliases = try container.decodeIfPresent([String].self, forKey: .aliases) ?? []
                chapters = try container.decode([Chapter].self, forKey: .chapters)
        }
}

nonisolated struct Chapter: Codable, Sendable {
        let chapter: Int
        let verses: [Verse]
}

nonisolated struct Verse: Codable, Sendable {
        let verse: Int
        let text: String
}

extension String {
        nonisolated var normalized: String {
                folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        }
}

extension Bible {
        nonisolated func verseText(bookNamePrefix: String, chapter: Int, verse: Int) -> String? {
                let prefix = bookNamePrefix.normalized
                return
                        books
                        .first { $0.name.normalized.hasPrefix(prefix) }?
                        .chapters.first { $0.chapter == chapter }?
                        .verses.first { $0.verse == verse }?
                        .text
        }
}

extension Bible {
        nonisolated static let newTestamentCount = 27

        nonisolated var oldTestament: [Book] { Array(books.dropLast(Self.newTestamentCount)) }
        nonisolated var newTestament: [Book] { Array(books.suffix(Self.newTestamentCount)) }

        nonisolated func book(id: String) -> Book? {
                books.first { $0.id == id }
        }
}

extension Book {
        nonisolated func chapter(_ number: Int) -> Chapter? {
                chapters.first { $0.chapter == number }
        }
}
