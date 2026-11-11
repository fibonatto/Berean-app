import SwiftData
import SwiftUI
import UIKit

struct ReaderView: View {
    @Environment(BibleStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var systemTypeSize
    @AppStorage("readerSizeStep") private var sizeStep = 0
    @AppStorage("readerFont") private var readerFont = ReaderFont.newYork
    @AppStorage("readerSpacing") private var spacing = ReaderSpacing.normal
    @AppStorage("readerMargin") private var margin = ReaderMargin.normal
    @Query private var marks: [VerseMark]
    @State private var position: Position
    @State private var highlight: ClosedRange<Int>?
    @State private var selected: Set<Int> = []
    @State private var showsCopied = false
    @State private var showsSettings = false

    private let rowShape = RoundedRectangle(cornerRadius: 6)

    init(position: Position, highlight: ClosedRange<Int>? = nil) {
        _position = State(initialValue: position)
        _highlight = State(initialValue: highlight)
    }

    private var book: Book? { store.bible?.book(key: position.bookKey) }
    private var chapter: Chapter? { book?.chapter(position.chapter) }
    private var previous: Position? { store.bible?.position(before: position) }
    private var next: Position? { store.bible?.position(after: position) }

    private var title: String {
        book.map { "\($0.name) \(position.chapter)" } ?? ""
    }

    private var chapterMarks: [Int: VerseMark] {
        marks
            .filter { $0.bookKey == position.bookKey && $0.chapter == position.chapter }
            .reduce(into: [:]) { $0[$1.verse] = $1 }
    }

    private var allFavorite: Bool {
        let current = chapterMarks
        return !selected.isEmpty && selected.allSatisfy { current[$0]?.isFavorite == true }
    }

    private var selectionText: String? {
        guard let book, let chapter, !selected.isEmpty else { return nil }
        let verses = chapter.verses.filter { selected.contains($0.verse) }
        guard !verses.isEmpty else { return nil }
        return VerseFormat.quotation(
            bookName: book.name,
            chapter: position.chapter,
            verses: verses,
            translation: store.translation.title
        )
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if let book, let chapter {
                    VStack(spacing: 0) {
                        chapterHeader(book: book)
                        verseList(chapter)
                    }
                    .padding(.horizontal, margin.points)
                    .padding(.bottom, 32)
                }
            }
            .id(position)
            .task(id: position) { await reveal(with: proxy) }
        }
        .background(Theme.paper)
        .font(readerFont.bodyFont)
        .foregroundStyle(Theme.ink)
        .lineSpacing(spacing.points)
        .dynamicTypeSize(ReaderStyle.textSize(system: systemTypeSize, step: sizeStep))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .overlay(alignment: .bottom) { copiedToast }
        .animation(.easeInOut(duration: 0.2), value: showsCopied)
        .sensoryFeedback(.selection, trigger: selected)
        .sensoryFeedback(.success, trigger: showsCopied) { _, isShown in isShown }
        .sheet(isPresented: $showsSettings) {
            ReaderSettingsView(sample: chapter?.verses.first?.text ?? "")
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.paper)
        }
        .simultaneousGesture(swipe)
        .onAppear { store.remember(position) }
        .onChange(of: position) { _, newValue in store.remember(newValue) }
        .onChange(of: store.lastPosition) { _, newValue in
            if let newValue, newValue != position { go(to: newValue) }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if selected.isEmpty {
                Button { showsSettings = true } label: {
                    Label("Ajustes de leitura", systemImage: "textformat.size")
                }
            } else {
                Button { selected = [] } label: {
                    Label("Limpar seleção", systemImage: "xmark")
                }
            }
        }
        ToolbarItemGroup(placement: .bottomBar) {
            if selected.isEmpty {
                navigationButtons
            } else {
                selectionButtons
            }
        }
    }

    @ViewBuilder
    private var navigationButtons: some View {
        Button { go(to: previous) } label: {
            Label("Capítulo anterior", systemImage: "chevron.left")
        }
        .disabled(previous == nil)
        Spacer()
        TranslationMenu()
        Spacer()
        Button { go(to: next) } label: {
            Label("Próximo capítulo", systemImage: "chevron.right")
        }
        .disabled(next == nil)
    }

    @ViewBuilder
    private var selectionButtons: some View {
        ForEach(MarkColor.allCases) { color in
            Button { applyHighlight(color) } label: {
                Circle()
                    .fill(color.color)
                    .overlay { Circle().stroke(Theme.border, lineWidth: 1) }
                    .frame(width: 24, height: 24)
            }
            .accessibilityLabel("Destacar em \(color.title.lowercased())")
        }
        Button { applyHighlight(nil) } label: {
            Label("Remover destaque", systemImage: "circle.slash")
        }
        Spacer()
        Button { toggleFavorite() } label: {
            Label("Favoritar", systemImage: allFavorite ? "star.fill" : "star")
        }
        Button { copySelection() } label: {
            Label("Copiar", systemImage: "doc.on.doc")
        }
        if let text = selectionText {
            ShareLink(item: text) {
                Label("Compartilhar", systemImage: "square.and.arrow.up")
            }
        }
    }

    @ViewBuilder
    private var copiedToast: some View {
        if showsCopied {
            Text("Copiado")
                .font(Theme.serif(.footnote, weight: .semibold))
                .foregroundStyle(Theme.paper)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.ink, in: Capsule())
                .padding(.bottom, 16)
                .transition(.opacity)
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard value.startLocation.x > 24,
                      abs(value.translation.width) > abs(value.translation.height) * 2
                else { return }
                go(to: value.translation.width < 0 ? next : previous)
            }
    }

    private func go(to target: Position?) {
        guard let target else { return }
        highlight = nil
        selected = []
        position = target
    }

    private func reveal(with proxy: ScrollViewProxy) async {
        guard let first = highlight?.lowerBound else { return }
        try? await Task.sleep(for: .milliseconds(150))
        proxy.scrollTo(first, anchor: UnitPoint(x: 0.5, y: 0.25))
    }

    private func toggle(_ verse: Int) {
        if selected.contains(verse) {
            selected.remove(verse)
        } else {
            selected.insert(verse)
        }
    }

    private func applyHighlight(_ color: MarkColor?) {
        update(selected) { $0.highlight = color?.rawValue }
        selected = []
    }

    private func toggleFavorite() {
        let makeFavorite = !allFavorite
        update(selected) { $0.isFavorite = makeFavorite }
        selected = []
    }

    private func update(_ verses: Set<Int>, change: (VerseMark) -> Void) {
        let existing = chapterMarks
        for verse in verses {
            let stored = existing[verse]
            let mark = stored ?? VerseMark(
                bookKey: position.bookKey,
                chapter: position.chapter,
                verse: verse
            )
            change(mark)
            if mark.highlight == nil, !mark.isFavorite {
                if stored != nil { context.delete(mark) }
            } else if stored == nil {
                context.insert(mark)
            }
        }
        try? context.save()
    }

    private func copySelection() {
        guard let text = selectionText else { return }
        UIPasteboard.general.string = text
        selected = []
        showsCopied = true
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            showsCopied = false
        }
    }

    private func chapterHeader(book: Book) -> some View {
        VStack(spacing: 8) {
            Text(book.name.uppercased())
                .font(Theme.serif(.footnote, weight: .semibold))
                .tracking(2)
                .foregroundStyle(Theme.inkSoft)
            Text("\(position.chapter)")
                .font(Theme.serif(.largeTitle))
                .foregroundStyle(Theme.ornament)
            Rectangle()
                .fill(Theme.border)
                .frame(width: 40, height: 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 28)
    }

    private func verseList(_ chapter: Chapter) -> some View {
        let current = chapterMarks
        return LazyVStack(alignment: .leading, spacing: 6) {
            ForEach(chapter.verses, id: \.verse) { verse in
                verseRow(verse, mark: current[verse.verse])
            }
        }
    }

    private func verseRow(_ verse: Verse, mark: VerseMark?) -> some View {
        let markColor = mark?.markColor
        let isTarget = highlight?.contains(verse.verse) == true
        let fill = markColor?.color ?? (isTarget ? Theme.highlight : Color.clear)
        return verseText(verse, onMark: markColor != nil, isFavorite: mark?.isFavorite == true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(fill, in: rowShape)
            .overlay {
                if selected.contains(verse.verse) {
                    rowShape.stroke(Theme.accent, lineWidth: 1.5)
                }
            }
            .contentShape(rowShape)
            .onTapGesture { toggle(verse.verse) }
            .id(verse.verse)
    }

    private func verseText(_ verse: Verse, onMark: Bool, isFavorite: Bool) -> Text {
        let number = Text("\(verse.verse)")
            .font(Theme.serif(.caption2, weight: .semibold))
            .foregroundStyle(onMark ? Theme.verseNumberOnMark : Theme.verseNumber)
            .baselineOffset(6)
        guard isFavorite else { return Text("\(number) \(verse.text)") }
        let star = Text(Image(systemName: "star.fill"))
            .font(.caption2)
            .foregroundStyle(Theme.star)
        return Text("\(number) \(verse.text) \(star)")
    }
}
