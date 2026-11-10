//
//  ReferenceResolver.swift
//  Berean
//
//  Created by Sergio Bonatto on 10/11/26.
//

import Foundation

nonisolated struct Reference: Hashable, Sendable {
    let bookKey: String
    let chapter: Int?
    let verse: Int?
    let endVerse: Int?

    func title(in bible: Bible) -> String {
        let name = bible.book(key: bookKey)?.name ?? bookKey
        guard let chapter else { return name }
        guard let verse else { return "\(name) \(chapter)" }
        guard let endVerse, endVerse > verse else { return "\(name) \(chapter):\(verse)" }
        return "\(name) \(chapter):\(verse)-\(endVerse)"
    }
}

nonisolated struct ReferenceResolver: Sendable {
    private let exact: [String: String]
    private let folded: [String: String]
    private let prefixes: [(form: String, key: String)]

    init(bible: Bible) {
        var exact: [String: String] = [:]
        var folded: [String: String] = [:]
        var prefixes: [(form: String, key: String)] = []

        func register(_ alias: String, for key: String) {
            let raw = Self.compact(alias)
            guard !raw.isEmpty else { return }
            let form = raw.normalized
            if exact[raw] == nil { exact[raw] = key }
            if folded[form] == nil { folded[form] = key }
            prefixes.append((form: form, key: key))
        }

        for book in bible.books {
            for alias in [book.name, book.abbrev] + book.aliases {
                register(alias, for: book.key)
            }
        }
        for key in Canon.order {
            register(key, for: key)
            for alias in BookAliases.table[key, default: ""].split(separator: " ") {
                register(String(alias), for: key)
            }
        }

        self.exact = exact
        self.folded = folded
        self.prefixes = prefixes
    }

    func matches(for input: String) -> [Reference] {
        guard let parsed = Self.split(input) else { return [] }
        let chapter = parsed.numbers.first
        let verse = parsed.numbers.dropFirst().first
        let endVerse = parsed.numbers.dropFirst(2).first
        return bookKeys(matching: parsed.book).map {
            Reference(bookKey: $0, chapter: chapter, verse: verse, endVerse: endVerse)
        }
    }

    private func bookKeys(matching text: String) -> [String] {
        let raw = Self.compact(text)
        guard !raw.isEmpty else { return [] }
        if let key = exact[raw] { return [key] }
        let forms = Self.variants(of: raw.normalized)
        if let key = forms.lazy.compactMap({ folded[$0] }).first { return [key] }
        var keys: [String] = []
        for entry in prefixes where forms.contains(where: { entry.form.hasPrefix($0) }) {
            if !keys.contains(entry.key) { keys.append(entry.key) }
        }
        return keys
    }

    private static func split(_ input: String) -> (book: String, numbers: [Int])? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let tail = text.reversed().prefix { $0.isNumber || ":.,-–— ".contains($0) }
        let book = String(text.dropLast(tail.count))
        let numbers = String(tail.reversed())
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
        guard numbers.count <= 3, numbers.allSatisfy({ $0 > 0 }) else { return nil }
        return (book, numbers)
    }

    private static func compact(_ text: String) -> String {
        text.precomposedStringWithCanonicalMapping
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private static let numberPrefixes = [
        ("iii", "3"), ("ii", "2"), ("i", "1"),
        ("terceiro", "3"), ("segundo", "2"), ("primeiro", "1"),
    ]

    private static func variants(of form: String) -> [String] {
        var numbered = [form]
        for (prefix, digit) in numberPrefixes where form.count > prefix.count && form.hasPrefix(prefix) {
            numbered.append(digit + String(form.dropFirst(prefix.count)))
        }
        return numbered.flatMap { candidate -> [String] in
            let digit = String(candidate.prefix { $0.isNumber })
            let rest = String(candidate.dropFirst(digit.count))
            guard rest.hasPrefix("sao"), rest.count > 3 else { return [candidate] }
            return [candidate, digit + String(rest.dropFirst(3))]
        }
    }
}
