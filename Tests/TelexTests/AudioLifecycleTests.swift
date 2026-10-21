import XCTest
import AVFoundation
import AppKit
@testable import Telex

@MainActor private final class TestVoiceService: VoicePacingServiceProtocol {
    var isRunning = false
    var onFailure: (@MainActor (String) -> Void)?
    var starts: [String?] = []
    var onEvent: (@MainActor @Sendable (VoicePacingEvent) -> Void)?
    func start(threshold: Double, holdMs: Int, speechLocale: String?, onTranscript: @escaping @MainActor @Sendable (String) -> Void, onSessionStarted: @escaping @MainActor @Sendable () -> Void, onEvent: @escaping @MainActor @Sendable (VoicePacingEvent) -> Void) throws {
        starts.append(speechLocale); isRunning = true; self.onEvent = onEvent
    }
    func stop() { isRunning = false; onEvent = nil }
}
@MainActor private final class TestPermissions: PermissionServiceProtocol {
    var speechDenied = false
    var speechGranted: Bool { speechAllowed && !speechDenied }
    var speechAllowed = true
    var micAllowed = true
    var delayMicrophone = false
    var microphoneReply: CheckedContinuation<Bool, Never>?
    var microphoneRequests = 0
    var speechRequests = 0
    func requestMicrophone() async -> Bool {
        microphoneRequests += 1
        if delayMicrophone { return await withCheckedContinuation { microphoneReply = $0 } }
        return micAllowed
    }
    func requestSpeechRecognition() async -> Bool { speechRequests += 1; return speechAllowed }
    func requestScreenCapture() -> Bool { false }
    func openSettings(_ pane: String) {}
}

final class AudioLifecycleTests: XCTestCase {
    func testAudioDemandStopsInEditorDuringPauseCountdownAndHiddenPanel() {
        let demand = AudioSessionPolicy.demand
        XCTAssertEqual(demand(false, false, 0, true, true, false, false), .stopped)
        XCTAssertEqual(demand(true, true, 0, true, true, false, false), .stopped)
        XCTAssertEqual(demand(true, false, 3, true, true, false, false), .stopped)
        XCTAssertEqual(demand(true, false, 0, false, true, false, false), .stopped)
        XCTAssertEqual(demand(true, false, 0, true, false, false, false), .stopped)
        XCTAssertEqual(demand(false, false, 0, false, false, false, true), .meter)
        XCTAssertEqual(demand(true, false, 0, true, true, false, false), .voiceLevel)
        XCTAssertEqual(demand(true, false, 0, true, true, true, false), .scriptWords)
    }
    @MainActor func testEditingDoesNotRequestMicrophoneAndMeterReleaseStopsIt() async {
        let voice = TestVoiceService(); let permissions = TestPermissions()
        let app = AppCoordinator(voice: voice, permissions: permissions)
        app.reconcileAudio()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(permissions.microphoneRequests, 0)
        let meter = UUID(); app.setMeterVisible(meter, visible: true)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertTrue(voice.isRunning); XCTAssertEqual(app.audioDemand, .meter)
        XCTAssertEqual(permissions.speechRequests, 0)
        app.setMeterVisible(meter, visible: false)
        XCTAssertFalse(voice.isRunning); XCTAssertEqual(app.audioDemand, .stopped)
    }
    @MainActor func testSpeechPermissionDenialFallsBackToLevelWithoutStoppingReading() async {
        let voice = TestVoiceService(); let permissions = TestPermissions(); permissions.speechAllowed = false; permissions.speechDenied = true
        let app = AppCoordinator(voice: voice, permissions: permissions)
        app.speechLanguages = [SpeechLanguage(id: "en-US", name: "English")]
        app.prompter.preferences.wordTrackingEnabled = true
        app.prompter.preferences.countdownSeconds = 0
        app.window.show(); app.prompter.start()
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(app.audioDemand, .voiceLevel)
        XCTAssertTrue(app.prompter.running); XCTAssertTrue(voice.isRunning)
        XCTAssertTrue(app.speechNotice?.contains("denied") == true)
        XCTAssertEqual(permissions.speechRequests, 0)
        XCTAssertEqual(voice.starts.count, 1); XCTAssertNil(voice.starts.first ?? "unexpected")
        app.prompter.hovering = true
        XCTAssertFalse(voice.isRunning)
        app.prompter.hovering = false
        for _ in 0..<30 { await Task.yield() }
        XCTAssertTrue(voice.isRunning)
        app.prompter.manualPaused = true
        XCTAssertFalse(voice.isRunning); XCTAssertEqual(app.audioDemand, .stopped)
        app.window.hide()
    }
    @MainActor func testUnavailableLanguagesFallBackWithoutRequestingSpeechPermission() async {
        let voice = TestVoiceService(); let permissions = TestPermissions()
        let app = AppCoordinator(voice: voice, permissions: permissions)
        app.prompter.preferences.wordTrackingEnabled = true; app.prompter.preferences.countdownSeconds = 0
        app.window.show(); app.prompter.start()
        for _ in 0..<40 { await Task.yield() }
        XCTAssertEqual(app.audioDemand, .voiceLevel); XCTAssertEqual(permissions.speechRequests, 0)
        XCTAssertTrue(app.speechNotice?.contains("No on-device") == true)
        app.beginEditing(); XCTAssertFalse(voice.isRunning); XCTAssertFalse(app.window.visible)
    }
    @MainActor func testPermissionReplyAfterMeterHidesCannotOpenMicrophone() async {
        let voice = TestVoiceService(); let permissions = TestPermissions(); permissions.delayMicrophone = true
        let app = AppCoordinator(voice: voice, permissions: permissions)
        let id = UUID(); app.setMeterVisible(id, visible: true)
        for _ in 0..<30 { await Task.yield() }
        XCTAssertNotNil(permissions.microphoneReply)
        app.setMeterVisible(id, visible: false)
        permissions.microphoneReply?.resume(returning: true); permissions.microphoneReply = nil
        for _ in 0..<30 { await Task.yield() }
        XCTAssertFalse(voice.isRunning); XCTAssertTrue(voice.starts.isEmpty)
    }
    @MainActor func testWordFollowingNeverPromptsForAppleSpeechDuringPlayback() async {
        let voice = TestVoiceService(); let permissions = TestPermissions(); permissions.speechAllowed = false
        let app = AppCoordinator(voice: voice, permissions: permissions)
        app.speechLanguages = [SpeechLanguage(id: "en-US", name: "English")]
        app.prompter.preferences.wordTrackingEnabled = true; app.prompter.preferences.countdownSeconds = 0
        app.window.show(); app.prompter.start()
        for _ in 0..<30 { await Task.yield() }
        XCTAssertEqual(permissions.speechRequests, 0)
        XCTAssertEqual(app.audioDemand, .voiceLevel)
        XCTAssertTrue(app.speechNotice?.contains("not enabled") == true)
        app.beginEditing()
    }
    @MainActor func testRecognitionRuntimeFailureFallsBackAndHiddenPanelReleasesMicrophone() async {
        let voice = TestVoiceService(); let permissions = TestPermissions()
        let app = AppCoordinator(voice: voice, permissions: permissions)
        app.speechLanguages = [SpeechLanguage(id: "en-US", name: "English")]
        app.prompter.preferences.wordTrackingEnabled = true; app.prompter.preferences.countdownSeconds = 0
        app.window.show(); app.prompter.start()
        for _ in 0..<30 { await Task.yield() }
        XCTAssertEqual(app.audioDemand, .scriptWords)
        voice.onFailure?("Speech assets unavailable")
        for _ in 0..<30 { await Task.yield() }
        XCTAssertEqual(app.audioDemand, .voiceLevel); XCTAssertTrue(app.prompter.running)
        XCTAssertTrue(app.speechNotice?.contains("Using voice-level pacing instead") == true)
        app.window.hide()
        XCTAssertFalse(voice.isRunning); XCTAssertFalse(app.prompter.running)
    }
    func testInputMeterRespondsToRealPCMLevels() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)); buffer.frameLength = 1024
        let samples = try XCTUnwrap(buffer.floatChannelData?[0])
        let filter = VoiceFilter(threshold: -38, holdMs: 350, speechRequest: nil)
        for i in 0..<1024 { samples[i] = 0 }
        let silent = try XCTUnwrap(filter.process(buffer))
        for i in 0..<1024 { samples[i] = 0.2 * sin(Float(i) * 2 * .pi * 440 / 48000) }
        let speaking = try XCTUnwrap(filter.process(buffer))
        XCTAssertGreaterThan(speaking.levelDB, silent.levelDB + 40)
        XCTAssertGreaterThan(speaking.intensity, silent.intensity)
        XCTAssertTrue(speaking.speaking)
        XCTAssertEqual(samples[17], 0.2 * sin(Float(17) * 2 * .pi * 440 / 48000), accuracy: 0.00001)
    }
    func testSystemLanguageCanonicalSelectionAndFallback() {
        let languages = [SpeechLanguage(id: "en-US", name: "English (US)"), SpeechLanguage(id: "hi-IN", name: "Hindi"), SpeechLanguage(id: "en-IN", name: "English (India)")]
        XCTAssertEqual(SpeechLanguage.preferred(requested: "en_IN", system: ["hi-IN"], available: languages), "en-IN")
        XCTAssertEqual(SpeechLanguage.preferred(requested: "missing", system: ["hi-IN"], available: languages), "hi-IN")
        XCTAssertEqual(SpeechLanguage.preferred(requested: "missing", system: ["en-GB"], available: languages), "en-US")
        XCTAssertNil(SpeechLanguage.preferred(requested: "en-IN", system: ["en-IN"], available: []))
    }
    @MainActor func testStealthLimitedForEveryNewerMacOSAndCanBeTurnedOff() {
        for version in [15, 16, 26, 27, 99] {
            XCTAssertTrue(CaptureExclusionService.status(enabled: true, majorVersion: version).contains("15 or later"))
            XCTAssertEqual(CaptureExclusionService.toggleLabel(enabled: true, majorVersion: version), "Stealth: Limited")
        }
        let panel = NSPanel()
        CaptureExclusionService().apply(to: panel, enabled: true); XCTAssertEqual(panel.sharingType, .none)
        CaptureExclusionService().apply(to: panel, enabled: false); XCTAssertEqual(panel.sharingType, .readOnly)
    }
}

final class MeterViewportTests: XCTestCase {
    @MainActor func testScrollingMeterOutOfViewportReleasesVisibilityAndDetachStopsNotifications() async {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 200, height: 100), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        let document = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 400))
        var visibility: [Bool] = []
        let meter = MeterViewportView { visibility.append($0) }
        meter.frame = NSRect(x: 0, y: 0, width: 180, height: 20)
        document.addSubview(meter); scroll.documentView = document; window.contentView = scroll
        window.orderFront(nil)
        defer { meter.detach(); window.close() }
        scroll.contentView.scroll(to: .zero); meter.scheduleCheck()
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(visibility.last, true)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 200)); scroll.reflectScrolledClipView(scroll.contentView)
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(visibility.last, false, "clip=\(scroll.contentView.bounds), meter=\(meter.visibleRect), posts=\(scroll.contentView.postsBoundsChangedNotifications), ancestor=\(meter.enclosingScrollView != nil)")
        scroll.contentView.scroll(to: .zero); scroll.reflectScrolledClipView(scroll.contentView)
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(visibility.last, true)
        meter.detach()
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(visibility.last, false)
        let count = visibility.count
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 200)); meter.scheduleCheck()
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(visibility.count, count)
    }
}
