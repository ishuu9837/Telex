import SwiftUI
struct CountdownOverlayView: View {
    var remaining: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            Color.black
            VStack(spacing: 8) {
                Text(reduceMotion ? "Ready" : "\(remaining)").font(.system(size: 40, weight: .medium, design: .monospaced))
                Text("Eyes up. You’re ready.").font(.caption).foregroundStyle(.secondary)
            }
        }.accessibilityLabel("Starting in \(remaining) seconds")
    }
}
