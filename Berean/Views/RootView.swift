//
//  RootView.swift
//  Berean
//
//  Created by Sergio Bonatto on 12/11/26.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        ContentView()
            .tint(Theme.accent)
            .preferredColorScheme(ThemeStore.shared.current.colorScheme)
    }
}
