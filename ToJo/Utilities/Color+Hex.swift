//
//  Color+Hex.swift
//  ToJo
//

import SwiftUI

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Returns `.black` or `.white` — whichever contrasts better with this color.
    var contrastingTextColor: Color {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else { return .primary }
        let brightness = 0.299 * components.redComponent
                       + 0.587 * components.greenComponent
                       + 0.114 * components.blueComponent
        return brightness > 0.5 ? .black : .white
    }

    var hexString: String? {
        guard let components = NSColor(self).usingColorSpace(.sRGB) else { return nil }
        let r = Int(components.redComponent * 255)
        let g = Int(components.greenComponent * 255)
        let b = Int(components.blueComponent * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
