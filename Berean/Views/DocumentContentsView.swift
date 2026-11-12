//
//  DocumentContentsView.swift
//  Berean
//
//  Created by Sergio Bonatto on 12/11/26.
//

import SwiftUI

struct ContentsEntry: Identifiable {
    let id: String
    let title: String
    let detail: String?
}

struct DocumentContentsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var questionText = ""
    @State private var notFound = false

    let entries: [ContentsEntry]
    let hasQuestions: Bool
    let onSelect: (String) -> Void
    let onGoToQuestion: (Int) -> Bool

    var body: some View {
        NavigationStack {
            List {
                if hasQuestions {
                    Section {
                        HStack {
                            TextField("Question number", text: $questionText)
                                .keyboardType(.numberPad)
                                .font(Theme.serif(.body))
                            Button("Go", action: goToQuestion)
                                .disabled(Int(questionText) == nil)
                        }
                        if notFound {
                            Text("No question with that number.")
                                .font(Theme.serif(.footnote))
                                .foregroundStyle(Theme.star)
                        }
                    }
                    .listRowBackground(Theme.paperAlt)
                }
                Section {
                    ForEach(entries) { entry in
                        Button {
                            onSelect(entry.id)
                            dismiss()
                        } label: {
                            HStack(alignment: .firstTextBaseline) {
                                Text(entry.title)
                                    .font(Theme.serif(.body))
                                    .foregroundStyle(Theme.ink)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                if let detail = entry.detail {
                                    Text(detail)
                                        .font(Theme.serif(.footnote))
                                        .foregroundStyle(Theme.inkSoft)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Theme.paper)
                        .listRowSeparatorTint(Theme.border)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .navigationTitle("Contents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: questionText) { notFound = false }
        }
    }

    private func goToQuestion() {
        guard let number = Int(questionText) else { return }
        if onGoToQuestion(number) {
            dismiss()
        } else {
            notFound = true
        }
    }
}
