//
//  TranslationMenu.swift
//  Berean
//
//  Created by Sergio Bonatto on 10/11/26.
//

import SwiftUI

struct TranslationMenu: View {
    @Environment(BibleStore.self) private var store

    var body: some View {
        Menu {
            Picker("Tradução", selection: selection) {
                ForEach(Translation.allCases) { translation in
                    Text("\(translation.title) · \(translation.name)").tag(translation)
                }
            }
        } label: {
            Text(store.translation.title)
                .font(Theme.serif(.subheadline, weight: .semibold))
        }
    }

    private var selection: Binding<Translation> {
        Binding(
            get: { store.translation },
            set: { newValue in Task { await store.select(newValue) } }
        )
    }
}
