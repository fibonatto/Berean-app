import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(BibleStore.self) private var store
    @State private var path = NavigationPath()
    @State private var query = ""
    @State private var isSearching = false
    @State private var handledDeepLink = false
    @AppStorage("resumeOnLaunch") private var resumeOnLaunch = true
    @Environment(\.scenePhase) private var scenePhase
    

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let bible = store.bible {
                    TodayView(bible: bible, onOpen: open)
                } else if let error = store.error {
                    ContentUnavailableView(
                        "Could not load",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    ProgressView()
                }
            }
            .background(Theme.paper)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    NavigationLink(value: MarksRoute()) {
                        Label("Favorites and highlights", systemImage: "bookmark")
                    }
                    NavigationLink(value: LibraryRoute()) {
                        Label("Library", systemImage: "books.vertical")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink(value: SearchRoute()) {
                        Label("Search text", systemImage: "magnifyingglass")
                    }
                    TranslationMenu()
                }
            }
            .searchable(text: $query, isPresented: $isSearching, prompt: "Go to… e.g. john 3:16")
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
            .navigationDestination(for: SearchRoute.self) { _ in
                SearchView(onSelect: openHit)
            }
            .navigationDestination(for: MarksRoute.self) { _ in
                MarksView(onSelect: openMark)
            }
            .navigationDestination(for: LibraryRoute.self) { _ in
                LibraryView()
            }
            .navigationDestination(for: DocumentRoute.self) { route in
                DocumentView(documentID: route.id, onOpenReference: open)
            }
            .navigationDestination(for: PlansRoute.self) { _ in
                PlansView()
            }
            .navigationDestination(for: PlanRoute.self) { route in
                PlanDetailView(planID: route.id, onOpenReference: open)
            }
            .navigationDestination(for: BooksRoute.self) { _ in
                if let bible = store.bible {
                    BookListView(bible: bible)
                        .navigationTitle("Bible")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
        .onOpenURL { url in
            guard let reference = DeepLink.reference(from: url) else { return }
            handledDeepLink = true
            path = NavigationPath()
            open(reference)
        }
        .task {
            await store.load(store.translation)
            if resumeOnLaunch && !handledDeepLink { restoreLastPosition() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { WidgetSync.update(store: store) }
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

    private func openHit(_ hit: SearchHit) {
        Task {
            await store.select(hit.translation)
            let position = Position(bookKey: hit.bookKey, chapter: hit.chapter)
            path.append(VerseRoute(position: position, verses: hit.verse...hit.verse))
        }
    }

    private func openMark(_ mark: VerseMark) {
        let position = Position(bookKey: mark.bookKey, chapter: mark.chapter)
        path.append(VerseRoute(position: position, verses: mark.verse...mark.verse))
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
        .environment(SearchModel())
        .environment(LibraryStore())
        .environment(PlanStore())
        .modelContainer(for: [VerseMark.self, PlanEnrollment.self], inMemory: true)
}
