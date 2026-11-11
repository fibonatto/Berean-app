import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum Theme {
    static let paper = Color(hex: 0xFAF5E5)
    static let paperAlt = Color(hex: 0xEEEADD)
    static let border = Color(hex: 0xD3CEBD)
    static let ink = Color(hex: 0x1B1F2A)
    static let inkSoft = Color(hex: 0x4A505E)
    static let accent = Color(hex: 0x2C67B3)
    static let verseNumber = Color(hex: 0x9A6138)
    static let ornament = Color(hex: 0xD15A4D)
    static let highlight = Color(hex: 0xD6E5F8)
    static let verseNumberOnMark = Color(hex: 0x7E4A28)
    static let star = Color(hex: 0x9E3526)
    static let markYellow = Color(hex: 0xF2E6B0)
    static let markGreen = Color(hex: 0xD6E8C4)
    static let markRose = Color(hex: 0xF5CFC8)

    static func serif(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif, weight: weight)
    }

    static func configureNavigationBar() {
        let bar = UINavigationBar.appearance()
        let color = UIColor(ink)
        bar.titleTextAttributes = [
            .font: serifUIFont(size: 17, weight: .semibold),
            .foregroundColor: color
        ]
        bar.largeTitleTextAttributes = [
            .font: serifUIFont(size: 34, weight: .bold),
            .foregroundColor: color
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
