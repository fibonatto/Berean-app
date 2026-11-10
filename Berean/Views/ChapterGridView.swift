import SwiftUI

struct ChapterGridView: View {
    let book: Book

    private let columns = [GridItem(.adaptive(minimum: 56), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(book.chapters, id: \.chapter) { chapter in
                    NavigationLink(value: Position(bookID: book.id, chapter: chapter.chapter)) {
                        Text("\(chapter.chapter)")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
