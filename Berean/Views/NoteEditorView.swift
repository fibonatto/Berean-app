//
//  NoteEditorView.swift
//  Berean
//
//  Created by Sergio Bonatto on 13/11/26.
//

import SwiftUI

struct NoteTarget: Identifiable {
    let verse: Int

    var id: Int { verse }
}

struct NoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var text: String

    let title: String
    let hasExistingNote: Bool
    let onSave: (String) -> Void

    init(title: String, initialText: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.hasExistingNote = !initialText.isEmpty
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextEditor(text: $text)
                    .font(Theme.serif(.body))
                    .foregroundStyle(Theme.ink)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                if hasExistingNote {
                    Button("Delete note", role: .destructive) {
                        onSave("")
                        dismiss()
                    }
                    .font(Theme.serif(.subheadline))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .background(Theme.paper)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                }
            }
            .onAppear { isFocused = true }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.paper)
    }
}
