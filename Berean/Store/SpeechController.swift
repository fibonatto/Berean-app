//
//  SpeechController.swift
//  Berean
//
//  Created by Sergio Bonatto on 13/11/26.
//

import AVFoundation
import Observation

nonisolated struct SpokenVerse: Sendable {
    let number: Int
    let text: String
}

nonisolated enum SpeechVoices {
    static func languagePrefix(for translationLanguage: String) -> String {
        translationLanguage == "en" ? "en" : "pt"
    }

    static func defaultLanguage(for translationLanguage: String) -> String {
        translationLanguage == "en" ? "en-GB" : "pt-BR"
    }

    static func available(for translationLanguage: String) -> [AVSpeechSynthesisVoice] {
        let prefix = languagePrefix(for: translationLanguage)
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(prefix) && !$0.identifier.contains("speech.synthesis.voice") }
            .sorted { lhs, rhs in
                lhs.quality.rawValue != rhs.quality.rawValue
                    ? lhs.quality.rawValue > rhs.quality.rawValue
                    : lhs.name < rhs.name
            }
    }

    static func resolve(identifier: String, translationLanguage: String) -> AVSpeechSynthesisVoice? {
        let prefix = languagePrefix(for: translationLanguage)
        if let saved = AVSpeechSynthesisVoice(identifier: identifier), saved.language.hasPrefix(prefix) {
            return saved
        }
        return AVSpeechSynthesisVoice(language: defaultLanguage(for: translationLanguage))
    }
}

@MainActor
@Observable
final class SpeechController: NSObject {
    private(set) var isSpeaking = false
    private(set) var isPaused = false
    private(set) var currentVerse: Int?
    private(set) var completions = 0

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var verseByUtterance: [ObjectIdentifier: Int] = [:]
    @ObservationIgnored private var lastUtterance: ObjectIdentifier?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func start(header: String?, verses: [SpokenVerse], voice: AVSpeechSynthesisVoice?, rate: Float) {
        stop()
        guard !verses.isEmpty else { return }
        activateAudioSession()
        isSpeaking = true
        isPaused = false

        let clampedRate = min(max(rate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        var last: ObjectIdentifier?

        func enqueue(_ text: String, verse: Int) {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = voice
            utterance.rate = clampedRate
            utterance.postUtteranceDelay = 0.15
            let id = ObjectIdentifier(utterance)
            verseByUtterance[id] = verse
            last = id
            synthesizer.speak(utterance)
        }

        if let header { enqueue(header, verse: 0) }
        for verse in verses { enqueue(verse.text, verse: verse.number) }
        lastUtterance = last
    }

    func stop() {
        let wasActive = isSpeaking
        synthesizer.stopSpeaking(at: .immediate)
        verseByUtterance.removeAll()
        lastUtterance = nil
        isSpeaking = false
        isPaused = false
        currentVerse = nil
        if wasActive { deactivateAudioSession() }
    }

    func togglePause() {
        guard isSpeaking else { return }
        if isPaused {
            synthesizer.continueSpeaking()
        } else {
            synthesizer.pauseSpeaking(at: .word)
        }
        isPaused.toggle()
    }

    fileprivate func handleStart(_ id: ObjectIdentifier) {
        guard let verse = verseByUtterance[id] else { return }
        currentVerse = verse == 0 ? nil : verse
    }

    fileprivate func handleFinish(_ id: ObjectIdentifier) {
        guard verseByUtterance[id] != nil else { return }
        verseByUtterance[id] = nil
        guard id == lastUtterance else { return }
        lastUtterance = nil
        isSpeaking = false
        isPaused = false
        currentVerse = nil
        deactivateAudioSession()
        completions += 1
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

extension SpeechController: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didStart utterance: AVSpeechUtterance
    ) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.handleStart(id) }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.handleFinish(id) }
    }
}
