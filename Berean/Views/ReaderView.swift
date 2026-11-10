import SwiftUI

struct ReaderView: View {
    @Environment(BibleStore.self) private var store
    @Environment(\.dynamicTypeSize) private var systemTypeSize
    @AppStorage("readerSizeStep") private var sizeStep = 0
    @State private var position: Position

    private let sizeStepRange = -3...6

    init(position: Position) {
        _position = State(initialValue: position)
    }

    private var book: Book? { store.bible?.book(id: position.bookID) }
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
        ScrollView {
            if let book, let chapter {
                VStack(spacing: 0) {
                    chapterHeader(book: book)
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(chapter.verses, id: \.verse) { verse in
                            verseText(verse)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .id(position)
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
                Button { go(to: next) } label: {
                    Label("Próximo capítulo", systemImage: "chevron.right")
                }
                .disabled(next == nil)
            }
        }
        .simultaneousGesture(swipe)
        .onAppear { store.remember(position) }
        .onChange(of: position) { _, newValue in store.remember(newValue) }
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
        position = target
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

    private func verseText(_ verse: Verse) -> Text {
        let number = Text("\(verse.verse)")
            .font(Theme.serif(.caption2, weight: .semibold))
            .foregroundStyle(Theme.verseNumber)
            .baselineOffset(6)
        return Text("\(number) \(verse.text)")
    }
}
