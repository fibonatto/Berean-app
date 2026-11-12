import SwiftUI
import UIKit

struct DocumentView: View {
    @Environment(BibleStore.self) private var store
    @Environment(LibraryStore.self) private var library
    @Environment(\.dynamicTypeSize) private var systemTypeSize
    @AppStorage("readerSizeStep") private var sizeStep = 0
    @AppStorage("readerFont") private var readerFont = ReaderFont.newYork
    @AppStorage("readerSpacing") private var spacing = ReaderSpacing.normal
    @AppStorage("readerMargin") private var margin = ReaderMargin.normal
    @State private var query = ""
    @State private var collapsed: Set<Int> = []
    @State private var scrollID: String?
    @State private var showsSettings = false
    @State private var showsContents = false

    let documentID: String
    let onOpenReference: (Reference) -> Void

    private struct Item: Identifiable {
        enum Content {
            case title
            case heading(title: String, section: Int)
            case block(DocumentBlock)
            case footer
        }

        let id: String
        let content: Content
    }

    private var document: LibraryDocument? { library.document(id: documentID) }
    private var positionKey: String { "documentPosition.\(documentID)" }

    var body: some View {
        ScrollView {
            if let document {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(items(for: document)) { item in
                        itemView(item, document: document)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, margin.points + 6)
                .padding(.bottom, 32)
            }
        }
        .scrollPosition(id: $scrollID, anchor: .top)
        .background(Theme.paper)
        .font(readerFont.bodyFont)
        .foregroundStyle(Theme.ink)
        .lineSpacing(spacing.points)
        .dynamicTypeSize(ReaderStyle.textSize(system: systemTypeSize, step: sizeStep))
        .navigationTitle(document?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search in document"
        )
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .toolbar { toolbarContent }
        .overlay { noMatches }
        .sheet(isPresented: $showsSettings) {
            ReaderSettingsView(sample: document?.previewText ?? "")
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.paper)
        }
        .sheet(isPresented: $showsContents) {
            if let document {
                DocumentContentsView(
                    entries: contentsEntries(document),
                    hasQuestions: hasQuestions(document),
                    onSelect: jump(toSectionID:),
                    onGoToQuestion: { goToQuestion($0, in: document) }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.paper)
            }
        }
        .onAppear { scrollID = UserDefaults.standard.string(forKey: positionKey) }
        .onChange(of: scrollID) { _, newValue in
            guard query.isEmpty, let newValue else { return }
            UserDefaults.standard.set(newValue, forKey: positionKey)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if let document {
                if hasContents(document) {
                    Button { showsContents = true } label: {
                        Label("Contents", systemImage: "list.bullet")
                    }
                }
                ShareLink(item: document.plainText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
            Button { showsSettings = true } label: {
                Label("Reading settings", systemImage: "textformat.size")
            }
        }
    }

    @ViewBuilder
    private var noMatches: some View {
        if let document, !SearchText.tokens(query).isEmpty, items(for: document).count <= 2 {
            ContentUnavailableView.search(text: query)
        }
    }

    private func items(for document: LibraryDocument) -> [Item] {
        let terms = SearchText.tokens(query)
        let isFiltering = !terms.isEmpty
        var result = [Item(id: "top", content: .title)]
        for (sectionIndex, section) in document.sections.enumerated() {
            let blocks = section.blocks.enumerated().filter { element in
                guard isFiltering else { return true }
                let haystack = element.element.searchableText.normalized
                return terms.allSatisfy { haystack.contains($0) }
            }
            if isFiltering, blocks.isEmpty { continue }
            if let title = section.title {
                result.append(Item(
                    id: "s\(sectionIndex)",
                    content: .heading(title: title, section: sectionIndex)
                ))
            }
            guard isFiltering || !collapsed.contains(sectionIndex) else { continue }
            for element in blocks {
                result.append(Item(
                    id: "s\(sectionIndex).b\(element.offset)",
                    content: .block(element.element)
                ))
            }
        }
        result.append(Item(id: "footer", content: .footer))
        return result
    }

    @ViewBuilder
    private func itemView(_ item: Item, document: LibraryDocument) -> some View {
        switch item.content {
        case .title:
            header(document)
        case let .heading(title, section):
            sectionHeader(title, section: section, document: document)
        case let .block(block):
            blockView(block)
                .contextMenu {
                    if let text = quotation(for: block, in: document) {
                        Button {
                            UIPasteboard.general.string = text
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        ShareLink(item: text) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                }
        case .footer:
            footer(document)
        }
    }

    private func header(_ document: LibraryDocument) -> some View {
        VStack(spacing: 8) {
            Text(library.category(for: document.kind).singularTitle.uppercased())
                .font(Theme.serif(.footnote, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Theme.inkSoft)
            Text(document.title)
                .font(Theme.serif(.title, weight: .semibold))
                .multilineTextAlignment(.center)
            if let subtitle = document.subtitle {
                Text(subtitle)
                    .font(Theme.serif(.subheadline))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }
            Rectangle()
                .fill(Theme.border)
                .frame(width: 40, height: 1)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 10)
    }

    private func sectionHeader(_ title: String, section: Int, document: LibraryDocument) -> some View {
        let isCollapsible = document.sections.count > 1 && query.isEmpty
        let isCollapsed = collapsed.contains(section)
        return Button { toggle(section) } label: {
            HStack(spacing: 8) {
                Text(title.uppercased())
                    .font(Theme.serif(.caption, weight: .semibold))
                    .tracking(1.5)
                    .multilineTextAlignment(.leading)
                Spacer()
                if isCollapsible {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                }
            }
            .foregroundStyle(Theme.inkSoft)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isCollapsible)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func blockView(_ block: DocumentBlock) -> some View {
        switch block {
        case let .paragraph(number, text, proofs):
            VStack(alignment: .leading, spacing: 6) {
                paragraphText(number: number, text: text)
                proofsView(proofs)
            }
        case let .verse(lines):
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    inline(line)
                }
            }
        case let .qa(number, question, answer, proofs):
            VStack(alignment: .leading, spacing: 6) {
                questionText(number: number, question: question)
                inline(answer)
                proofsView(proofs)
            }
        case let .scripture(reference, caption):
            scriptureView(reference, caption: caption)
        }
    }

    private func paragraphText(number: String?, text: String) -> Text {
        guard let number else { return inline(text) }
        let label = Text(number)
            .font(Theme.serif(.caption2, weight: .semibold))
            .foregroundStyle(Theme.verseNumber)
            .baselineOffset(6)
        return Text("\(label) \(inline(text))")
    }

    private func questionText(number: Int, question: String) -> Text {
        let label = Text("\(number).")
            .font(Theme.serif(.subheadline, weight: .semibold))
            .foregroundStyle(Theme.verseNumber)
        let body = inline(question).fontWeight(.semibold)
        return Text("\(label) \(body)")
    }

    @ViewBuilder
    private func scriptureView(_ referenceText: String, caption: String?) -> some View {
        if let reference = store.references(matching: referenceText).first,
           let bible = store.bible,
           let chapterNumber = reference.chapter,
           let chapter = bible.book(key: reference.bookKey)?.chapter(chapterNumber) {
            let range = reference.verse.map { $0...max($0, reference.endVerse ?? $0) }
            let verses = chapter.verses.filter { range?.contains($0.verse) ?? true }
            VStack(alignment: .leading, spacing: 8) {
                if let caption {
                    Text(caption)
                        .font(Theme.serif(.subheadline, weight: .semibold))
                }
                ForEach(verses, id: \.verse) { verse in
                    scriptureVerse(verse)
                }
                Button { onOpenReference(reference) } label: {
                    Text("\(reference.title(in: bible)) · \(store.translation.title)")
                        .font(Theme.serif(.footnote))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
        } else {
            Text("Passage unavailable: \(referenceText)")
                .font(Theme.serif(.footnote))
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private func scriptureVerse(_ verse: Verse) -> Text {
        let number = Text("\(verse.verse)")
            .font(Theme.serif(.caption2, weight: .semibold))
            .foregroundStyle(Theme.verseNumber)
            .baselineOffset(6)
        return Text("\(number) \(verse.text)")
    }

    @ViewBuilder
    private func proofsView(_ proofs: [String]) -> some View {
        let references = proofs.compactMap { store.references(matching: $0).first }
        if !references.isEmpty, let bible = store.bible {
            Text(proofsText(references, in: bible))
                .font(Theme.serif(.footnote))
                .foregroundStyle(Theme.inkSoft)
                .environment(\.openURL, OpenURLAction { url in
                    guard let index = url.host.flatMap(Int.init),
                          references.indices.contains(index)
                    else { return .discarded }
                    onOpenReference(references[index])
                    return .handled
                })
        }
    }

    private func proofsText(_ references: [Reference], in bible: Bible) -> AttributedString {
        var result = AttributedString("Proofs: ")
        for (index, reference) in references.enumerated() {
            if index > 0 { result.append(AttributedString("; ")) }
            var item = AttributedString(reference.title(in: bible))
            item.link = URL(string: "berean-proof://\(index)")
            item.foregroundColor = Theme.accent
            result.append(item)
        }
        return result
    }

    private func footer(_ document: LibraryDocument) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let source = document.source { Text("Source: \(source)") }
            if let license = document.license { Text("License: \(license)") }
        }
        .font(Theme.serif(.caption))
        .foregroundStyle(Theme.inkSoft)
        .padding(.top, 16)
    }

    private func inline(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        guard let attributed = try? AttributedString(markdown: text, options: options) else {
            return Text(text)
        }
        return Text(attributed)
    }

    private static func plain(_ text: String) -> String {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        guard let attributed = try? AttributedString(markdown: text, options: options) else {
            return text
        }
        return String(attributed.characters)
    }

    private func quotation(for block: DocumentBlock, in document: LibraryDocument) -> String? {
        switch block {
        case let .paragraph(number, text, _):
            let source = number.map { "\(document.title), \($0)" } ?? document.title
            return "\(Self.plain(text))\n— \(source)"
        case let .verse(lines):
            return "\(lines.map(Self.plain).joined(separator: "\n"))\n— \(document.title)"
        case let .qa(number, question, answer, _):
            return "\(number). \(Self.plain(question))\n\(Self.plain(answer))\n— \(document.title), Q. \(number)"
        case .scripture:
            return nil
        }
    }

    private func hasQuestions(_ document: LibraryDocument) -> Bool {
        document.sections.contains { section in
            section.blocks.contains { block in
                if case .qa = block { return true }
                return false
            }
        }
    }

    private func hasContents(_ document: LibraryDocument) -> Bool {
        document.sections.filter { $0.title != nil }.count > 1 || hasQuestions(document)
    }

    private func contentsEntries(_ document: LibraryDocument) -> [ContentsEntry] {
        var entries: [ContentsEntry] = []
        for (index, section) in document.sections.enumerated() {
            guard let title = section.title else { continue }
            let numbers = section.blocks.compactMap { block -> Int? in
                if case let .qa(number, _, _, _) = block { return number }
                return nil
            }
            var detail: String?
            if let first = numbers.first, let last = numbers.last {
                detail = first == last ? "Q. \(first)" : "Q. \(first)–\(last)"
            }
            entries.append(ContentsEntry(id: "s\(index)", title: title, detail: detail))
        }
        return entries
    }

    private func toggle(_ section: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if collapsed.contains(section) {
                collapsed.remove(section)
            } else {
                collapsed.insert(section)
            }
        }
    }

    private func scroll(to id: String) {
        Task {
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.easeInOut(duration: 0.25)) { scrollID = id }
        }
    }

    private func jump(toSectionID id: String) {
        query = ""
        if let index = Int(id.dropFirst()) {
            collapsed.remove(index)
        }
        scroll(to: id)
    }

    private func goToQuestion(_ number: Int, in document: LibraryDocument) -> Bool {
        for (sectionIndex, section) in document.sections.enumerated() {
            for (blockIndex, block) in section.blocks.enumerated() {
                if case let .qa(candidate, _, _, _) = block, candidate == number {
                    query = ""
                    collapsed.remove(sectionIndex)
                    scroll(to: "s\(sectionIndex).b\(blockIndex)")
                    return true
                }
            }
        }
        return false
    }
}
