//
//  ReadingPlan.swift
//  Berean
//
//  Created by Sergio Bonatto on 13/11/26.
//

import Foundation
import SwiftData

nonisolated struct ReadingPlan: Decodable, Identifiable, Sendable {
    let id: String
    let order: Int?
    let title: String
    let subtitle: String?
    let days: [[String]]
}

extension ReadingPlan {
    nonisolated func summary(ofDay day: Int, in bible: Bible) -> String {
        guard days.indices.contains(day - 1) else { return "" }
        let parsed = days[day - 1].compactMap { entry -> (key: String, chapter: Int)? in
            let pieces = entry.split(separator: " ")
            guard pieces.count == 2, let chapter = Int(pieces[1]) else { return nil }
            return (String(pieces[0]), chapter)
        }
        var parts: [String] = []
        var index = 0
        while index < parsed.count {
            let first = parsed[index]
            var last = first
            var next = index + 1
            while next < parsed.count,
                  parsed[next].key == first.key,
                  parsed[next].chapter == last.chapter + 1 {
                last = parsed[next]
                next += 1
            }
            let name = bible.book(key: first.key)?.name ?? first.key
            parts.append(
                first.chapter == last.chapter
                    ? "\(name) \(first.chapter)"
                    : "\(name) \(first.chapter)–\(last.chapter)"
            )
            index = next
        }
        return parts.joined(separator: ", ")
    }
}

@Model
final class PlanEnrollment {
    @Attribute(.unique) var planID: String
    var startedAt: Date
    var completedDays: [Int]

    init(planID: String, startedAt: Date = .now) {
        self.planID = planID
        self.startedAt = startedAt
        self.completedDays = []
    }

    func nextDay(total: Int) -> Int? {
        let done = Set(completedDays)
        return (1...max(total, 1)).first { !done.contains($0) && $0 <= total }
    }

    func scheduledDay(total: Int) -> Int {
        let calendar = Calendar.current
        let elapsed = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: startedAt),
            to: calendar.startOfDay(for: .now)
        ).day ?? 0
        return min(max(elapsed + 1, 1), total)
    }
}
