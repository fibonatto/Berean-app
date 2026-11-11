//
//  MarksView.swift
//  Berean
//
//  Created by Sergio Bonatto on 10/11/26.
//

import SwiftData
import SwiftUI

struct MarksView: View {
    private enum Filter: String, CaseIterable, Identifiable {
        case favorites = "Favoritos"
        case highlights = "Destaques"

        var id: String { rawValue }
    }

    private struct Row: Identifiable {
        let mark: VerseMark
        let title: String
        let text: String

        var id: String { mark.id }
    }

    @Environment(BibleStore.self) private var store
    @Environment(\.modelContext) private var context
    @Query(sort: \VerseMark.createdAt, order: .reverse) private var marks: [VerseMark]
    @State private var filter: Filter = .favorites

    let onSelect: (VerseMark) -> Void

    private var rows: [Row] {
        guard let bible = store.bible else { return [] }
        return marks.compactMap { mark in
            guard filter == .favorites ? mark.isFavorite : mark.highlight != nil,
                  let book = bible.book(key: mark.bookKey),
                  let verse = book.chapter(mark.chapter)?.verses.first(where: { $0.verse == mark.verse })
            else { return nil }
            return Row(
                mark: mark,
                title: "\(book.name) \(mark.chapter):\(mark.verse)",
                text: verse.text
            )
        }
    }

    var body: some View {
        List {
            ForEach(rows) { row in
                Button { onSelect(row.mark) } label: { label(for: row) }
                    .buttonStyle(.plain)
                    .listRowBackground(row.mark.markColor?.color ?? Theme.paper)
                    .listRowSeparatorTint(Theme.border)
                    .swipeActions {
                        Button(role: .destructive) { remove(row.mark) } label: {
                            Label("Remover", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .safeAreaInset(edge: .top) {
            Picker("Filtro", selection: $filter) {
                ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Theme.paper)
        }
        .overlay {
            if rows.isEmpty {
                ContentUnavailableView(
                    filter == .favorites ? "Sem favoritos" : "Sem destaques",
                    systemImage: filter == .favorites ? "star" : "highlighter",
                    description: Text("Toque num versículo no leitor para marcá-lo.")
                )
            }
        }
        .navigationTitle("Marcações")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func label(for row: Row) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(row.title)
                    .font(Theme.serif(.subheadline, weight: .semibold))
                    .foregroundStyle(Theme.verseNumberOnMark)
                if row.mark.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.star)
                }
            }
            Text(row.text)
                .font(Theme.serif(.body))
                .foregroundStyle(Theme.ink)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func remove(_ mark: VerseMark) {
        switch filter {
        case .favorites: mark.isFavorite = false
        case .highlights: mark.highlight = nil
        }
        if mark.highlight == nil, !mark.isFavorite {
            context.delete(mark)
        }
        try? context.save()
    }
}
