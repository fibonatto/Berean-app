//
//  ParallelStore.swift
//  Berean
//
//  Created by Sergio Bonatto on 14/11/26.
//

import Foundation
import Observation

nonisolated enum ParallelChoice {
    static func resolve(stored: String, primary: Translation) -> Translation {
        if let saved = Translation(rawValue: stored), saved != primary { return saved }
        let preferred: Translation = primary.language == "en" ? .acf : .kjv
        if preferred != primary { return preferred }
        return Translation.allCases.first { $0 != primary } ?? primary
    }
}

@MainActor
@Observable
final class ParallelStore {
    private(set) var translation: Translation?
    private(set) var bible: Bible?
    private(set) var isLoading = false

    func ensure(_ translation: Translation?) async {
        guard let translation else {
            release()
            return
        }
        if self.translation == translation, bible != nil { return }
        self.translation = translation
        bible = nil
        isLoading = true
        let loaded = try? await Task.detached(priority: .userInitiated) {
            try BibleLoader.load(translation)
        }.value
        guard self.translation == translation else { return }
        bible = loaded
        isLoading = false
    }

    func release() {
        translation = nil
        bible = nil
        isLoading = false
    }
}
