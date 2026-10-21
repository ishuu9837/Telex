import SwiftUI
struct MenuBarView: View {
    @Bindable var app: AppCoordinator
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Text(app.prompter.status)
        Text("Telex microphone: \(app.microphoneActivity)")
        Button(app.window.visible ? "Hide Prompter" : "Show Prompter") { app.handlePrompterAction(app.window.visible ? .hide : .show) }
        Button(app.prompter.running && !app.prompter.manualPaused ? "Lock Pause" : "Play / Resume") { app.playPause() }
        Button("Stop") { app.stop() }
        Button("Open Workspace") { openWindow(id: "workspace"); NSApplication.shared.activate(ignoringOtherApps: true) }
        Divider()
        Menu("Jump to Cue") { ForEach(app.draft.cues) { cue in Button(cue.title) { app.handlePrompterAction(.jumpToCue(cue.id)) } } }
        Button("Back to Previous Spot") { app.handlePrompterAction(.returnToSpot) }.disabled(app.prompter.cueService.returnPositionStack.isEmpty)
        Button(app.preferences.clickThroughEnabled ? "Click-Through ON — Unlock Prompter (⇧⌘L)" : "Enable Click-Through") { app.preferences.clickThroughEnabled.toggle() }
        Button(app.recorder.isRecording ? "Stop Recording…" : "Record Screen…") { app.handlePrompterAction(.record) }
        Divider()
        Toggle(CaptureExclusionService.toggleLabel(enabled: app.preferences.stealthModeEnabled), isOn: Binding(get: { app.preferences.stealthModeEnabled }, set: { app.preferences.stealthModeEnabled = $0 }))
        Text(CaptureExclusionService.status(enabled: app.preferences.stealthModeEnabled))
        Menu("Pacing mode") { ForEach(PacingMode.allCases) { mode in Button(mode.title) { app.handlePrompterAction(.pacing(mode)) } } }
        Menu("Speed preset") { ForEach(SpeedPreset.allCases) { preset in Button(preset.label) { app.handlePrompterAction(.speed(preset)) } } }
        Button("Quick Tour…") { openWindow(id: "workspace"); app.presentedSheet = .tour }
        Button("Terms of Service…") { openWindow(id: "workspace"); app.presentedSheet = .terms }
        if app.hotkeyWarning != nil { Button("Some shortcuts unavailable — Retry") { app.registerHotkeys() } }
        SettingsLink()
        Button("Quit Telex") { app.handlePrompterAction(.quit) }.keyboardShortcut("q")
    }
}
