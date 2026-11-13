//
//  Backup.swift
//  Berean
//
//  Created by Sergio Bonatto on 13/11/26.
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

nonisolated struct BackupFile: Codable, Sendable {
    struct Mark: Codable, Sendable {
        let bookKey: String
        let chapter: Int
        let verse: Int
        let highlight: String?
        let isFavorite: Bool
        let note: String?
        let createdAt: Date
    }

    struct Plan: Codable, Sendable {
        let planID: String
        let startedAt: Date
        let completedDays: [Int]
    }

    var version: Int
    var exportedAt: Date
    var marks: [Mark]
    var plans: [Plan]

    init(version: Int = 1, exportedAt: Date, marks: [Mark], plans: [Plan]) {
        self.version = version
        self.exportedAt = exportedAt
        self.marks = marks
        self.plans = plans
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? .now
        marks = try container.decodeIfPresent([Mark].self, forKey: .marks) ?? []
        plans = try container.decodeIfPresent([Plan].self, forKey: .plans) ?? []
    }
}

enum ExportFormat {
    case org, markdown, json

    var fileExtension: String {
        switch self {
        case .org: "org"
        case .markdown: "md"
        case .json: "json"
        }
    }

    var contentType: UTType {
        switch self {
        case .org: UTType(filenameExtension: "org", conformingTo: .plainText) ?? .plainText
        case .markdown: UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
        case .json: .json
        }
    }

    var fileName: String {
        "berean-marks-\(BackupService.dayString(.now))"
    }
}

nonisolated struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    static var writableContentTypes: [UTType] {
        [
            .json,
            .plainText,
            UTType(filenameExtension: "org", conformingTo: .plainText) ?? .plainText,
            UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText,
        ]
    }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct RestoreSummary {
    var marksCreated = 0
    var marksMerged = 0
    var plansCreated = 0
    var plansMerged = 0

    var text: String {
        "Added \(marksCreated) marks and merged \(marksMerged). "
            + "Plans: \(plansCreated) added, \(plansMerged) merged."
    }
}

@MainActor
enum BackupService {
    static func json(marks: [VerseMark], enrollments: [PlanEnrollment]) throws -> Data {
        let file = BackupFile(
            exportedAt: .now,
            marks: sorted(marks).map {
                BackupFile.Mark(
                    bookKey: $0.bookKey,
                    chapter: $0.chapter,
                    verse: $0.verse,
                    highlight: $0.highlight,
                    isFavorite: $0.isFavorite,
                    note: $0.note,
                    createdAt: $0.createdAt
                )
            },
            plans: enrollments.map {
                BackupFile.Plan(
                    planID: $0.planID,
                    startedAt: $0.startedAt,
                    completedDays: $0.completedDays
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    static func org(marks: [VerseMark], bible: Bible?, translation: Translation) -> Data {
        var lines = ["#+TITLE: Berean marks", "#+DATE: \(dayString(.now))", ""]
        var currentBook: String?
        for mark in sorted(marks) {
            let bookName = bible?.book(key: mark.bookKey)?.name ?? mark.bookKey
            if currentBook != mark.bookKey {
                lines.append("* \(bookName)")
                currentBook = mark.bookKey
            }
            var tags: [String] = []
            if mark.isFavorite { tags.append("favorite") }
            if let color = mark.highlight { tags.append("hl_\(color)") }
            let tagText = tags.isEmpty ? "" : " :\(tags.joined(separator: ":")):"
            lines.append("** \(bookName) \(mark.chapter):\(mark.verse)\(tagText)")
            lines.append(":PROPERTIES:")
            lines.append(":REF: \(mark.bookKey) \(mark.chapter):\(mark.verse)")
            lines.append(":TRANSLATION: \(translation.title)")
            lines.append(":END:")
            if let text = verseText(of: mark, in: bible) {
                lines.append("#+begin_quote")
                lines.append(escapeOrg(text))
                lines.append("#+end_quote")
            }
            if let note = mark.note, !note.isEmpty {
                lines.append(escapeOrg(note))
            }
            lines.append("")
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    static func markdown(marks: [VerseMark], bible: Bible?, translation: Translation) -> Data {
        var lines = ["# Berean marks", "", "_\(translation.title) · \(dayString(.now))_", ""]
        var currentBook: String?
        for mark in sorted(marks) {
            let bookName = bible?.book(key: mark.bookKey)?.name ?? mark.bookKey
            if currentBook != mark.bookKey {
                lines.append("## \(bookName)")
                lines.append("")
                currentBook = mark.bookKey
            }
            var badges: [String] = []
            if mark.isFavorite { badges.append("★ favorite") }
            if let color = mark.highlight { badges.append("\(color) highlight") }
            let badgeText = badges.isEmpty ? "" : " — " + badges.joined(separator: " · ")
            lines.append("### \(bookName) \(mark.chapter):\(mark.verse)\(badgeText)")
            lines.append("")
            if let text = verseText(of: mark, in: bible) {
                lines.append(contentsOf: text.split(separator: "\n", omittingEmptySubsequences: false).map { "> \($0)" })
                lines.append("")
            }
            if let note = mark.note, !note.isEmpty {
                lines.append(note)
                lines.append("")
            }
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    static func restore(
        _ data: Data,
        context: ModelContext,
        marks: [VerseMark],
        enrollments: [PlanEnrollment]
    ) throws -> RestoreSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(BackupFile.self, from: data)
        var summary = RestoreSummary()

        var markByID = Dictionary(marks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for item in file.marks {
            let id = VerseMark.id(bookKey: item.bookKey, chapter: item.chapter, verse: item.verse)
            if let existing = markByID[id] {
                existing.highlight = existing.highlight ?? item.highlight
                existing.isFavorite = existing.isFavorite || item.isFavorite
                if (existing.note ?? "").isEmpty { existing.note = item.note }
                summary.marksMerged += 1
            } else {
                let mark = VerseMark(bookKey: item.bookKey, chapter: item.chapter, verse: item.verse)
                mark.highlight = item.highlight
                mark.isFavorite = item.isFavorite
                mark.note = item.note
                mark.createdAt = item.createdAt
                context.insert(mark)
                markByID[id] = mark
                summary.marksCreated += 1
            }
        }

        var planByID = Dictionary(enrollments.map { ($0.planID, $0) }, uniquingKeysWith: { first, _ in first })
        for item in file.plans {
            if let existing = planByID[item.planID] {
                existing.completedDays = Set(existing.completedDays).union(item.completedDays).sorted()
                existing.startedAt = min(existing.startedAt, item.startedAt)
                summary.plansMerged += 1
            } else {
                let enrollment = PlanEnrollment(planID: item.planID, startedAt: item.startedAt)
                enrollment.completedDays = item.completedDays.sorted()
                context.insert(enrollment)
                planByID[item.planID] = enrollment
                summary.plansCreated += 1
            }
        }

        try context.save()
        return summary
    }

    static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func sorted(_ marks: [VerseMark]) -> [VerseMark] {
        marks.sorted { lhs, rhs in
            (Canon.rank(of: lhs.bookKey) ?? 1000, lhs.chapter, lhs.verse)
                < (Canon.rank(of: rhs.bookKey) ?? 1000, rhs.chapter, rhs.verse)
        }
    }

    private static func verseText(of mark: VerseMark, in bible: Bible?) -> String? {
        bible?.book(key: mark.bookKey)?
            .chapter(mark.chapter)?
            .verses.first { $0.verse == mark.verse }?
            .text
    }

    private static func escapeOrg(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                line.hasPrefix("*") || line.hasPrefix("#+") ? ",\(line)" : String(line)
            }
            .joined(separator: "\n")
    }
}
