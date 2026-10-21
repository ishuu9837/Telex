import SwiftUI
struct SettingsView: View {
    @Bindable var app: AppCoordinator
    var body: some View {
        TabView {
            ScrollView { PrompterInspectorView(app: app) }.tabItem { Label("Prompter", systemImage: "text.viewfinder") }
            Form {
                Text("Shortcuts work while other apps have focus.").foregroundStyle(.secondary)
                ForEach(Array(GlobalHotkeyService.shortcuts.enumerated()), id: \.offset) { _, binding in Text(binding.2) }
                Text("⌃⌥1…9 · Jump to cue")
            }.padding(24).tabItem { Label("Shortcuts", systemImage: "keyboard") }
            Form {
                Text("Telex runs locally. No accounts, uploads, or analytics.")
                Text(CaptureExclusionService.guidance).foregroundStyle(.secondary)
                Button("Microphone settings") { app.permissions.openSettings() }
                Button("Screen recording settings") { app.permissions.openSettings("Privacy_ScreenCapture") }
                Button("Quick Tour…") { app.openWorkspace?(); app.presentedSheet = .tour }
                Button("Terms of Service…") { app.openWorkspace?(); app.presentedSheet = .terms }
                Button("Repeat setup") { app.openWorkspace?(); app.showOnboarding = true }
                Text("Script words mode transcribes on-device and advances only through matched words. Choose Voice activity for language-independent fixed-speed pacing.").font(.caption).foregroundStyle(.secondary)
            }.padding(24).tabItem { Label("Privacy", systemImage: "lock.shield") }
        }.frame(width: 450, height: 610).preferredColorScheme(.dark)
    }
}
