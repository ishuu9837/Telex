import SwiftUI
import AppKit

@MainActor enum BrandAssets {
    static var logo: NSImage {
        #if SWIFT_PACKAGE
        let resources = Bundle.module
        #else
        let resources = Bundle.main
        #endif
        if let url = resources.url(forResource: "AppIcon", withExtension: "png", subdirectory: "Resources"), let image = NSImage(contentsOf: url) { return image }
        if let url = resources.url(forResource: "AppIcon", withExtension: "png"), let image = NSImage(contentsOf: url) { return image }
        return NSApplication.shared.applicationIconImage
    }
    static let menuMark: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            func polygon(_ points: [NSPoint]) {
                guard let first = points.first else { return }
                let path = NSBezierPath(); path.move(to: first)
                points.dropFirst().forEach { path.line(to: $0) }; path.close(); path.fill()
            }
            NSBezierPath(ovalIn: NSRect(x: 7.5, y: 14, width: 3, height: 3)).fill()
            polygon([NSPoint(x: 1, y: 2), NSPoint(x: 1, y: 14), NSPoint(x: 3, y: 15), NSPoint(x: 8.5, y: 10), NSPoint(x: 8.5, y: 7), NSPoint(x: 3.5, y: 11), NSPoint(x: 3.5, y: 3)])
            polygon([NSPoint(x: 17, y: 2), NSPoint(x: 17, y: 14), NSPoint(x: 15, y: 15), NSPoint(x: 9.5, y: 10), NSPoint(x: 9.5, y: 7), NSPoint(x: 14.5, y: 11), NSPoint(x: 14.5, y: 3)])
            polygon([NSPoint(x: 4, y: 10), NSPoint(x: 9, y: 6), NSPoint(x: 14, y: 10), NSPoint(x: 14, y: 7.5), NSPoint(x: 10.5, y: 4.5), NSPoint(x: 15, y: 1), NSPoint(x: 12, y: 1), NSPoint(x: 9, y: 3.5), NSPoint(x: 6, y: 1), NSPoint(x: 3, y: 1), NSPoint(x: 7.5, y: 4.5), NSPoint(x: 4, y: 7.5)])
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Telex menu"
        return image
    }()
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: BrandAssets.logo).resizable().frame(width: 96, height: 96).accessibilityLabel("Telex M and X logo")
            Text("Telex").font(.largeTitle.bold())
            Text("Your words. Your pace.").foregroundStyle(.secondary)
            Text("Version 1.0 · Built for macOS").font(.caption)
            Text("Scripts, voice processing and recordings stay on your Mac.").font(.caption).multilineTextAlignment(.center)
        }.padding(36).frame(width: 360, height: 350)
    }
}
