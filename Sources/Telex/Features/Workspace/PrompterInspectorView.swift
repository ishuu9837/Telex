import SwiftUI

struct PrompterInspectorView: View {
    @Bindable var app: AppCoordinator
    @State private var testingMicrophone = false
    @State private var meterID = UUID()
    @State private var meterInViewport = false
    func pref<T>(_ key: WritableKeyPath<AppPreferences, T>) -> Binding<T> {
        Binding(get: { app.preferences[keyPath: key] }, set: { app.preferences[keyPath: key] = $0 })
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack { Text("MAKE IT YOURS").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(1.5); Spacer(); Image(systemName: "slider.horizontal.3") }.foregroundStyle(.secondary)
                preview
                section("PACING") {
                    Text("Telex microphone: \(app.microphoneActivity)").font(.caption2).foregroundStyle(.secondary)
                    Text("macOS shows a privacy indicator and the app name whenever the microphone is active.").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Picker("Pacing mode", selection: Binding(get: { app.preferences.pacingMode }, set: { app.setPacingMode($0) })) {
                        ForEach(PacingMode.allCases) { mode in Text(mode.title).tag(mode) }
                    }.accessibilityIdentifier("pacing.mode")
                    if !app.preferences.voicePacingEnabled {
                        Label("No microphone · continuous scrolling", systemImage: "mic.slash").font(.caption).foregroundStyle(.green)
                    }
                    Menu("Speed presets") {
                        ForEach(SpeedPreset.allCases) { preset in Button(preset.label) { app.preferences.scrollSpeedWPM = preset.rawValue } }
                    }.accessibilityIdentifier("pacing.presets")
                    valueSlider("Reading speed", value: Binding(get: { Double(app.preferences.scrollSpeedWPM) }, set: { app.preferences.scrollSpeedWPM = Int($0) }), range: 40...300, suffix: "WPM")
                        .disabled(app.preferences.voicePacingEnabled && app.prompter.usesWordTracking)
                    Text(app.preferences.voicePacingEnabled && app.prompter.usesWordTracking ? "Speed follows matched words; WPM is not used." : app.preferences.voicePacingEnabled ? "Target speed while your voice is detected. Silence pauses scrolling." : "Constant scrolling speed when voice following is off.")
                        .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    if app.preferences.voicePacingEnabled {
                        if app.preferences.wordTrackingEnabled {
                            Picker("Language", selection: pref(\.speechLocaleIdentifier)) {
                                if app.speechLanguages.isEmpty { Text("No on-device languages available").tag("") }
                                ForEach(app.speechLanguages) { language in Text(language.name).tag(language.id) }
                            }
                            .disabled(app.speechLanguages.isEmpty || app.speechPermissionDenied)
                            if let notice = app.speechNotice {
                                Text(notice).font(.caption2).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                            }
                            if app.speechPermissionDenied {
                                Button("Speech Recognition Settings") { app.permissions.openSettings("Privacy_SpeechRecognition") }
                            }
                            if !app.speechPermissionGranted && !app.speechPermissionDenied {
                                Text("Optional: Apple transcription requires Speech Recognition permission and may require Siri language assets. Voice-level pacing needs neither.").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                Button("Enable optional Apple transcription…") { Task { await app.enableOptionalTranscription() } }
                            }
                            Button("Refresh available languages") { app.refreshSpeechLanguages(); app.preferencesChanged() }.font(.caption2)
                            Text("Advances on matched script words. Repeats and ad-libs hold your place.").font(.caption2).foregroundStyle(.secondary)
                            if !app.prompter.transcriptPreview.isEmpty {
                                Text(app.prompter.transcriptPreview).font(.caption2).foregroundStyle(DesignTokens.periwinkle).lineLimit(3).accessibilityLabel("Live on-device transcript")
                            }
                        }
                        valueSlider("Mic sensitivity", value: pref(\.micSensitivityDB), range: -55 ... -15, suffix: "dB")
                        InputLevelMeter(levelDB: app.prompter.levelDB, active: app.audioDemand != .stopped)
                            .background(MeterViewportObserver { visible in
                                meterInViewport = visible; syncMeterVisibility()
                            })
                        Button(testingMicrophone ? "Stop microphone test" : "Test microphone") { testingMicrophone.toggle() }
                            .onChange(of: testingMicrophone) { _, _ in syncMeterVisibility() }
                        if testingMicrophone {
                            Text("Microphone test active — only while this control is visible.").font(.caption2).foregroundStyle(.orange)
                                .onAppear { syncMeterVisibility() }
                                .onDisappear { app.setMeterVisible(meterID, visible: false) }
                        }
                        Text(app.prompter.status).font(.caption2).foregroundStyle(.secondary)
                        Button("Adjust sensitivity from my voice") { app.calibrateSensitivityFromVoice() }.disabled(app.audioDemand == .stopped)
                            .help("Speak normally, then click to place the threshold 8 dB below your current input level.")
                        if app.prompter.running && !app.prompter.speaking && app.prompter.levelDB > -70 && app.prompter.levelDB < app.preferences.micSensitivityDB {
                            Text("Input is below the sensitivity threshold. Speak and adjust sensitivity, or choose No microphone.").font(.caption2).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                        }
                        valueSlider("Silence hold", value: Binding(get: { Double(app.preferences.silenceHoldMs) }, set: { app.preferences.silenceHoldMs = Int($0) }), range: 150...1000, suffix: "ms")
                    }
                    Picker("Countdown", selection: pref(\.countdownSeconds)) { Text("Off").tag(0); Text("3s").tag(3); Text("5s").tag(5); Text("10s").tag(10) }.font(.caption)
                }
                section("TYPE & COLOR") {
                    valueSlider("Font size", value: pref(\.fontSizePt), range: 14...42, suffix: "pt")
                    valueSlider("Line spacing", value: pref(\.lineSpacingMultiplier), range: 1.2...1.8, suffix: "×", decimals: 2)
                    HStack(spacing: 9) {
                        ForEach(DesignTokens.presets, id: \.self) { hex in
                            Button { app.preferences.scriptTextColorHex = hex } label: {
                                Circle().fill(Color(hex: hex)).frame(width: 22, height: 22)
                                    .overlay(Circle().stroke(.white, lineWidth: app.preferences.scriptTextColorHex == hex ? 2 : 0).padding(-3))
                            }.buttonStyle(.plain)
                            .help(DesignTokens.colorName(hex))
                            .accessibilityLabel(DesignTokens.colorName(hex))
                            .accessibilityValue(app.preferences.scriptTextColorHex == hex ? "Selected" : "Not selected")
                        }
                    }.padding(.vertical, 5)
                    ColorPicker("Custom color", selection: Binding(get: { Color(hex: app.preferences.scriptTextColorHex) }, set: { app.preferences.scriptTextColorHex = $0.hexString }), supportsOpacity: false)
                    Toggle("Reading band", isOn: pref(\.readingBandEnabled))
                    Toggle("Blue bubble glow", isOn: pref(\.voiceBeamEnabled))
                        .help("Responds to your voice, or gently animates during no-microphone playback. Reduce Motion keeps it still.")
                }
                section("POSITION & SIZE") {
                    Picker("Display", selection: Binding(get: { app.window.selectedDisplayID }, set: { app.window.selectedDisplayID = $0; app.window.layout() })) {
                        Text("Main display").tag("")
                        ForEach(NSScreen.screens, id: \.localizedName) { screen in Text(screen.localizedName).tag(DisplayGeometryService.id(for: screen)) }
                    }
                    Button(app.prompter.floating ? "Dock at camera" : "Detach floating window") { app.window.toggleDock() }
                    valueSlider("Width", value: Binding(get: { app.prompter.panelWidth }, set: { app.window.setSize(width: $0) }), range: 210...840, suffix: "pt")
                    valueSlider("Height", value: Binding(get: { app.prompter.panelHeight }, set: { app.window.setSize(height: $0) }), range: 76...520, suffix: "pt")
                    Toggle("Mirror horizontally", isOn: pref(\.mirrorHorizontally))
                    Toggle("Mirror vertically", isOn: pref(\.mirrorVertically))
                    Toggle("Pause on hover", isOn: pref(\.hoverToPauseEnabled))
                    Toggle("Click-through", isOn: pref(\.clickThroughEnabled)).help("Use ⇧⌘L or the menu bar to unlock")
                    if app.preferences.clickThroughEnabled {
                        Label("Click-through on · ⇧⌘L to unlock", systemImage: "cursorarrow.slash").font(.caption).foregroundStyle(.orange)
                        Button("Turn off click-through") { app.preferences.clickThroughEnabled = false }
                    }
                }
                if let warning = app.hotkeyWarning {
                    section("SHORTCUT WARNING") {
                        Text(warning).font(.caption2).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                        Button("Retry global shortcuts") { app.registerHotkeys() }
                    }
                }
                section("SCREEN SHARING") {
                    if app.audioDemand != .stopped || app.recorder.microphoneActive {
                        Label("Microphone privacy indicator cannot be hidden", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                        Text("macOS identifies Telex while its microphone is active. Stealth does not hide this. Choose No microphone to scroll without prompting microphone use.").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Toggle("Stealth mode", isOn: pref(\.stealthModeEnabled))
                    Text(CaptureExclusionService.status(enabled: app.preferences.stealthModeEnabled)).font(.caption).foregroundStyle(.orange)
                    Text(CaptureExclusionService.guidance).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }.font(.system(size: 12)).padding(20)
        }.background(Color(hex: "#1B1B22"))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in testingMicrophone = false; app.setMeterVisible(meterID, visible: false) }
        .onChange(of: app.preferences.voicePacingEnabled) { _, enabled in if !enabled { testingMicrophone = false; app.setMeterVisible(meterID, visible: false) } }
        .onDisappear { testingMicrophone = false; app.setMeterVisible(meterID, visible: false) }
    }
    private func syncMeterVisibility() {
        app.setMeterVisible(meterID, visible: testingMicrophone && meterInViewport)
    }
    var preview: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Rectangle().fill(.black)
                VoiceBeamVisualView(intensity: 0.7).scaleEffect(0.6).frame(height: 50).clipped()
                VStack(spacing: 6) {
                    Text("Speak naturally").opacity(0.38)
                    Text("to the camera.")
                    Text("Find your flow.")
                }.font(.system(size: 14, weight: .medium, design: .monospaced)).foregroundStyle(Color(hex: app.preferences.scriptTextColorHex)).padding(20)
            }.frame(height: 108)
            Text("A little closer to your audience.").font(.caption2).foregroundStyle(.secondary).padding(.top, 12)
        }.accessibilityLabel("Prompter appearance preview")
    }
    func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.2).foregroundStyle(DesignTokens.periwinkle)
            content()
        }
    }
    func valueSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String, decimals: Int = 0) -> some View {
        VStack(spacing: 7) {
            HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text("\(value.wrappedValue.formatted(.number.precision(.fractionLength(decimals)))) \(suffix)").monospacedDigit() }
            Slider(value: value, in: range).controlSize(.small).accessibilityLabel(title)
        }
    }
}

/// Observe AppKit clipping without writing SwiftUI state from a geometry action.
/// Delivery is coalesced onto the next run-loop turn and only reports transitions.
private struct MeterViewportObserver: NSViewRepresentable {
    var changed: (Bool) -> Void
    func makeNSView(context: Context) -> MeterViewportView { MeterViewportView(changed: changed) }
    func updateNSView(_ view: MeterViewportView, context: Context) { view.changed = changed; view.scheduleCheck() }
    static func dismantleNSView(_ view: MeterViewportView, coordinator: ()) { view.detach() }
}

@MainActor final class MeterViewportView: NSView {
    var changed: (Bool) -> Void
    private var pending = false
    private var lastVisible = false
    private var attached = true
    private var observers: [NSObjectProtocol] = []
    init(changed: @escaping (Bool) -> Void) { self.changed = changed; super.init(frame: .zero) }
    required init?(coder: NSCoder) { nil }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); observeViewport() }
    override func viewDidMoveToSuperview() { super.viewDidMoveToSuperview(); observeViewport() }
    override func layout() { super.layout(); scheduleCheck() }
    private func observeViewport() {
        removeObservers()
        attached = true
        let center = NotificationCenter.default
        // SwiftUI can attach/reparent its scroll view after this view enters a window.
        // Observe clip changes without caching an ancestor that can become stale.
        observers.append(center.addObserver(forName: NSView.boundsDidChangeNotification, object: nil, queue: .main) { [weak self] notification in
            guard notification.object is NSClipView else { return }
            MainActor.assumeIsolated { self?.scheduleCheck() }
        })
        enclosingScrollView?.contentView.postsBoundsChangedNotifications = true
        if let window {
            for name in [NSWindow.didResizeNotification, NSWindow.didMiniaturizeNotification, NSWindow.didDeminiaturizeNotification, NSWindow.didChangeOcclusionStateNotification] {
                observers.append(center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.scheduleCheck() }
                })
            }
        }
        scheduleCheck()
    }
    func scheduleCheck() {
        guard attached, !pending else { return }
        pending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pending = false
            guard self.attached else { return }
            self.enclosingScrollView?.contentView.postsBoundsChangedNotifications = true
            let visible = self.window?.isVisible == true && !self.isHiddenOrHasHiddenAncestor && self.visibleRect.intersection(self.bounds).height >= 10
            guard visible != self.lastVisible else { return }
            self.lastVisible = visible
            self.changed(visible)
        }
    }
    private func removeObservers() { observers.forEach(NotificationCenter.default.removeObserver); observers.removeAll() }
    func detach() {
        attached = false; removeObservers()
        if lastVisible { lastVisible = false; let notify = changed; DispatchQueue.main.async { notify(false) } }
    }
}
