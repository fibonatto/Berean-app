//
//  SearchView.swift
//  Berean
//
//  Created by Sergio Bonatto on 10/11/26.
//

import SwiftUI

struct SearchView: View {
    @Environment(BibleStore.self) private var store
    @Environment(SearchModel.self) private var search
    @State private var query = ""
    @State private var scope: SearchModel.Scope = .current

    let onSelect: (SearchHit) -> Void

    private struct ResultSection: Identifiable {
        let translation: Translation
        let hits: [SearchHit]
        var id: Translation { translation }
    }

    private var sections: [ResultSection] {
        Translation.allCases.compactMap { translation in
            let hits = search.results.hits.filter { $0.translation == translation }
            return hits.isEmpty ? nil : ResultSection(translation: translation, hits: hits)
        }
    }

    private var isBlank: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.hits) { hit in row(hit) }
                } header: {
                    if scope == .all {
                        Text("\(section.translation.title) · \(section.translation.name)".uppercased())
                            .font(Theme.serif(.caption, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .overlay { placeholder }
        .navigationTitle("Buscar")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Palavras do versículo"
        )
        .searchScopes($scope) {
            Text("Esta tradução").tag(SearchModel.Scope.current)
            Text("Todas").tag(SearchModel.Scope.all)
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .onChange(of: query) { refresh() }
        .onChange(of: scope) { refresh() }
        .task { await search.warmUp(store: store) }
    }

    @ViewBuilder
    private var placeholder: some View {
        if isBlank {
            ContentUnavailableView(
                "Buscar no texto",
                systemImage: "magnifyingglass",
                description: Text("Digite palavras do versículo, em qualquer ordem. Pequenos erros de digitação são tolerados.")
            )
        } else if search.results.hits.isEmpty {
            if search.isWorking {
                ProgressView("Buscando…")
            } else {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    private func row(_ hit: SearchHit) -> some View {
        Button { onSelect(hit) } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(hit.bookName) \(hit.chapter):\(hit.verse)")
                    .font(Theme.serif(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.verseNumber)
                Text(highlighted(hit.text))
                    .font(Theme.serif(.body))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.paper)
        .listRowSeparatorTint(Theme.border)
    }

    private func refresh() {
        search.update(query: query, scope: scope, store: store)
    }

    private func highlighted(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        let words = search.results.matchedWords
        guard !words.isEmpty else { return result }
        for range in wordRanges(in: text) where words.contains(String(text[range]).normalized) {
            if let target = Range(range, in: result) {
                result[target].backgroundColor = Theme.highlight
            }
        }
        return result
    }

    private func wordRanges(in text: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var start: String.Index?
        for index in text.indices {
            let character = text[index]
            let isWord = character.isLetter || character.isNumber
            if isWord, start == nil {
                start = index
            } else if !isWord, let begin = start {
                ranges.append(begin..<index)
                start = nil
            }
        }
        if let begin = start { ranges.append(begin..<text.endIndex) }
        return ranges
    }
}
