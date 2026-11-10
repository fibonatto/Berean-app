import SwiftUI

struct ContentView: View {
    @Environment(BibleStore.self) private var store
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let bible = store.bible {
                    BookListView(bible: bible)
                } else if let error = store.error {
                    ContentUnavailableView(
                        "Não foi possível carregar",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(store.translation.title)
            .navigationDestination(for: BookRoute.self) { route in
                if let book = store.bible?.book(id: route.bookID) {
                    ChapterGridView(book: book)
                }
            }
            .navigationDestination(for: Position.self) { position in
                ReaderView(position: position)
            }
        }
        .task {
            await store.load(store.translation)
            restoreLastPosition()
        }
    }

    private func restoreLastPosition() {
        guard let last = store.lastPosition,
              store.bible?.book(id: last.bookID)?.chapter(last.chapter) != nil
        else { return }
        path.append(BookRoute(bookID: last.bookID))
        path.append(last)
    }
}

#Preview {
    ContentView()
        .environment(BibleStore())
}
