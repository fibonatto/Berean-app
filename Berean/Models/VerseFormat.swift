//
//  VerseFormat.swift
//  Berean
//
//  Created by Sergio Bonatto on 10/11/26.
//

nonisolated enum VerseFormat {
    static func ranges(of numbers: [Int]) -> String {
        guard let first = numbers.first else { return "" }
        var parts: [String] = []
        var start = first
        var end = first
        for number in numbers.dropFirst() {
            if number == end + 1 {
                end = number
            } else {
                parts.append(range(start, end))
                start = number
                end = number
            }
        }
        parts.append(range(start, end))
        return parts.joined(separator: ",")
    }

    static func quotation(bookName: String, chapter: Int, verses: [Verse], translation: String) -> String {
        let quote = verses.map(\.text).joined(separator: " ")
        let reference = "\(bookName) \(chapter):\(ranges(of: verses.map(\.verse)))"
        return "“\(quote)”\n— \(reference) (\(translation))"
    }

    private static func range(_ start: Int, _ end: Int) -> String {
        start == end ? "\(start)" : "\(start)-\(end)"
    }
}
