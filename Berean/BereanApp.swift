//
//  BereanApp.swift
//  Berean
//
//  Created by Sergio Bonatto on 09/11/26.
//

import SwiftData
import SwiftUI

@main
struct BereanApp: App {
    @State private var store = BibleStore()
    @State private var search = SearchModel()
    @State private var library = LibraryStore()
    @State private var plans = PlanStore()
    @State private var parallel = ParallelStore()

    init() {
        Theme.configureNavigationBar()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(search)
                .environment(library)
                .environment(plans)
                .environment(parallel)
        }
        .modelContainer(for: [VerseMark.self, PlanEnrollment.self])
    }
}
