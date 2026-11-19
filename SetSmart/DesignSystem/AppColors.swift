import SwiftUI

extension Color {
    // Backgrounds
    static let ssBackground    = Color(hex: "#09090B")
    static let ssSurface       = Color(hex: "#18181B")
    static let ssBorder        = Color(hex: "#27272A")
    static let ssSurfaceRaised = Color(hex: "#27272A")

    // Text
    static let ssTextPrimary   = Color(hex: "#F4F4F5")
    static let ssTextSecondary = Color(hex: "#A1A1AA")
    static let ssTextMuted     = Color(hex: "#71717A")

    // Accent (lime)
    static let ssAccent        = Color(hex: "#A3E635")
    static let ssAccentStrong  = Color(hex: "#BEF264")

    // Chart / data
    static let ssChartSeries      = Color(hex: "#65A30D")
    static let ssChartDeemphasis  = Color(hex: "#71717A")
    static let ssMeterTrack       = Color(hex: "#1A2E05")

    // Semantic
    static let ssWarning     = Color(hex: "#D97706")
    static let ssWarningText = Color(hex: "#FCD34D")
    static let ssDanger      = Color(hex: "#EF4444")
    static let ssDangerText  = Color(hex: "#FCA5A5")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}
