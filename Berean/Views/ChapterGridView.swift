import SwiftUI

struct ChapterGridView: View {
    let book: Book

    private let columns = [GridItem(.adaptive(minimum: 56), spacing: 10)]
    private let cell = RoundedRectangle(cornerRadius: 6)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(book.chapters, id: \.chapter) { chapter in
                    NavigationLink(value: Position(bookID: book.id, chapter: chapter.chapter)) {
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
        .background(Theme.paper)
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
