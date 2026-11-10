import SwiftUI

struct ChapterGridView: View {
    @Environment(BibleStore.self) private var store
    let bookKey: String

    private let columns = [GridItem(.adaptive(minimum: 56), spacing: 10)]
    private let cell = RoundedRectangle(cornerRadius: 6)

    private var book: Book? { store.bible?.book(key: bookKey) }

    var body: some View {
        Group {
            if let book {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(book.chapters, id: \.chapter) { chapter in
                            NavigationLink(value: Position(bookKey: book.key, chapter: chapter.chapter)) {
                                Text("\(chapter.chapter)")
                                    .font(Theme.serif(.title3))
                                    .foregroundStyle(Theme.ink)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(Theme.paperAlt, in: cell)
                                    .overlay { cell.stroke(Theme.border, lineWidth: 1) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("Livro indisponível nesta tradução", systemImage: "book.closed")
            }
        }
        .background(Theme.paper)
        .navigationTitle(book?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
    }
}
