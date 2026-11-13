import AVFoundation
import SwiftUI

enum ReaderFont: String, CaseIterable, Identifiable {
    case newYork, iowan, charter, georgia, palatino

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newYork: "New York"
        case .iowan: "Iowan Old Style"
        case .charter: "Charter"
        case .georgia: "Georgia"
        case .palatino: "Palatino"
        }
    }

    var bodyFont: Font {
        switch self {
        case .newYork: Theme.serif(.body)
        case .iowan: .custom("IowanOldStyle-Roman", size: 17, relativeTo: .body)
        case .charter: .custom("Charter-Roman", size: 17, relativeTo: .body)
        case .georgia: .custom("Georgia", size: 17, relativeTo: .body)
        case .palatino: .custom("Palatino-Roman", size: 17, relativeTo: .body)
        }
    }
}

enum ReaderSpacing: Int, CaseIterable, Identifiable {
    case compact, normal, relaxed

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .compact: "Compact"
        case .normal: "Normal"
        case .relaxed: "Relaxed"
        }
    }

    var points: CGFloat {
        switch self {
        case .compact: 3
        case .normal: 6
        case .relaxed: 10
        }
    }
}

enum ReaderMargin: Int, CaseIterable, Identifiable {
    case narrow, normal, wide

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .narrow: "Narrow"
        case .normal: "Normal"
        case .wide: "Wide"
        }
    }

    var points: CGFloat {
        switch self {
        case .narrow: 8
        case .normal: 18
        case .wide: 32
        }
    }
}

enum ReaderStyle {
    static let sizeSteps = -3...6
    static let speechRates = [0.75, 1.0, 1.25, 1.5]

    static func textSize(system: DynamicTypeSize, step: Int) -> DynamicTypeSize {
        let sizes = DynamicTypeSize.allCases
        let base = sizes.firstIndex(of: system) ?? 0
        return sizes[min(max(base + step, 0), sizes.count - 1)]
    }

    static func speedLabel(_ value: Double) -> String {
        String(format: "%g×", value)
    }
}

struct ReaderSettingsView: View {
    @Environment(BibleStore.self) private var store
    @Environment(\.dynamicTypeSize) private var systemTypeSize
    @AppStorage("readerSizeStep") private var sizeStep = 0
    @AppStorage("readerFont") private var readerFont = ReaderFont.newYork
    @AppStorage("readerSpacing") private var spacing = ReaderSpacing.normal
    @AppStorage("readerMargin") private var margin = ReaderMargin.normal
    @AppStorage("speechVoice") private var voiceID = ""
    @AppStorage("speechRate") private var speechRate = 1.0
    @AppStorage("speechAutoAdvance") private var autoAdvance = true

    let sample: String

    private let previewShape = RoundedRectangle(cornerRadius: 8)

    private var appearance: Binding<AppTheme> {
        Binding(
            get: { ThemeStore.shared.current },
            set: { ThemeStore.shared.select($0) }
        )
    }

    private var voices: [AVSpeechSynthesisVoice] {
        SpeechVoices.available(for: store.translation.language)
    }

    private var voiceSelection: Binding<String> {
        let available = voices
        return Binding(
            get: { available.contains { $0.identifier == voiceID } ? voiceID : "" },
            set: { voiceID = $0 }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                preview
                section("Appearance") {
                    Picker("Appearance", selection: appearance) {
                        ForEach(AppTheme.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                section("Size") {
                    HStack(spacing: 12) {
                        Image(systemName: "textformat.size.smaller")
                        Slider(
                            value: Binding(
                                get: { Double(sizeStep) },
                                set: { sizeStep = Int($0.rounded()) }
                            ),
                            in: Double(ReaderStyle.sizeSteps.lowerBound)...Double(ReaderStyle.sizeSteps.upperBound),
                            step: 1
                        )
                        Image(systemName: "textformat.size.larger")
                    }
                    .foregroundStyle(Theme.inkSoft)
                }
                section("Font") {
                    Picker("Font", selection: $readerFont) {
                        ForEach(ReaderFont.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                section("Line spacing") {
                    Picker("Spacing", selection: $spacing) {
                        ForEach(ReaderSpacing.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                section("Margins") {
                    Picker("Margins", selection: $margin) {
                        ForEach(ReaderMargin.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                section("Read aloud") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Voice", selection: voiceSelection) {
                            Text("Default").tag("")
                            ForEach(voices, id: \.identifier) { voice in
                                Text(Self.voiceTitle(voice)).tag(voice.identifier)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        Picker("Speed", selection: $speechRate) {
                            ForEach(ReaderStyle.speechRates, id: \.self) {
                                Text(ReaderStyle.speedLabel($0)).tag($0)
                            }
                        }
                        .pickerStyle(.segmented)
                        Toggle("Continue to the next chapter", isOn: $autoAdvance)
                        Text("Better voices: Settings → Accessibility → Spoken Content → Voices.")
                            .font(Theme.serif(.footnote))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Button("Reset to defaults", action: reset)
                    .font(Theme.serif(.subheadline))
            }
            .padding(20)
        }
        .background(Theme.paper)
        .presentationBackground(Theme.paper)
    }

    private var preview: some View {
        Text(sample)
            .font(readerFont.bodyFont)
            .lineSpacing(spacing.points)
            .lineLimit(4)
            .dynamicTypeSize(ReaderStyle.textSize(system: systemTypeSize, step: sizeStep))
            .foregroundStyle(Theme.ink)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(Theme.paperAlt, in: previewShape)
            .overlay { previewShape.stroke(Theme.border, lineWidth: 1) }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(Theme.serif(.caption, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.inkSoft)
            content()
        }
    }

    private static func voiceTitle(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium: "\(voice.name) (Premium)"
        case .enhanced: "\(voice.name) (Enhanced)"
        default: voice.name
        }
    }

    private func reset() {
        sizeStep = 0
        readerFont = .newYork
        spacing = .normal
        margin = .normal
        voiceID = ""
        speechRate = 1.0
        autoAdvance = true
    }
}
