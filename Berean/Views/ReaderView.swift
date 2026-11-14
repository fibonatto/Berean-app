import AVFoundation
import SwiftData
import SwiftUI
import UIKit

struct ReaderView: View {
    @Environment(BibleStore.self) private var store
    @Environment(ParallelStore.self) private var parallel
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var systemTypeSize
    @AppStorage("readerSizeStep") private var sizeStep = 0
    @AppStorage("readerFont") private var readerFont = ReaderFont.newYork
    @AppStorage("readerSpacing") private var spacing = ReaderSpacing.normal
    @AppStorage("readerMargin") private var margin = ReaderMargin.normal
    @AppStorage("speechVoice") private var voiceID = ""
    @AppStorage("speechRate") private var speechRate = 1.0
    @AppStorage("speechAutoAdvance") private var autoAdvance = true
    @AppStorage("parallelEnabled") private var parallelEnabled = false
    @AppStorage("parallelTranslation") private var parallelStored = ""
    @AppStorage("parallelLayout") private var parallelLayout = ParallelLayout.stacked
    @Query private var marks: [VerseMark]
    @State private var position: Position
    @State private var highlight: ClosedRange<Int>?
    @State private var selected: Set<Int> = []
    @State private var showsCopied = false
    @State private var showsSettings = false
    @State private var speech = SpeechController()
    @State private var noteTarget: NoteTarget?

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

    private var secondaryTranslation: Translation? {
        parallelEnabled
            ? ParallelChoice.resolve(stored: parallelStored, primary: store.translation)
            : nil
    }

    private var secondaryTitle: String { secondaryTranslation?.title ?? "" }

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
            .onChange(of: speech.currentVerse) { _, verse in
                guard let verse else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(verse, anchor: UnitPoint(x: 0.5, y: 0.35))
                }
            }
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
        .sheet(item: $noteTarget) { target in
            NoteEditorView(
                title: "\(book?.name ?? "") \(position.chapter):\(target.verse)",
                initialText: chapterMarks[target.verse]?.note ?? "",
                onSave: { saveNote($0, verse: target.verse) }
            )
        }
        .simultaneousGesture(swipe)
        .onAppear { store.remember(position) }
        .onDisappear { speech.stop() }
        .onChange(of: position) { _, newValue in store.remember(newValue) }
        .onChange(of: store.lastPosition) { _, newValue in
            if let newValue, newValue != position { go(to: newValue) }
        }
        .onChange(of: speech.completions) { advanceAfterSpeech() }
        .onChange(of: speechRate) { restartSpeech() }
        .task(id: secondaryTranslation) { await parallel.ensure(secondaryTranslation) }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if selected.isEmpty {
                Button { toggleSpeech() } label: {
                    Label(
                        speech.isSpeaking ? "Stop reading" : "Read aloud",
                        systemImage: speech.isSpeaking ? "speaker.slash.fill" : "speaker.wave.2"
                    )
                }
                Button { parallelEnabled.toggle() } label: {
                    Label(
                        "Parallel reading",
                        systemImage: parallelEnabled ? "rectangle.split.2x1.fill" : "rectangle.split.2x1"
                    )
                }
                Button { showsSettings = true } label: {
                    Label("Reading settings", systemImage: "textformat.size")
                }
            } else {
                if selected.count == 1, let verse = selected.first {
                    Button { noteTarget = NoteTarget(verse: verse) } label: {
                        Label("Note", systemImage: "note.text.badge.plus")
                    }
                }
                Button { startSpeech() } label: {
                    Label("Read aloud from here", systemImage: "speaker.wave.2")
                }
                Button { selected = [] } label: {
                    Label("Clear selection", systemImage: "xmark")
                }
            }
        }
        ToolbarItemGroup(placement: .bottomBar) {
            if !selected.isEmpty {
                selectionButtons
            } else if speech.isSpeaking {
                speechButtons
            } else {
                navigationButtons
            }
        }
    }

    @ViewBuilder
    private var navigationButtons: some View {
        Button { go(to: previous) } label: {
            Label("Previous chapter", systemImage: "chevron.left")
        }
        .disabled(previous == nil)
        Spacer()
        TranslationMenu()
        Spacer()
        Button { go(to: next) } label: {
            Label("Next chapter", systemImage: "chevron.right")
        }
        .disabled(next == nil)
    }

    @ViewBuilder
    private var speechButtons: some View {
        Button { speech.togglePause() } label: {
            Label(
                speech.isPaused ? "Resume" : "Pause",
                systemImage: speech.isPaused ? "play.fill" : "pause.fill"
            )
        }
        Spacer()
        Menu {
            Picker("Speed", selection: $speechRate) {
                ForEach(ReaderStyle.speechRates, id: \.self) {
                    Text(ReaderStyle.speedLabel($0)).tag($0)
                }
            }
        } label: {
            Text(ReaderStyle.speedLabel(speechRate))
                .font(Theme.serif(.subheadline, weight: .semibold))
        }
        Spacer()
        Button { speech.stop() } label: {
            Label("Stop reading", systemImage: "stop.fill")
        }
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
            .accessibilityLabel("Highlight in \(color.title.lowercased())")
        }
        Button { applyHighlight(nil) } label: {
            Label("Remove highlight", systemImage: "circle.slash")
        }
        Spacer()
        Button { toggleFavorite() } label: {
            Label("Favorite", systemImage: allFavorite ? "star.fill" : "star")
        }
        Button { copySelection() } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        if let text = selectionText {
            ShareLink(item: text) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }

    @ViewBuilder
    private var copiedToast: some View {
        if showsCopied {
            Text("Copied")
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
        speech.stop()
        highlight = nil
        selected = []
        position = target
    }

    private func reveal(with proxy: ScrollViewProxy) async {
        guard let first = highlight?.lowerBound else { return }
        try? await Task.sleep(for: .milliseconds(150))
        proxy.scrollTo(first, anchor: UnitPoint(x: 0.5, y: 0.25))
    }

    private func toggleSpeech() {
        if speech.isSpeaking {
            speech.stop()
        } else {
            startSpeech()
        }
    }

    private func startSpeech(from verse: Int? = nil) {
        guard let book, let chapter else { return }
        let first = verse ?? selected.min() ?? 0
        let verses = chapter.verses
            .filter { $0.verse >= first }
            .map { SpokenVerse(number: $0.verse, text: $0.text) }
        let word = store.translation.language == "pt" ? "capítulo" : "chapter"
        let header = first == 0 ? "\(book.name), \(word) \(position.chapter)" : nil
        selected = []
        speech.start(
            header: header,
            verses: verses,
            voice: SpeechVoices.resolve(
                identifier: voiceID,
                translationLanguage: store.translation.language
            ),
            rate: AVSpeechUtteranceDefaultSpeechRate * Float(speechRate)
        )
    }

    private func restartSpeech() {
        guard speech.isSpeaking else { return }
        startSpeech(from: speech.currentVerse ?? 1)
    }

    private func advanceAfterSpeech() {
        guard autoAdvance, let target = next else { return }
        highlight = nil
        selected = []
        position = target
        startSpeech()
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

    private func saveNote(_ text: String, verse: Int) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        update([verse]) { $0.note = trimmed.isEmpty ? nil : trimmed }
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
            if mark.isEmpty {
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

    private var columnHeader: some View {
        HStack(spacing: 14) {
            Text(store.translation.title)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(secondaryTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(Theme.serif(.caption, weight: .semibold))
        .tracking(1.5)
        .foregroundStyle(Theme.inkSoft)
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
    }

    private func secondaryTexts() -> [Int: String]? {
        guard let translation = secondaryTranslation, parallel.translation == translation else {
            return nil
        }
        guard let chapter = parallel.bible?.book(key: position.bookKey)?.chapter(position.chapter) else {
            return [:]
        }
        return chapter.verses.reduce(into: [:]) { $0[$1.verse] = $1.text }
    }

    private func verseList(_ chapter: Chapter) -> some View {
        let current = chapterMarks
        let secondary = secondaryTexts()
        return LazyVStack(alignment: .leading, spacing: 6) {
            if secondary != nil, parallelLayout == .columns {
                columnHeader
            }
            ForEach(chapter.verses, id: \.verse) { verse in
                verseRow(verse, mark: current[verse.verse], secondary: secondary)
            }
        }
    }

    private func verseRow(_ verse: Verse, mark: VerseMark?, secondary: [Int: String]?) -> some View {
        let markColor = mark?.markColor
        let isTarget = highlight?.contains(verse.verse) == true
        let isSpoken = speech.currentVerse == verse.verse
        let fill = markColor?.color ?? ((isTarget || isSpoken) ? Theme.highlight : Color.clear)
        let primary = verseText(verse, onMark: markColor != nil, isFavorite: mark?.isFavorite == true)
        return VStack(alignment: .leading, spacing: 6) {
            if let secondary, parallelLayout == .columns {
                HStack(alignment: .top, spacing: 14) {
                    primary
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(secondary[verse.verse] ?? "—")
                        .font(Theme.serif(.callout))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                primary
                if let secondary {
                    stackedSecondary(secondary[verse.verse])
                }
            }
            if let note = mark?.note, !note.isEmpty {
                noteBlock(note)
            }
        }
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

    private func stackedSecondary(_ text: String?) -> some View {
        let tag = Text(secondaryTitle)
            .font(Theme.serif(.caption2, weight: .semibold))
            .foregroundStyle(Theme.accent)
        return Text("\(tag)  \(text ?? "—")")
            .font(Theme.serif(.callout))
            .foregroundStyle(Theme.inkSoft)
            .padding(.leading, 10)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 2)
            }
    }

    private func noteBlock(_ note: String) -> some View {
        Text(note)
            .font(Theme.serif(.footnote))
            .italic()
            .foregroundStyle(Theme.inkSoft)
            .padding(.leading, 10)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 2)
            }
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
