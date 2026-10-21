import SwiftUI
import UniformTypeIdentifiers

struct RecordingControlsView: View {
    @Bindable var app: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var targetID = ""
    @State private var mic = false
    @State private var system = false
    @State private var regionEnabled = false
    @State private var x = 0.0
    @State private var y = 0.0
    @State private var width = 1280.0
    @State private var height = 720.0
    @State private var localError: String?
    @State private var busy = false
    @State private var countdown = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Image(systemName: "record.circle").foregroundStyle(.red); Text("Record your next take").font(.title2.bold()); Spacer() }
            Text("Record your screen locally. An exclusion filter is configured for Telex; check a test recording before presenting.").foregroundStyle(.secondary)
            if app.recorder.isRecording {
                Label("Recording in progress", systemImage: "circle.fill").foregroundStyle(.red)
                Button("Stop & save recording") {
                    busy = true
                    Task { do { try await app.recorder.stop() } catch { localError = error.localizedDescription }; busy = false }
                }.buttonStyle(.borderedProminent)
            } else {
                Text("Screen recording permission is optional. Teleprompting and Stealth do not need screen access.").font(.caption).foregroundStyle(.secondary)
                Button("Choose screen or window…") {
                    guard app.permissions.requestScreenCapture() else { localError = "Screen recording is not enabled. Teleprompting still works without it."; return }
                    busy = true
                    Task { defer { busy = false }; do { try await app.recorder.refreshTargets() } catch { localError = error.localizedDescription } }
                }
                Picker("Source", selection: $targetID) { Text("Choose a display or window").tag(""); ForEach(app.recorder.targets) { target in Text(target.title).tag(target.id) } }.frame(maxWidth: .infinity)
                if app.recorder.targets.first(where: { $0.id == targetID })?.display != nil {
                    Toggle("Crop to region (display coordinates)", isOn: $regionEnabled)
                    if regionEnabled {
                        HStack {
                            TextField("X", value: $x, format: .number)
                            TextField("Y", value: $y, format: .number)
                            TextField("Width", value: $width, format: .number)
                            TextField("Height", value: $height, format: .number)
                        }.textFieldStyle(.roundedBorder)
                        Text("Origin is the top-left of the selected display, in points.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Toggle("Microphone", isOn: $mic)
                Toggle("System audio", isOn: $system)
                if countdown > 0 { Text("Starting in \(countdown)…").font(.title.monospacedDigit()) }
                Button("Choose file & start…") { chooseFile() }.buttonStyle(.borderedProminent).disabled(targetID.isEmpty || busy)
            }
            if let url = app.recorder.lastRecordingURL {
                Button("Reveal last recording in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
            if let localError { Text(localError).foregroundStyle(.orange).font(.caption).textSelection(.enabled) }
            if busy { ProgressView().controlSize(.small) }
            HStack { Button("Screen Recording Settings") { app.permissions.openSettings("Privacy_ScreenCapture") }; Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.cancelAction) }
        }.padding(28).frame(width: 560).disabled(app.recorder.isBusy)
        .interactiveDismissDisabled(busy)
    }
    func chooseFile() {
        guard let target = app.recorder.targets.first(where: { $0.id == targetID }) else { return }
        var region: CGRect?
        if regionEnabled, let display = target.display {
            let bounds = display.frame
            guard x.isFinite, y.isFinite, width.isFinite, height.isFinite, x >= 0, y >= 0, width >= 2, height >= 2, x + width <= bounds.width, y + height <= bounds.height else { localError = "The crop must fit inside the selected display."; return }
            region = CGRect(x: x, y: y, width: width, height: height)
        }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.mpeg4Movie, .quickTimeMovie]
        panel.nameFieldStringValue = "Telex-\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash)))\(Int(Date().timeIntervalSince1970)).mp4"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        busy = true; localError = nil
        Task {
            defer { busy = false; countdown = 0 }
            if mic {
                let granted = await app.permissions.requestMicrophone()
                if !granted { localError = TelexError.permissionDenied("Microphone").localizedDescription; return }
            }
            countdown = app.preferences.countdownSeconds
            while countdown > 0 {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                countdown -= 1
            }
            do { try await app.recorder.start(target: target, url: url, region: region, microphone: mic, systemAudio: system) }
            catch { localError = error.localizedDescription }
        }
    }
}
