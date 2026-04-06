//
//  Color+Hex.swift
//  ToJo
//

import SwiftUI
#if os(macOS)
import AppKit
private typealias PlatformColor = NSColor
#else
import UIKit
private typealias PlatformColor = UIColor
#endif

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

    private func rgbaComponents() -> (r: Double, g: Double, b: Double)? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if os(macOS)
        guard let converted = PlatformColor(self).usingColorSpace(.sRGB) else { return nil }
        converted.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        guard PlatformColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        #endif
        return (Double(r), Double(g), Double(b))
    }

    /// Returns `.black` or `.white` — whichever contrasts better with this color.
    var contrastingTextColor: Color {
        guard let c = rgbaComponents() else { return .primary }
        let brightness = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
        return brightness > 0.5 ? .black : .white
    }

    var hexString: String? {
        guard let c = rgbaComponents() else { return nil }
        return String(format: "%02X%02X%02X", Int(c.r * 255), Int(c.g * 255), Int(c.b * 255))
    }
}
