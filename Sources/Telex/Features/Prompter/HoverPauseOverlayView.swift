import SwiftUI

struct HoverPauseOverlayView: View {
    @Bindable var model: PrompterViewModel
    var window: WeakPrompterWindow
    private func actionButton(_ title: String, icon: String, id: String, action: PrompterAction) -> some View {
        Button { window.onAction?(action) } label: { Image(systemName: icon).frame(width: 24, height: 25).contentShape(Rectangle()) }
            .buttonStyle(.borderless).help(title).accessibilityLabel(title).accessibilityIdentifier(id)
    }
    var body: some View {
        VStack(spacing: 3) {
            if model.hovering && model.running && !model.manualPaused {
                Text("Hover pause · move pointer away to read").font(.system(size: 9)).foregroundStyle(.secondary).frame(width: min(180, model.panelWidth - 30)).lineLimit(1).minimumScaleFactor(0.7)
            }
            HStack(spacing: 3) {
            actionButton(model.manualPaused || !model.running ? "Play or resume" : "Lock pause", icon: model.manualPaused || !model.running ? "play.fill" : "pause.fill", id: "prompter.playPause", action: .playPause)
            Menu {
                ForEach(model.script.cues) { cue in Button(cue.title) { window.onAction?(.jumpToCue(cue.id)) } }
                Button("Back to previous spot") { window.onAction?(.returnToSpot) }.disabled(model.cueService.returnPositionStack.isEmpty)
                Divider()
                Button("Restart from beginning") { window.onAction?(.restart) }
            } label: { Image(systemName: "list.bullet").frame(width: 22, height: 25) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Cues and reading position").accessibilityIdentifier("prompter.cues")
            Menu {
                ForEach(PacingMode.allCases) { mode in Button(mode.title) { window.onAction?(.pacing(mode)) } }
                Divider()
                ForEach(SpeedPreset.allCases) { preset in Button(preset.label) { window.onAction?(.speed(preset)) } }
                Divider()
                Button("Slower (−10 WPM)") { window.onAction?(.slower) }
                Button("Faster (+10 WPM)") { window.onAction?(.faster) }
            } label: { Text("\(model.preferences.scrollSpeedWPM)").font(.system(size: 10, design: .monospaced)).frame(height: 25) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Pacing mode and six speed presets").accessibilityLabel("Speed and microphone mode").accessibilityIdentifier("prompter.speed")
            actionButton("Dock or float", icon: model.floating ? "pin" : "arrow.up.left.and.arrow.down.right", id: "prompter.dock", action: .toggleDock)
            Menu {
                Button("Recording controls…") { window.onAction?(.record) }
                Button("Open workspace") { window.onAction?(.workspace) }
                Button("Stop reading") { window.onAction?(.stop) }
                Button("Hide prompter") { window.onAction?(.hide) }
            } label: { Image(systemName: "ellipsis").frame(width: 20, height: 25) }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Recording, workspace and stop").accessibilityIdentifier("prompter.more")
            actionButton("Quit Telex", icon: "power", id: "prompter.quit", action: .quit)
        }
            }
        .font(.system(size: 12)).foregroundStyle(.white)
        .padding(.horizontal, 8).padding(.vertical, 3).background(.black.opacity(0.96), in: RoundedRectangle(cornerRadius: 9))
        .fixedSize().accessibilityElement(children: .contain)
    }
}
