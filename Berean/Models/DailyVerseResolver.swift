//
//  DailyVerseResolver.swift
//  Berean
//
//  Created by Sergio Bonatto on 14/11/26.
//

import Foundation

struct ResolvedVerse {
    let reference: Reference
    let title: String
    let text: String
}

@MainActor
enum DailyVerseResolver {
    static func resolve(on day: Date, store: BibleStore, bible: Bible) -> ResolvedVerse? {
        let index = Calendar.current.ordinality(of: .day, in: .era, for: day) ?? 0
        let code = DailyVerses.references[index % DailyVerses.references.count]
        guard let reference = store.references(matching: code).first,
              let chapterNumber = reference.chapter,
              let first = reference.verse,
              let chapter = bible.book(key: reference.bookKey)?.chapter(chapterNumber)
        else { return nil }
        let last = max(first, reference.endVerse ?? first)
        let text = chapter.verses
            .filter { (first...last).contains($0.verse) }
            .map(\.text)
            .joined(separator: " ")
        guard !text.isEmpty else { return nil }
        return ResolvedVerse(reference: reference, title: reference.title(in: bible), text: text)
    }
}
