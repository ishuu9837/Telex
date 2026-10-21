import SwiftUI

struct InputLevelMeter: View {
    var levelDB: Double
    var active: Bool
    private var fraction: Double { active ? min(1, max(0, (levelDB + 60) / 60)) : 0 }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Input level")
                Spacer()
                Text(active ? (levelDB <= -60 ? "Silence" : "\(Int(levelDB)) dBFS") : "Microphone off").monospacedDigit()
            }.font(.caption2).foregroundStyle(.secondary)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3).fill(LinearGradient(colors: [.green, .yellow, .orange], startPoint: .leading, endPoint: .trailing)).frame(width: geometry.size.width * fraction)
                    HStack(spacing: 2) { ForEach(0..<24) { _ in Rectangle().fill(.black.opacity(0.25)).frame(width: 1); Spacer(minLength: 0) } }
                }
            }.frame(height: 10).allowsHitTesting(false)
            Text(active ? "Speak to see the level rise. This meter cannot be dragged." : "The microphone stays off while editing. Use Test microphone to check sensitivity.")
                .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Input level meter")
        .accessibilityValue(active ? "\(Int(fraction * 100)) percent, \(Int(levelDB)) decibels" : "Microphone off")
        .help("Live microphone loudness, not a slider. Far left means silence or microphone off.")
    }
}
