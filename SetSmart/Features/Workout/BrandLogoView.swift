import SwiftUI

struct BrandLogoView: View {
    // Configurable colors (fallbacks if custom colors unavailable)
    var baseColor: Color = Color(white: 0.08) // deep charcoal
    var surfaceColor: Color = Color(white: 0.16)
    var accentColor: Color = {
        // Try to use Color.ssAccent if defined in the project.
        if let accent = Color(named: "ssAccent") { return accent }
        return Color(red: 0.0, green: 0.68, blue: 0.94) // cyan/blue accent fallback
    }()

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let ringOuter = size * 0.8
            let ringInner = ringOuter * 0.62
            let lineThickness = size * 0.08

            ZStack {
                // Background circle (for previews/icons when exported on transparent bg)
                Circle()
                    .fill(baseColor)

                // Barbell plate ring
                ZStack {
                    Circle()
                        .strokeBorder(surfaceColor, lineWidth: size * 0.08)
                        .frame(width: ringOuter, height: ringOuter)
                        .shadow(color: Color.black.opacity(0.15), radius: size * 0.02, x: 0, y: size * 0.01)

                    Circle()
                        .fill(baseColor)
                        .frame(width: ringInner, height: ringInner)
                }

                // Rising progress line (slanted bar/graph motif)
                ProgressSlash()
                    .stroke(accentColor, style: StrokeStyle(lineWidth: lineThickness, lineCap: .round, lineJoin: .round))
                    .frame(width: size * 0.9, height: size * 0.9)
                    .offset(x: 0, y: size * 0.02)
                    .shadow(color: accentColor.opacity(0.4), radius: size * 0.03, x: 0, y: size * 0.01)
            }
            .compositingGroup()
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private struct ProgressSlash: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Draw a rising line from lower-left to upper-right with a slight curve
        let inset = min(rect.width, rect.height) * 0.18
        let start = CGPoint(x: rect.minX + inset * 0.6, y: rect.maxY - inset)
        let end   = CGPoint(x: rect.maxX - inset * 0.6, y: rect.minY + inset * 0.9)
        let cp1   = CGPoint(x: rect.minX + rect.width * 0.35, y: rect.midY + inset * 0.2)
        let cp2   = CGPoint(x: rect.midX + inset * 0.4, y: rect.minY + inset * 0.6)

        p.move(to: start)
        p.addCurve(to: end, control1: cp1, control2: cp2)

        // Add a short bar at the end to suggest a graph tick
        let tickLen = rect.width * 0.12
        let angle: CGFloat = -20 * .pi / 180
        let dx = cos(angle) * tickLen
        let dy = sin(angle) * tickLen
        p.move(to: end)
        p.addLine(to: CGPoint(x: end.x + dx, y: end.y + dy))

        return p
    }
}

extension Color {
    // Attempt to resolve a named color if present; otherwise return nil
    init?(named name: String) {
        #if canImport(UIKit)
        if let uiColor = UIColor(named: name) { self = Color(uiColor); return }
        #elseif canImport(AppKit)
        if let nsColor = NSColor(named: NSColor.Name(name)) { self = Color(nsColor); return }
        #endif
        return nil
    }
}

#Preview("Brand Logo") {
    ZStack {
        Color(white: 0.07).ignoresSafeArea()
        VStack(spacing: 20) {
            BrandLogoView()
                .frame(width: 200, height: 200)
            Text("Brand Logo Preview")
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding()
    }
}
