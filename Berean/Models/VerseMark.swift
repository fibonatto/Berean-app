//
//  VerseMark.swift
//  Berean
//
//  Created by Sergio Bonatto on 10/11/26.
//

import Foundation
import SwiftData

nonisolated enum MarkColor: String, CaseIterable, Identifiable, Sendable {
    case yellow, green, rose

    var id: String { rawValue }

    var title: String {
        switch self {
        case .yellow: "Yellow"
        case .green: "Green"
        case .rose: "Rose"
        }
    }
}

@Model
final class VerseMark {
    @Attribute(.unique) var id: String
    var bookKey: String
    var chapter: Int
    var verse: Int
    var highlight: String?
    var isFavorite: Bool
    var note: String?
    var createdAt: Date

    var markColor: MarkColor? {
        highlight.flatMap(MarkColor.init(rawValue:))
    }

    var isEmpty: Bool {
        highlight == nil && !isFavorite && (note ?? "").isEmpty
    }

    init(bookKey: String, chapter: Int, verse: Int) {
        self.id = Self.id(bookKey: bookKey, chapter: chapter, verse: verse)
        self.bookKey = bookKey
        self.chapter = chapter
        self.verse = verse
        self.highlight = nil
        self.isFavorite = false
        self.note = nil
        self.createdAt = .now
    }

    static func id(bookKey: String, chapter: Int, verse: Int) -> String {
        "\(bookKey).\(chapter).\(verse)"
    }
}
