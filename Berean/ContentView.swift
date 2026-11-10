//
//  ContentView.swift
//  Berean
//
//  Created by Sergio Bonatto on 09/11/26.
//
import SwiftUI

struct ContentView: View {
        @Environment(BibleStore.self) private var store

        var body: some View {
                NavigationStack {
                        Group {
                                if let bible = store.bible {
                                        BookListView(bible: bible)
                                } else if let error = store.error {
                                        ContentUnavailableView(
                                                "Não foi possível carregar",
                                                systemImage: "exclamationmark.triangle",
                                                description: Text(error)
                                        )
                                } else {
                                        ProgressView()
                                }
                        }
                        .navigationTitle(store.translation.title)
                        .navigationDestination(for: BookRoute.self) { route in
                                if let book = store.bible?.book(id: route.bookID) {
                                        ChapterGridView(book: book)
                                }
                        }
                        .navigationDestination(for: ChapterRoute.self) { route in
                                if let book = store.bible?.book(id: route.bookID),
                                        let chapter = book.chapter(route.chapter)
                                {
                                        ReaderView(book: book, chapter: chapter)
                                }
                        }
                }
                .task { await store.load(store.translation) }
        }
}

#Preview {
        ContentView()
                .environment(BibleStore())
}
