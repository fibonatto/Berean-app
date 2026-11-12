//
//  WidgetPalette.swift
//  Berean
//
//  Created by Sergio Bonatto on 12/11/26.
//

import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum WidgetPalette {
    static let paper = Color(hex: 0xFAF5E5)
    static let ink = Color(hex: 0x1B1F2A)
    static let inkSoft = Color(hex: 0x4A505E)
    static let border = Color(hex: 0xD3CEBD)
    static let reference = Color(hex: 0x9A6138)
}
