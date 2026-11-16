import SwiftUI
import Foundation

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

enum IconExporter {
    /// Renders a SwiftUI view to PNG data at a specific pixel size and writes it to the Documents directory.
    /// - Parameters:
    ///   - view: The SwiftUI view to render.
    ///   - size: The pixel size (width = height) for the output PNG.
    ///   - fileName: The file name (e.g., "AppIcon-1024.png").
    /// - Returns: The file URL where the PNG was written.
    @discardableResult
    static func exportPNG<V: View>(of view: V, size: CGFloat, fileName: String = "AppIcon-1024.png") throws -> URL {
        #if canImport(UIKit)
        let renderer = ImageRenderer(content: view.frame(width: size, height: size))
        renderer.scale = 1 // size is in pixels for renderer when used this way
        guard let uiImage = renderer.uiImage else { throw NSError(domain: "IconExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render image"]) }
        guard let data = uiImage.pngData() else { throw NSError(domain: "IconExporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"]) }
        #elseif canImport(AppKit)
        let renderer = ImageRenderer(content: view.frame(width: size, height: size))
        renderer.scale = 1
        guard let nsImage = renderer.nsImage else { throw NSError(domain: "IconExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render image"]) }
        guard let data = nsImage.pngData() else { throw NSError(domain: "IconExporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"]) }
        #else
        throw NSError(domain: "IconExporter", code: 0, userInfo: [NSLocalizedDescriptionKey: "Unsupported platform"]) 
        #endif

        let url = try writeToDocuments(data: data, fileName: fileName)
        return url
    }

    /// Convenience: export the brand logo at 1024x1024.
    static func exportBrandLogo1024() throws -> URL {
        try exportPNG(of: BrandLogoView(), size: 1024, fileName: "AppIcon-1024.png")
    }

    private static func writeToDocuments(data: Data, fileName: String) throws -> URL {
        let fm = FileManager.default
        #if os(iOS) || os(tvOS) || os(watchOS)
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        #elseif os(macOS)
        let dir = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        #else
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        #endif
        let url = dir.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }
}

#if canImport(AppKit)
private extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = self.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let data = bitmap.representation(using: .png, properties: [:])
        else { return nil }
        return data
    }
}
#endif

#Preview("Export Brand Logo 1024") {
    VStack(spacing: 12) {
        BrandLogoView()
            .frame(width: 200, height: 200)
        Button("Export 1024 PNG to Documents/Downloads") {
            do {
                let url = try IconExporter.exportBrandLogo1024()
                print("Exported icon to: \(url.path)")
            } catch {
                print("Failed to export icon: \(error)")
            }
        }
    }
    .padding()
}
