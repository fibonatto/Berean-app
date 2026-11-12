import Foundation

nonisolated struct LibraryCategory: Decodable, Identifiable, Sendable {
    let id: String
    let title: String
    let singularTitle: String
    let order: Int

    enum CodingKeys: String, CodingKey {
        case id, title, order
        case singularTitle = "singular"
    }
}

nonisolated struct LibraryDocument: Decodable, Identifiable, Sendable {
    let slug: String
    let kind: String
    let language: String
    let order: Int?
    let title: String
    let subtitle: String?
    let tradition: String?
    let source: String?
    let license: String?
    let sections: [DocumentSection]

    var id: String { "\(slug).\(language)" }

    enum CodingKeys: String, CodingKey {
        case slug = "id"
        case kind, language, order, title, subtitle, tradition, source, license, sections
    }

    func matches(language code: String?) -> Bool {
        code == nil || language == "any" || language == code
    }
}

nonisolated struct DocumentSection: Decodable, Sendable {
    let title: String?
    let blocks: [DocumentBlock]
}

nonisolated enum DocumentBlock: Decodable, Sendable {
    case paragraph(number: String?, text: String, proofs: [String])
    case verse(lines: [String])
    case qa(number: Int, question: String, answer: String, proofs: [String])
    case scripture(reference: String, caption: String?)

    private enum CodingKeys: String, CodingKey {
        case type, number, text, lines, question, answer, proofs, reference, caption
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let proofs = try container.decodeIfPresent([String].self, forKey: .proofs) ?? []
        switch try container.decode(String.self, forKey: .type) {
        case "paragraph":
            self = .paragraph(
                number: try container.decodeIfPresent(String.self, forKey: .number),
                text: try container.decode(String.self, forKey: .text),
                proofs: proofs
            )
        case "verse":
            self = .verse(lines: try container.decode([String].self, forKey: .lines))
        case "qa":
            self = .qa(
                number: try container.decode(Int.self, forKey: .number),
                question: try container.decode(String.self, forKey: .question),
                answer: try container.decode(String.self, forKey: .answer),
                proofs: proofs
            )
        case "scripture":
            self = .scripture(
                reference: try container.decode(String.self, forKey: .reference),
                caption: try container.decodeIfPresent(String.self, forKey: .caption)
            )
        case let other:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown block type \(other)"
            )
        }
    }

    nonisolated var searchableText: String {
        switch self {
        case let .paragraph(number, text, _):
            [number, text].compactMap { $0 }.joined(separator: " ")
        case let .verse(lines):
            lines.joined(separator: " ")
        case let .qa(number, question, answer, _):
            "\(number) \(question) \(answer)"
        case let .scripture(reference, caption):
            [caption, reference].compactMap { $0 }.joined(separator: " ")
        }
    }
}

extension LibraryDocument {
    nonisolated var plainText: String {
        var lines = [title]
        if let subtitle { lines.append(subtitle) }
        for section in sections {
            lines.append("")
            if let heading = section.title { lines.append(heading) }
            for block in section.blocks {
                switch block {
                case let .paragraph(number, text, _):
                    lines.append(number.map { "\($0) \(text)" } ?? text)
                case let .verse(verseLines):
                    lines.append(contentsOf: verseLines)
                case let .qa(number, question, answer, _):
                    lines.append("\(number). \(question)")
                    lines.append(answer)
                case let .scripture(reference, caption):
                    lines.append(caption ?? reference)
                }
                lines.append("")
            }
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated var previewText: String {
        for section in sections {
            for block in section.blocks {
                switch block {
                case let .paragraph(_, text, _): return text
                case let .verse(lines): return lines.joined(separator: " ")
                case let .qa(_, question, answer, _): return "\(question) \(answer)"
                case let .scripture(reference, caption): return caption ?? reference
                }
            }
        }
        return title
    }
}
