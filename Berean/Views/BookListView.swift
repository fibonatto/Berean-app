import SwiftUI

struct BookListView: View {
        let bible: Bible

        var body: some View {
                List {
                        Section("Antigo Testamento") { rows(bible.oldTestament) }
                        Section("Novo Testamento") { rows(bible.newTestament) }
                }
        }

        private func rows(_ books: [Book]) -> some View {
                ForEach(books) { book in
                        NavigationLink(book.name, value: BookRoute(bookID: book.id))
                }
        }
}
