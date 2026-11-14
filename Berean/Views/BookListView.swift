import SwiftUI

struct BookListView: View {
    let bible: Bible

    var body: some View {
        List {
            Section { rows(bible.oldTestament) } header: { header("Old Testament") }
            Section { rows(bible.newTestament) } header: { header("New Testament") }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
    }

    private func header(_ title: String) -> some View {
        Text(title.uppercased())
            .font(Theme.serif(.caption, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(Theme.inkSoft)
    }

    private func rows(_ books: [Book]) -> some View {
        ForEach(books) { book in
            NavigationLink(value: BookRoute(bookKey: book.key)) {
                Text(book.name)
                    .font(Theme.serif(.body))
                    .foregroundStyle(Theme.ink)
            }
            .listRowBackground(Theme.paper)
            .listRowSeparatorTint(Theme.border)
        }
    }
}
