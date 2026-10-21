import SwiftUI

struct LaunchIntroView: View {
    var finished: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    var body: some View {
        ZStack {
            Color(hex: "#090914")
            RadialGradient(colors: [DesignTokens.violet.opacity(0.45), .clear], center: .center, startRadius: 20, endRadius: 350)
            VStack(spacing: 20) {
                Image(nsImage: BrandAssets.logo).resizable().frame(width: 100, height: 100)
                    .scaleEffect(reduceMotion || revealed ? 1 : 0.82)
                Text("Telex").font(.system(size: 44, weight: .semibold))
                Text("Your words. Your pace.").font(.system(size: 15, design: .monospaced)).foregroundStyle(.secondary)
                Rectangle().fill(LinearGradient(colors: [DesignTokens.periwinkle, DesignTokens.violet, .green], startPoint: .leading, endPoint: .trailing))
                    .frame(width: revealed ? 210 : 0, height: 1).padding(.top, 15)
            }.opacity(reduceMotion || revealed ? 1 : 0)
            VStack { HStack { Spacer(); Button("Skip intro") { finished() }.accessibilityIdentifier("intro.skip").buttonStyle(.plain).foregroundStyle(.secondary) }; Spacer() }.padding(28)
        }
        .task {
            if reduceMotion { revealed = true } else { withAnimation(.easeOut(duration: 0.65)) { revealed = true } }
            do { try await Task.sleep(for: .milliseconds(reduceMotion ? 250 : 1600)) } catch { return }
            finished()
        }
        .accessibilityElement(children: .contain).accessibilityLabel("Telex introduction")
    }
}
