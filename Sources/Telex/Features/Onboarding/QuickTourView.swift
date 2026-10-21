import SwiftUI

struct QuickTourView: View {
    @Bindable var app: AppCoordinator
    @State private var progress = TourProgress()
    private let titles = ["Start with your words", "Read without a microphone", "Let your voice set the pace", "Your controls stay close", "Know what Stealth can do"]
    private let icons = ["doc.text", "mic.slash", "waveform", "playpause", "shield.lefthalf.filled"]
    private let descriptions = [
        "Write or import a script. Add # Headings to create cues, then jump between sections and return to your previous spot.",
        "Choose No microphone, pick Very slow through Very high, and press Start reading. Text moves continuously without microphone or Siri permission.",
        "Voice level scrolls when you speak and holds in silence. If the input level stays low, lower the sensitivity threshold. Script words is optional and requires separate Apple permission.",
        "Hover pauses the text. Move your pointer away to resume, or click Pause to lock it. The prompter bar has cues, speed, dock, stop, hide and Quit. Click-through is unlocked with ⇧⌘L or the menu bar.",
        "Stealth is Limited on macOS 15 or later. macOS still shows the microphone or recording indicator and the app using it. No microphone mode avoids prompting microphone use; sharing a single app window is safer than sharing a whole display."
    ]
    var body: some View {
        VStack(spacing: 22) {
            HStack { Text("QUICK TOUR").font(.system(size: 10, weight: .bold, design: .monospaced)).tracking(2); Spacer(); Text("\(progress.index + 1) / \(TourProgress.count)").font(.caption) }.foregroundStyle(.secondary)
            Image(systemName: icons[progress.index]).font(.system(size: 45)).foregroundStyle(DesignTokens.periwinkle).frame(height: 75).accessibilityHidden(true)
            Text(titles[progress.index]).font(.title2.bold()).multilineTextAlignment(.center)
            Text(descriptions[progress.index]).font(.system(size: 14)).lineSpacing(5).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(height: 130)
            HStack {
                Toggle("Tour sounds", isOn: Binding(get: { app.preferences.tourSoundsEnabled }, set: { app.preferences.tourSoundsEnabled = $0; if !$0 { app.tourSound.stop() } })).toggleStyle(.switch)
                Spacer()
                Button("Preview sound") { app.tourSound.play(enabled: app.preferences.tourSoundsEnabled) }.disabled(!app.preferences.tourSoundsEnabled)
            }.font(.caption)
            HStack {
                Button("Skip tour") { app.completeTour() }
                Spacer()
                Button("Back") { progress.back() }.disabled(progress.index == 0)
                Button(progress.isLast ? "Ready to read" : "Next") {
                    if progress.isLast { app.completeTour() } else { progress.next() }
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(30).frame(width: 540)
        .onAppear { app.tourSound.play(enabled: app.preferences.tourSoundsEnabled) }
        .onChange(of: progress.index) { _, _ in app.tourSound.play(enabled: app.preferences.tourSoundsEnabled) }
        .onDisappear { app.tourSound.stop() }
        .interactiveDismissDisabled()
    }
}
