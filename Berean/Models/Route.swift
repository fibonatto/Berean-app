nonisolated struct BookRoute: Hashable {
    let bookKey: String
}

nonisolated struct VerseRoute: Hashable {
    let position: Position
    let verses: ClosedRange<Int>
}

nonisolated struct SearchRoute: Hashable {}

nonisolated struct MarksRoute: Hashable {}

nonisolated struct LibraryRoute: Hashable {}

nonisolated struct DocumentRoute: Hashable {
    let id: String
}
