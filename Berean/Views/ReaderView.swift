import SwiftUI

struct ReaderView: View {
    @Environment(BibleStore.self) private var store
    @Environment(\.dynamicTypeSize) private var systemTypeSize
    @AppStorage("readerSizeStep") private var sizeStep = 0
    @State private var position: Position
    @State private var highlight: ClosedRange<Int>?

    private let sizeStepRange = -3...6

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

    private var textSize: DynamicTypeSize {
        let sizes = DynamicTypeSize.allCases
        let base = sizes.firstIndex(of: systemTypeSize) ?? 0
        return sizes[min(max(base + sizeStep, 0), sizes.count - 1)]
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if let book, let chapter {
                    VStack(spacing: 0) {
                        chapterHeader(book: book)
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(chapter.verses, id: \.verse) { verse in
                                verseRow(verse)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 32)
                }
            }
            .id(position)
            .task(id: position) { await reveal(with: proxy) }
        }
        .background(Theme.paper)
        .font(Theme.serif(.body))
        .foregroundStyle(Theme.ink)
        .lineSpacing(6)
        .dynamicTypeSize(textSize)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    sizeStep = max(sizeStep - 1, sizeStepRange.lowerBound)
                } label: {
                    Label("Diminuir texto", systemImage: "textformat.size.smaller")
                }
                Button {
                    sizeStep = min(sizeStep + 1, sizeStepRange.upperBound)
                } label: {
                    Label("Aumentar texto", systemImage: "textformat.size.larger")
                }
            }
            ToolbarItemGroup(placement: .bottomBar) {
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
        }
        .simultaneousGesture(swipe)
        .onAppear { store.remember(position) }
        .onChange(of: position) { _, newValue in store.remember(newValue) }
        .onChange(of: store.lastPosition) { _, newValue in
            if let newValue, newValue != position { go(to: newValue) }
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
        position = target
    }

    private func reveal(with proxy: ScrollViewProxy) async {
        guard let first = highlight?.lowerBound else { return }
        try? await Task.sleep(for: .milliseconds(150))
        proxy.scrollTo(first, anchor: UnitPoint(x: 0.5, y: 0.25))
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

    private func verseRow(_ verse: Verse) -> some View {
        let isHighlighted = highlight?.contains(verse.verse) ?? false
        return verseText(verse)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                isHighlighted ? Theme.highlight : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .id(verse.verse)
    }

    private func verseText(_ verse: Verse) -> Text {
        let number = Text("\(verse.verse)")
            .font(Theme.serif(.caption2, weight: .semibold))
            .foregroundStyle(Theme.verseNumber)
            .baselineOffset(6)
        return Text("\(number) \(verse.text)")
    }
}
