import SwiftUI

enum LibraryLanguage: String, CaseIterable, Identifiable {
    case automatic, english, portuguese, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .english: "English"
        case .portuguese: "Português"
        case .all: "All languages"
        }
    }

    func code(following translation: Translation) -> String? {
        switch self {
        case .automatic: translation.language
        case .english: "en"
        case .portuguese: "pt"
        case .all: nil
        }
    }
}

struct LibraryView: View {
    @Environment(BibleStore.self) private var store
    @Environment(LibraryStore.self) private var library
    @AppStorage("libraryCollapsed") private var collapsedKinds = ""
    @State private var language = LibraryLanguage.automatic

    private var languageCode: String? { language.code(following: store.translation) }

    private var collapsed: Set<String> {
        Set(collapsedKinds.split(separator: ",").map(String.init))
    }

    private var visibleCount: Int {
        library.documents.filter { $0.matches(language: languageCode) }.count
    }

    private var hiddenCount: Int { library.documents.count - visibleCount }

    var body: some View {
        List {
            ForEach(library.categories) { category in
                let documents = library.documents(of: category.id, language: languageCode)
                if !documents.isEmpty {
                    Section {
                        if !collapsed.contains(category.id) {
                            ForEach(documents) { document in row(document) }
                        }
                    } header: {
                        header(category, count: documents.count)
                    }
                }
            }
            if hiddenCount > 0, visibleCount > 0 {
                Button("Show \(hiddenCount) in other languages") { language = .all }
                    .font(Theme.serif(.footnote))
                    .listRowBackground(Theme.paper)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .overlay { emptyState }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { languageMenu }
        }
        .task { await library.load() }
    }

    @ViewBuilder
    private var emptyState: some View {
        if library.isLoaded {
            if library.documents.isEmpty {
                ContentUnavailableView(
                    "No documents",
                    systemImage: "books.vertical",
                    description: Text("Add library-*.json files to Resources/Library.")
                )
            } else if visibleCount == 0 {
                ContentUnavailableView {
                    Label("No documents in this language", systemImage: "globe")
                } description: {
                    Text("Change the language filter to see documents in other languages.")
                } actions: {
                    Button("Show all languages") { language = .all }
                }
            }
        }
    }

    private var languageMenu: some View {
        Menu {
            Picker("Language", selection: $language) {
                ForEach(LibraryLanguage.allCases) { Text($0.title).tag($0) }
            }
        } label: {
            Text((languageCode ?? "all").uppercased())
                .font(Theme.serif(.subheadline, weight: .semibold))
        }
    }

    private func header(_ category: LibraryCategory, count: Int) -> some View {
        let isCollapsed = collapsed.contains(category.id)
        return Button { toggle(category) } label: {
            HStack(spacing: 8) {
                Text(category.title.uppercased())
                    .font(Theme.serif(.caption, weight: .semibold))
                    .tracking(1.5)
                Text("\(count)")
                    .font(Theme.serif(.caption2))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
            }
            .foregroundStyle(Theme.inkSoft)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isCollapsed ? "Collapsed" : "Expanded")
    }

    private func toggle(_ category: LibraryCategory) {
        var current = collapsed
        if current.contains(category.id) {
            current.remove(category.id)
        } else {
            current.insert(category.id)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            collapsedKinds = current.sorted().joined(separator: ",")
        }
    }

    private func row(_ document: LibraryDocument) -> some View {
        NavigationLink(value: DocumentRoute(id: document.id)) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(document.title)
                        .font(Theme.serif(.body))
                        .foregroundStyle(Theme.ink)
                    if let subtitle = document.subtitle {
                        Text(subtitle)
                            .font(Theme.serif(.footnote))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Spacer()
                if document.language != "any" {
                    Text(document.language.uppercased())
                        .font(Theme.serif(.caption2, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .listRowBackground(Theme.paper)
        .listRowSeparatorTint(Theme.border)
    }
}
