nonisolated struct BookRoute: Hashable {
        let bookID: String
}

nonisolated struct ChapterRoute: Hashable {
        let bookID: String
        let chapter: Int
}
