//
//  PlanStore.swift
//  Berean
//
//  Created by Sergio Bonatto on 13/11/26.
//

import Foundation
import Observation

nonisolated enum PlanLoader {
    static func loadAll() -> [ReadingPlan] {
        guard let enumerator = FileManager.default.enumerator(
            at: Bundle.main.bundleURL,
            includingPropertiesForKeys: nil
        ) else { return [] }

        var plans: [ReadingPlan] = []
        for case let url as URL in enumerator
        where url.pathExtension == "json" && url.lastPathComponent.hasPrefix("plan-") {
            do {
                let data = try Data(contentsOf: url)
                plans.append(try JSONDecoder().decode(ReadingPlan.self, from: data))
            } catch {
                assertionFailure("Invalid plan file \(url.lastPathComponent): \(error)")
            }
        }
        return plans.sorted { ($0.order ?? 1000, $0.title) < ($1.order ?? 1000, $1.title) }
    }
}

@MainActor
@Observable
final class PlanStore {
    private(set) var plans: [ReadingPlan] = []
    private(set) var isLoaded = false

    func load() async {
        guard !isLoaded else { return }
        plans = await Task.detached(priority: .userInitiated) {
            PlanLoader.loadAll()
        }.value
        isLoaded = true
    }

    func plan(id: String) -> ReadingPlan? {
        plans.first { $0.id == id }
    }
}
