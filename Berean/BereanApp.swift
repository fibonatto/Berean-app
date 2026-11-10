//
//  BereanApp.swift
//  Berean
//
//  Created by Sergio Bonatto on 09/11/26.
//

import SwiftUI

@main
struct BereanApp: App {
    @State private var store = BibleStore()
    @State private var search = SearchModel()

    init() {
        Theme.configureNavigationBar()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(search)
                .tint(Theme.accent)
                .preferredColorScheme(.light)
        }
    }
}
