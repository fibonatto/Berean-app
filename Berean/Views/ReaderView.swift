import SwiftUI

struct ReaderView: View {
        let book: Book
        let chapter: Chapter

        var body: some View {
                ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(chapter.verses, id: \.verse) { verse in
                                        Text("\(verse.verse)  \(verse.text)")
                                }
                        }
                        .padding()
                }
                .navigationTitle("\(book.name) \(chapter.chapter)")
                .navigationBarTitleDisplayMode(.inline)
        }
}
