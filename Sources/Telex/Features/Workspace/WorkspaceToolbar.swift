import SwiftUI

@MainActor struct WorkspaceToolbar: ToolbarContent {
    @Bindable var app: AppCoordinator
    private var playing: Bool { app.prompter.running && !app.prompter.manualPaused }
    private var playTitle: String { app.prompter.running ? (app.prompter.manualPaused ? "Paused · Resume" : "Playing · Pause") : "Start reading" }
    var body: some ToolbarContent {
        ToolbarItemGroup {
            if app.preferences.clickThroughEnabled { unlockButton }
            stealthButton
            recordButton
            visibilityButton
            playbackButton
            if app.prompter.running {
                Button { app.stop() } label: { Label("Stop", systemImage: "stop.fill") }
                    .labelStyle(.titleAndIcon).help("Stop reading and release the microphone").accessibilityLabel("Stop reading")
            }
        }
    }
    private var stealthButton: some View {
        let title = CaptureExclusionService.toggleLabel(enabled: app.preferences.stealthModeEnabled)
        let status = CaptureExclusionService.status(enabled: app.preferences.stealthModeEnabled)
        return Button { app.preferences.stealthModeEnabled.toggle() } label: { Label(title, systemImage: "shield.lefthalf.filled") }
            .labelStyle(.titleAndIcon).help(status + ". Click to toggle. " + CaptureExclusionService.guidance)
            .accessibilityLabel("Toggle Stealth Mode").accessibilityValue(status)
    }
    private var unlockButton: some View {
        Button { app.preferences.clickThroughEnabled = false } label: { Label("Click-through on · Unlock", systemImage: "cursorarrow.slash") }
            .labelStyle(.titleAndIcon).help("Turn off click-through (⇧⌘L)").accessibilityLabel("Click-through is on. Unlock prompter").tint(.orange)
    }
    private var recordButton: some View {
        let title = app.recorder.isRecording ? "Recording · Stop…" : "Record"
        return Button { app.handlePrompterAction(.record) } label: { Label(title, systemImage: app.recorder.isRecording ? "stop.circle.fill" : "record.circle") }
            .labelStyle(.titleAndIcon).help("Open screen recording controls").accessibilityLabel(app.recorder.isRecording ? "Recording in progress. Open stop controls" : "Record screen")
    }
    private var visibilityButton: some View {
        let title = app.window.visible ? "Hide prompter" : "Show prompter"
        return Button { app.handlePrompterAction(app.window.visible ? .hide : .show) } label: { Label(title, systemImage: "macwindow") }
            .labelStyle(.titleAndIcon).help(app.window.visible ? "Hide the prompter and stop reading (⇧⌘T)" : "Show camera prompter (⇧⌘T)")
            .accessibilityLabel(title)
    }
    private var playbackButton: some View {
        Button { app.playPause() } label: { Label(playTitle, systemImage: playing ? "pause.fill" : "play.fill") }
            .labelStyle(.titleAndIcon).help("Play or lock pause (⌘Return)").accessibilityLabel(playing ? "Reading. Pause playback" : "Resume or start reading")
            .accessibilityValue(app.prompter.status).buttonStyle(.borderedProminent).tint(DesignTokens.violet)
    }
}
