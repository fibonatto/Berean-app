import Observation
import SwiftUI
import UIKit

nonisolated enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case automatic, light, sepia, dark

    static let storageKey = "appTheme"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .light: "Light"
        case .sepia: "Sepia"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .automatic: nil
        case .light, .sepia: .light
        case .dark: .dark
        }
    }

    static var stored: AppTheme {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppTheme.init(rawValue:)) ?? .automatic
    }

    func spec(for style: UIUserInterfaceStyle) -> PaletteSpec {
        switch self {
        case .light: .light
        case .sepia: .sepia
        case .dark: .dark
        case .automatic: style == .dark ? .dark : .light
        }
    }
}

nonisolated struct PaletteSpec: Sendable {
    let paper: UInt32
    let paperAlt: UInt32
    let border: UInt32
    let ink: UInt32
    let inkSoft: UInt32
    let accent: UInt32
    let verseNumber: UInt32
    let verseNumberOnMark: UInt32
    let ornament: UInt32
    let star: UInt32
    let highlight: UInt32
    let markYellow: UInt32
    let markGreen: UInt32
    let markRose: UInt32

    static let light = PaletteSpec(
        paper: 0xFAF5E5, paperAlt: 0xEEEADD, border: 0xD3CEBD,
        ink: 0x1B1F2A, inkSoft: 0x4A505E, accent: 0x2C67B3,
        verseNumber: 0x9A6138, verseNumberOnMark: 0x7E4A28,
        ornament: 0xD15A4D, star: 0x9E3526, highlight: 0xD6E5F8,
        markYellow: 0xF2E6B0, markGreen: 0xD6E8C4, markRose: 0xF5CFC8
    )

    static let sepia = PaletteSpec(
        paper: 0xF1E6CC, paperAlt: 0xE6D9B8, border: 0xCDBE9A,
        ink: 0x2B2218, inkSoft: 0x5B4C38, accent: 0x24599A,
        verseNumber: 0x84502A, verseNumberOnMark: 0x6B3C1D,
        ornament: 0xB8473A, star: 0x8C2A1B, highlight: 0xC9D9E6,
        markYellow: 0xE8D27A, markGreen: 0xC9DDA6, markRose: 0xE8BBAE
    )

    static let dark = PaletteSpec(
        paper: 0x1E1F22, paperAlt: 0x28292D, border: 0x3C3E43,
        ink: 0xDCD9D0, inkSoft: 0xA9A79F, accent: 0x86AEE6,
        verseNumber: 0xD69A67, verseNumberOnMark: 0xF0CDA0,
        ornament: 0xE27C6D, star: 0xF4A898, highlight: 0x31435A,
        markYellow: 0x514A24, markGreen: 0x2E4835, markRose: 0x553333
    )
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension UIColor {
    nonisolated convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

@MainActor
@Observable
final class ThemeStore {
    static let shared = ThemeStore()

    private(set) var current = AppTheme.stored

    private init() {}

    func select(_ theme: AppTheme) {
        current = theme
        UserDefaults.standard.set(theme.rawValue, forKey: AppTheme.storageKey)
    }

    func color(_ keyPath: KeyPath<PaletteSpec, UInt32>) -> Color {
        let theme = current
        guard theme == .automatic else {
            return Color(hex: theme.spec(for: .light)[keyPath: keyPath])
        }
        let light = PaletteSpec.light[keyPath: keyPath]
        let dark = PaletteSpec.dark[keyPath: keyPath]
        return Color(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

enum Theme {
    static var paper: Color { ThemeStore.shared.color(\.paper) }
    static var paperAlt: Color { ThemeStore.shared.color(\.paperAlt) }
    static var border: Color { ThemeStore.shared.color(\.border) }
    static var ink: Color { ThemeStore.shared.color(\.ink) }
    static var inkSoft: Color { ThemeStore.shared.color(\.inkSoft) }
    static var accent: Color { ThemeStore.shared.color(\.accent) }
    static var verseNumber: Color { ThemeStore.shared.color(\.verseNumber) }
    static var verseNumberOnMark: Color { ThemeStore.shared.color(\.verseNumberOnMark) }
    static var ornament: Color { ThemeStore.shared.color(\.ornament) }
    static var star: Color { ThemeStore.shared.color(\.star) }
    static var highlight: Color { ThemeStore.shared.color(\.highlight) }
    static var markYellow: Color { ThemeStore.shared.color(\.markYellow) }
    static var markGreen: Color { ThemeStore.shared.color(\.markGreen) }
    static var markRose: Color { ThemeStore.shared.color(\.markRose) }

    static func serif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif, weight: weight)
    }

    static func configureNavigationBar() {
        let bar = UINavigationBar.appearance()
        let ink = UIColor { traits in
            UIColor(hex: AppTheme.stored.spec(for: traits.userInterfaceStyle).ink)
        }
        bar.titleTextAttributes = [
            .font: serifUIFont(size: 17, weight: .semibold),
            .foregroundColor: ink,
        ]
        bar.largeTitleTextAttributes = [
            .font: serifUIFont(size: 34, weight: .bold),
            .foregroundColor: ink,
        ]
    }

    private static func serifUIFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
        return UIFont(descriptor: descriptor, size: size)
    }
}

extension MarkColor {
    var color: Color {
        switch self {
        case .yellow: Theme.markYellow
        case .green: Theme.markGreen
        case .rose: Theme.markRose
        }
    }
}
