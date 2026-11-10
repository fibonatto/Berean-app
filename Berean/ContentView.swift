import SwiftUI

struct ContentView: View {
    @Environment(BibleStore.self) private var store
    @State private var path = NavigationPath()
    @State private var query = ""
    @State private var isSearching = false

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
            .background(Theme.paper)
            .navigationTitle("Bíblia")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { TranslationMenu() }
            }
            .searchable(text: $query, isPresented: $isSearching, prompt: "Ir para… ex.: pv 1:1")
            .searchSuggestions {
                ForEach(suggestions, id: \.self) { reference in
                    Button { open(reference) } label: {
                        Text(title(of: reference)).font(Theme.serif(.body))
                    }
                }
            }
            .onSubmit(of: .search) {
                if let first = suggestions.first { open(first) }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .navigationDestination(for: BookRoute.self) { route in
                ChapterGridView(bookKey: route.bookKey)
            }
            .navigationDestination(for: Position.self) { position in
                ReaderView(position: position)
            }
            .navigationDestination(for: VerseRoute.self) { route in
                ReaderView(position: route.position, highlight: route.verses)
            }
        }
        .task {
            await store.load(store.translation)
            restoreLastPosition()
        }
    }

    private var suggestions: [Reference] {
        Array(store.references(matching: query).prefix(8))
    }

    private func title(of reference: Reference) -> String {
        store.bible.map { reference.title(in: $0) } ?? ""
    }

    private func open(_ reference: Reference) {
        query = ""
        isSearching = false
        path.append(BookRoute(bookKey: reference.bookKey))
        guard let chapter = reference.chapter else { return }
        let position = Position(bookKey: reference.bookKey, chapter: chapter)
        if let verse = reference.verse {
            let last = max(verse, reference.endVerse ?? verse)
            path.append(VerseRoute(position: position, verses: verse...last))
        } else {
            path.append(position)
        }
    }

    private func restoreLastPosition() {
        guard let last = store.lastPosition,
              store.bible?.book(key: last.bookKey)?.chapter(last.chapter) != nil
        else { return }
        path.append(BookRoute(bookKey: last.bookKey))
        path.append(last)
    }
}

#Preview {
    ContentView()
        .environment(BibleStore())
}
