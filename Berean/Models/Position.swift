nonisolated struct Position: Hashable, Codable, Sendable {
    let bookKey: String
    let chapter: Int
}

extension Bible {
    nonisolated func position(after position: Position) -> Position? {
        guard let index = books.firstIndex(where: { $0.key == position.bookKey }) else { return nil }
        if let next = books[index].chapters.first(where: { $0.chapter > position.chapter }) {
            return Position(bookKey: position.bookKey, chapter: next.chapter)
        }
        guard books.indices.contains(index + 1),
              let first = books[index + 1].chapters.first
        else { return nil }
        return Position(bookKey: books[index + 1].key, chapter: first.chapter)
    }

    nonisolated func position(before position: Position) -> Position? {
        guard let index = books.firstIndex(where: { $0.key == position.bookKey }) else { return nil }
        if let previous = books[index].chapters.last(where: { $0.chapter < position.chapter }) {
            return Position(bookKey: position.bookKey, chapter: previous.chapter)
        }
        guard index > 0, let last = books[index - 1].chapters.last else { return nil }
        return Position(bookKey: books[index - 1].key, chapter: last.chapter)
    }

    nonisolated func resolve(_ position: Position) -> Position? {
        if let book = book(key: position.bookKey) {
            guard let first = book.chapters.first else { return nil }
            let chapter = book.chapters.last(where: { $0.chapter <= position.chapter }) ?? first
            return Position(bookKey: book.key, chapter: chapter.chapter)
        }
        guard let book = nearestBook(to: position.bookKey),
              let first = book.chapters.first
        else { return nil }
        return Position(bookKey: book.key, chapter: first.chapter)
    }

    private nonisolated func nearestBook(to key: String) -> Book? {
        guard let rank = Canon.rank(of: key) else { return nil }
        return books.last(where: { (Canon.rank(of: $0.key) ?? .max) < rank }) ?? books.first
    }
}
