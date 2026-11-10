//
//  SearchIndex.swift
//  Berean
//
//  Created by Sergio Bonatto on 10/11/26.
//

import Foundation

nonisolated enum SearchText {
    static func tokens(_ text: String) -> [String] {
        text.normalized
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
    }
}

nonisolated struct SearchHit: Identifiable, Hashable, Sendable {
    let translation: Translation
    let bookKey: String
    let bookName: String
    let chapter: Int
    let verse: Int
    let text: String
    let score: Int

    var id: String { "\(translation.rawValue)-\(bookKey)-\(chapter)-\(verse)" }
}

nonisolated struct SearchResults: Sendable {
    var hits: [SearchHit] = []
    var matchedWords: Set<String> = []
}

nonisolated struct SearchIndex: Sendable {
    private nonisolated struct Entry: Sendable {
        let book: Int
        let chapter: Int
        let verse: Int
        let text: String
    }

    private static let candidateCap = 3000

    private let translation: Translation
    private let books: [(key: String, name: String)]
    private let entries: [Entry]
    private let postings: [String: [Int]]
    private let vocabulary: [String]

    init(bible: Bible, translation: Translation) {
        var books: [(key: String, name: String)] = []
        var entries: [Entry] = []
        var postings: [String: [Int]] = [:]

        for (bookIndex, book) in bible.books.enumerated() {
            books.append((key: book.key, name: book.name))
            for chapter in book.chapters {
                for verse in chapter.verses {
                    let id = entries.count
                    entries.append(Entry(
                        book: bookIndex,
                        chapter: chapter.chapter,
                        verse: verse.verse,
                        text: verse.text
                    ))
                    for token in Set(SearchText.tokens(verse.text)) {
                        postings[token, default: []].append(id)
                    }
                }
            }
        }

        self.translation = translation
        self.books = books
        self.entries = entries
        self.postings = postings
        self.vocabulary = Array(postings.keys)
    }

    func search(_ query: String, limit: Int) -> SearchResults {
        var seen = Set<String>()
        let terms = SearchText.tokens(query).filter { seen.insert($0).inserted }
        guard !terms.isEmpty else { return SearchResults() }

        var matchedWords = Set<String>()
        var perTerm: [[Int: Int]] = []
        for term in terms {
            var weights: [Int: Int] = [:]
            for (word, weight) in matchingWords(for: term) {
                matchedWords.insert(word)
                for id in postings[word] ?? [] where weights[id, default: 0] < weight {
                    weights[id] = weight
                }
            }
            if weights.isEmpty { return SearchResults() }
            perTerm.append(weights)
        }

        perTerm.sort { $0.count < $1.count }
        var scores = perTerm[0]
        for weights in perTerm.dropFirst() {
            var combined: [Int: Int] = [:]
            for (id, score) in scores {
                if let weight = weights[id] { combined[id] = score + weight }
            }
            scores = combined
            if scores.isEmpty { return SearchResults() }
        }

        let phrase = terms.joined(separator: " ")
        let candidates = scores
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(Self.candidateCap)
        let ranked = candidates
            .map { element -> (id: Int, score: Int) in
                guard terms.count > 1 else { return (element.key, element.value) }
                let text = SearchText.tokens(entries[element.key].text).joined(separator: " ")
                let bonus = text.contains(phrase) ? terms.count * 3 : 0
                return (element.key, element.value + bonus)
            }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.id < $1.id }
            .prefix(limit)

        let hits = ranked.map { item -> SearchHit in
            let entry = entries[item.id]
            let book = books[entry.book]
            return SearchHit(
                translation: translation,
                bookKey: book.key,
                bookName: book.name,
                chapter: entry.chapter,
                verse: entry.verse,
                text: entry.text,
                score: item.score
            )
        }
        return SearchResults(hits: Array(hits), matchedWords: matchedWords)
    }

    private func matchingWords(for term: String) -> [(word: String, weight: Int)] {
        let chars = Array(term)
        let tolerance = Self.tolerance(forLength: chars.count)
        var matches: [(word: String, weight: Int)] = []
        for word in vocabulary {
            if word == term {
                matches.append((word: word, weight: 3))
            } else if chars.count >= 3, word.hasPrefix(term) {
                matches.append((word: word, weight: 2))
            } else if tolerance > 0 {
                let candidate = Array(word)
                guard abs(candidate.count - chars.count) <= tolerance,
                      Self.distance(candidate, chars) <= tolerance
                else { continue }
                matches.append((word: word, weight: 1))
            }
        }
        return matches
    }

    private static func tolerance(forLength length: Int) -> Int {
        switch length {
        case ..<4: 0
        case 4...6: 1
        default: 2
        }
    }

    private static func distance(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var twoAgo = [Int](repeating: 0, count: b.count + 1)
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                var value = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    value = min(value, twoAgo[j - 2] + 1)
                }
                current[j] = value
            }
            (twoAgo, previous, current) = (previous, current, twoAgo)
        }
        return previous[b.count]
    }
}
