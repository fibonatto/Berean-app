nonisolated struct Position: Hashable, Codable, Sendable {
    let bookID: String
    let chapter: Int
}

extension Bible {
    nonisolated func position(after position: Position) -> Position? {
        guard let index = books.firstIndex(where: { $0.id == position.bookID }) else { return nil }
        if let next = books[index].chapters.first(where: { $0.chapter > position.chapter }) {
            return Position(bookID: position.bookID, chapter: next.chapter)
        }
        guard books.indices.contains(index + 1),
              let first = books[index + 1].chapters.first
        else { return nil }
        return Position(bookID: books[index + 1].id, chapter: first.chapter)
    }

    nonisolated func position(before position: Position) -> Position? {
        guard let index = books.firstIndex(where: { $0.id == position.bookID }) else { return nil }
        if let previous = books[index].chapters.last(where: { $0.chapter < position.chapter }) {
            return Position(bookID: position.bookID, chapter: previous.chapter)
        }
        guard index > 0, let last = books[index - 1].chapters.last else { return nil }
        return Position(bookID: books[index - 1].id, chapter: last.chapter)
    }
}
