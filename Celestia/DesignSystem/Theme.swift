import SwiftUI

/// SwiftUI view of the gateway's design tokens.
struct Theme: Equatable {
    var accent: Color
    var stageTop: Color
    var stageBottom: Color
    var glassFill: Double
    var glassStroke: Double
    var cornerRadius: CGFloat

    init(_ tokens: DesignTokens) {
        let fallback = DesignTokens.fallback
        accent = Color(hex: tokens.accent) ?? Color(hex: fallback.accent)!
        stageTop = Color(hex: tokens.stageTop) ?? Color(hex: fallback.stageTop)!
        stageBottom = Color(hex: tokens.stageBottom) ?? Color(hex: fallback.stageBottom)!
        glassFill = min(max(tokens.glassFill, 0.02), 0.4)
        glassStroke = min(max(tokens.glassStroke, 0.05), 0.8)
        cornerRadius = CGFloat(min(max(tokens.cornerRadius, 8), 48))
    }

    static let fallback = Theme(.fallback)
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.fallback
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension Color {
    /// Parses `#RRGGBB` or `#RRGGBBAA`.
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let value = UInt64(s, radix: 16) else { return nil }
        let r, g, b, a: Double
        if s.count == 6 {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        } else {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
