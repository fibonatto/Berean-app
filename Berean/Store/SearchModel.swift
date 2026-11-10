//
//  SearchModel.swift
//  Berean
//
//  Created by Sergio Bonatto on 10/11/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class SearchModel {
    enum Scope: Hashable {
        case current, all
    }

    private(set) var results = SearchResults()
    private(set) var isWorking = false

    @ObservationIgnored private var indices: [Translation: SearchIndex] = [:]
    @ObservationIgnored private var builders: [Translation: Task<SearchIndex?, Never>] = [:]
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var generation = 0

    func warmUp(store: BibleStore) async {
        _ = await index(for: store.translation, preloaded: store.bible)
    }

    func update(query: String, scope: Scope, store: BibleStore) {
        task?.cancel()
        generation += 1
        let id = generation

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = SearchResults()
            isWorking = false
            return
        }

        let current = store.translation
        let loaded = store.bible
        let translations = scope == .current ? [current] : Translation.allCases
        let limit = scope == .current ? 100 : 40
        isWorking = true

        task = Task {
            try? await Task.sleep(for: .milliseconds(250))
            var combined = SearchResults()
            for translation in translations {
                guard !Task.isCancelled, id == self.generation else { return }
                let preloaded = translation == current ? loaded : nil
                guard let index = await self.index(for: translation, preloaded: preloaded) else {
                    continue
                }
                let found = await Task.detached(priority: .userInitiated) {
                    index.search(query, limit: limit)
                }.value
                guard id == self.generation else { return }
                combined.hits += found.hits
                combined.matchedWords.formUnion(found.matchedWords)
                self.results = combined
            }
            if id == self.generation { self.isWorking = false }
        }
    }

    private func index(for translation: Translation, preloaded: Bible?) async -> SearchIndex? {
        if let cached = indices[translation] { return cached }
        let builder = builders[translation] ?? Task.detached(priority: .userInitiated) { () -> SearchIndex? in
            guard let bible = preloaded ?? (try? BibleLoader.load(translation)) else { return nil }
            return SearchIndex(bible: bible, translation: translation)
        }
        builders[translation] = builder
        let built = await builder.value
        builders[translation] = nil
        if let built { indices[translation] = built }
        return built
    }
}
