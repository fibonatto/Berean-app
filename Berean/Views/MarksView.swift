//
//  MarksView.swift
//  Berean
//
//  Created by Sergio Bonatto on 10/11/26.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MarksView: View {
    private enum Filter: String, CaseIterable, Identifiable {
        case favorites = "Favorites"
        case highlights = "Highlights"
        case notes = "Notes"

        var id: String { rawValue }

        var emptyTitle: String {
            switch self {
            case .favorites: "No favorites"
            case .highlights: "No highlights"
            case .notes: "No notes"
            }
        }

        var symbol: String {
            switch self {
            case .favorites: "star"
            case .highlights: "highlighter"
            case .notes: "note.text"
            }
        }
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
    @Query private var enrollments: [PlanEnrollment]
    @State private var filter: Filter = .favorites
    @State private var exportDocument: ExportDocument?
    @State private var exportFormat = ExportFormat.json
    @State private var showsExporter = false
    @State private var showsImporter = false
    @State private var message: String?

    let onSelect: (VerseMark) -> Void

    private var rows: [Row] {
        guard let bible = store.bible else { return [] }
        return marks.compactMap { mark in
            guard matches(mark),
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
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.paper)
        .safeAreaInset(edge: .top) {
            Picker("Filter", selection: $filter) {
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
                    filter.emptyTitle,
                    systemImage: filter.symbol,
                    description: Text("Tap a verse in the reader to mark it.")
                )
            }
        }
        .navigationTitle("Marks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Section("Export") {
                        Button("Org") { export(.org) }
                        Button("Markdown") { export(.markdown) }
                    }
                    Section("Backup") {
                        Button("Back up (JSON)") { export(.json) }
                        Button("Restore from backup…") { showsImporter = true }
                    }
                } label: {
                    Label("Backup and export", systemImage: "ellipsis.circle")
                }
            }
        }
        .fileExporter(
            isPresented: $showsExporter,
            document: exportDocument,
            contentType: exportFormat.contentType,
            defaultFilename: exportFormat.fileName
        ) { result in
            if case let .failure(error) = result {
                message = "Export failed: \(error.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.json]) { result in
            handleImport(result)
        }
        .alert(
            "Backup",
            isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )
        ) {
            Button("OK") {}
        } message: {
            Text(message ?? "")
        }
    }

    private func matches(_ mark: VerseMark) -> Bool {
        switch filter {
        case .favorites: mark.isFavorite
        case .highlights: mark.highlight != nil
        case .notes: !(mark.note ?? "").isEmpty
        }
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
            if let note = row.mark.note, !note.isEmpty {
                Text(note)
                    .font(Theme.serif(.footnote))
                    .italic()
                    .foregroundStyle(Theme.inkSoft)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func remove(_ mark: VerseMark) {
        switch filter {
        case .favorites: mark.isFavorite = false
        case .highlights: mark.highlight = nil
        case .notes: mark.note = nil
        }
        if mark.isEmpty {
            context.delete(mark)
        }
        try? context.save()
    }

    private func export(_ format: ExportFormat) {
        let data: Data?
        switch format {
        case .json:
            data = try? BackupService.json(marks: marks, enrollments: enrollments)
        case .org:
            data = BackupService.org(marks: marks, bible: store.bible, translation: store.translation)
        case .markdown:
            data = BackupService.markdown(marks: marks, bible: store.bible, translation: store.translation)
        }
        guard let data else {
            message = "Could not prepare the export."
            return
        }
        exportFormat = format
        exportDocument = ExportDocument(data: data)
        showsExporter = true
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case let .success(url):
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let summary = try BackupService.restore(
                    data,
                    context: context,
                    marks: marks,
                    enrollments: enrollments
                )
                message = summary.text
            } catch {
                message = "Could not restore: \(error.localizedDescription)"
            }
        case let .failure(error):
            message = "Could not open the file: \(error.localizedDescription)"
        }
    }
}
