import SwiftUI
struct OnboardingView: View {
    @Bindable var app: AppCoordinator
    @State private var step = 0
    var body: some View {
        VStack(spacing: 24) {
            HStack { Text("TELEX").font(.system(size: 12, weight: .bold, design: .monospaced)).tracking(4); Spacer(); Text("\(step + 1) / 3").font(.caption.monospacedDigit()) }.foregroundStyle(.white.opacity(0.7))
            Spacer()
            Image(nsImage: BrandAssets.logo).resizable().frame(width: 80, height: 80)
            Text(["Eyes up. Words ready.", "Your voice sets the pace.", "Share with confidence."][step]).font(.system(size: 32, weight: .semibold)).multilineTextAlignment(.center)
            Text(["Keep your script beside your camera. Stretch it to fit, or float it anywhere on your screen.", "Telex uses your microphone locally to follow when you speak. Hover to pause, or click Pause to hold your place. You can also use manual pacing.", "Stealth is limited on macOS 15 and later. Share a single app window or a second display. Built-in recordings always exclude Telex."][step])
                .font(.system(size: 15)).lineSpacing(5).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center).frame(maxWidth: 410)
            if step == 1 {
                Button("Enable microphone") { Task { if !(await app.permissions.requestMicrophone()) { app.preferences.voicePacingEnabled = false } } }.buttonStyle(.bordered)
                Button("Use no-microphone mode") { app.setPacingMode(.noMicrophone); step = 2 }.buttonStyle(.plain).font(.caption)
            }
            Spacer()
            HStack {
                Button(step == 0 ? "Skip setup" : "Back") { if step == 0 { app.completeOnboarding() } else { step -= 1 } }.buttonStyle(.plain)
                Spacer()
                Button(step == 2 ? "Open workspace" : "Continue") { if step < 2 { step += 1 } else { app.completeOnboarding() } }.buttonStyle(.borderedProminent).tint(.white).foregroundStyle(Color(hex: "#1717B8")).keyboardShortcut(.defaultAction)
            }
        }.padding(36).frame(width: 540, height: 530).foregroundStyle(.white)
        .background(LinearGradient(colors: [Color(hex: "#8794F2"), Color(hex: "#3938D6"), Color(hex: "#11114F")], startPoint: .topLeading, endPoint: .bottomTrailing))
        .overlay(alignment: .top) { LinearGradient(colors: [.white, DesignTokens.periwinkle, .green], startPoint: .leading, endPoint: .trailing).frame(height: 1) }
        .interactiveDismissDisabled()
    }
}
