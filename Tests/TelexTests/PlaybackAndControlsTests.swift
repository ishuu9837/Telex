import XCTest
import AppKit
@testable import Telex

@MainActor private final class SilentPermissions: PermissionServiceProtocol {
    var speechDenied = true
    var speechGranted = false
    var microphoneRequests = 0
    var speechRequests = 0
    var screenRequests = 0
    func requestMicrophone() async -> Bool { microphoneRequests += 1; return false }
    func requestSpeechRecognition() async -> Bool { speechRequests += 1; return false }
    func requestScreenCapture() -> Bool { screenRequests += 1; return false }
    func openSettings(_ pane: String) {}
}

@MainActor private final class ConflictingHotkeys: GlobalHotkeyServiceProtocol {
    var onAction: ((UInt32) -> Void)?
    func register() throws { throw TelexError.hotkeyConflict("Test shortcut") }
    func unregister() {}
}

final class PlaybackAndControlsTests: XCTestCase {
    @MainActor private func makeApp(accepted: Bool = true) throws -> (AppCoordinator, SilentPermissions, UserDefaults, String) {
        let name = "TelexControlTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let permissions = SilentPermissions()
        let app = AppCoordinator(permissions: permissions, preferencesStore: PreferencesStore(defaults: defaults), repository: ScriptRepository(directory: FileManager.default.temporaryDirectory.appendingPathComponent(name)), surfaceProvider: { DisplaySurface(id: "test-display", metrics: DisplayMetrics(frame: CGRect(x: 0, y: 0, width: 1512, height: 982), visibleFrame: CGRect(x: 0, y: 40, width: 1512, height: 904), safeTop: 38, notchWidth: 204)) })
        app.prompter.preferences.acceptedTermsVersion = accepted ? AppTerms.version : nil
        app.prompter.preferences.countdownSeconds = 0
        app.prompter.preferences.voicePacingEnabled = false
        let script = ScriptDocument.welcome
        app.scripts = [script]; app.select(script.id)
        return (app, permissions, defaults, name)
    }
    @MainActor func testSpeechArrivalAfterLongSilenceAdvancesAndSilenceHolds() {
        let model = PrompterViewModel(); model.rebuildLines()
        model.preferences.wordTrackingEnabled = false; model.preferences.countdownSeconds = 0
        model.start()
        let start = Date(timeIntervalSince1970: 1000)
        model.tick(start); model.tick(start.addingTimeInterval(2))
        XCTAssertEqual(model.offset, 0)
        model.speaking = true
        model.tick(start.addingTimeInterval(2.016)); model.tick(start.addingTimeInterval(2.032))
        XCTAssertGreaterThan(model.offset, 0)
        let position = model.offset
        model.speaking = false; model.tick(start.addingTimeInterval(4))
        XCTAssertEqual(model.offset, position)
        model.speaking = true; model.tick(start.addingTimeInterval(4.016))
        XCTAssertGreaterThan(model.offset, position)
        model.stop()
    }
    @MainActor func testAllSixNoMicSpeedsAdvanceAtIncreasingRates() {
        var previous = -1.0
        for preset in SpeedPreset.allCases {
            let model = PrompterViewModel(); model.rebuildLines()
            model.preferences.pacingMode = .noMicrophone; model.preferences.scrollSpeedWPM = preset.rawValue; model.preferences.countdownSeconds = 0
            model.start()
            let start = Date(timeIntervalSince1970: 1000)
            model.tick(start)
            for frame in 1...60 { model.tick(start.addingTimeInterval(Double(frame) / 60)) }
            XCTAssertGreaterThan(model.offset, previous); XCTAssertGreaterThan(model.offset, 0)
            previous = model.offset; model.stop()
        }
        XCTAssertEqual(SpeedPreset.allCases.map(\.title), ["Very slow", "Slow", "Medium", "Medium fast", "High", "Very high"])
    }
    @MainActor func testSingleLineScriptScrollsAndReleasesReadingAtEnd() {
        let model = PrompterViewModel(); model.script = ScriptDocument(title: "Short", body: "Hello world")
        model.preferences.pacingMode = .noMicrophone; model.preferences.countdownSeconds = 0; model.preferences.scrollSpeedWPM = 300
        model.rebuildLines(); model.start()
        let start = Date(timeIntervalSince1970: 1000); model.tick(start)
        for frame in 1...120 { model.tick(start.addingTimeInterval(Double(frame) / 60)) }
        XCTAssertGreaterThan(model.offset, 0); XCTAssertFalse(model.running)
    }
    @MainActor func testFinalMatchedWordEndsWordFollowingSession() {
        let model = PrompterViewModel(); model.script = ScriptDocument(title: "Short", body: "Hello world")
        model.preferences.pacingMode = .scriptWords; model.preferences.countdownSeconds = 0
        model.rebuildLines(); model.start(); model.receiveTranscript("Hello world")
        let start = Date(timeIntervalSince1970: 1000); model.tick(start)
        for frame in 1...240 { model.tick(start.addingTimeInterval(Double(frame) / 60)) }
        XCTAssertGreaterThan(model.offset, 0); XCTAssertFalse(model.running)
    }
    @MainActor func testActualPlaybackClockAdvancesAndStopsWithoutTimelineView() async throws {
        let model = PrompterViewModel(); model.rebuildLines(); model.preferences.pacingMode = .noMicrophone; model.preferences.countdownSeconds = 0
        model.start(); let clock = PrompterPlaybackClock(model: model); clock.setRunning(true)
        try await Task.sleep(for: .milliseconds(120))
        XCTAssertGreaterThan(model.offset, 0)
        clock.stop(); let position = model.offset
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(model.offset, position); model.stop()
    }
    @MainActor func testPlayPauseHideStopRestartSpeedAndDockActions() throws {
        let (app, permissions, defaults, name) = try makeApp(); defer { app.stop(); defaults.removePersistentDomain(forName: name) }
        XCTAssertNotNil(app.window.onAction)
        app.window.onAction?(.playPause); XCTAssertTrue(app.prompter.running); XCTAssertTrue(app.window.visible)
        XCTAssertTrue(app.window.panel?.canBecomeKey == true)
        XCTAssertTrue(app.window.panel?.contentView?.acceptsFirstMouse(for: nil) == true)
        XCTAssertFalse(app.window.panel?.isMovableByWindowBackground == true)
        app.window.onAction?(.playPause); XCTAssertTrue(app.prompter.manualPaused)
        app.window.onAction?(.playPause); XCTAssertFalse(app.prompter.manualPaused)
        for preset in SpeedPreset.allCases { app.window.onAction?(.speed(preset)); XCTAssertEqual(app.preferences.scrollSpeedWPM, preset.rawValue) }
        app.window.onAction?(.speed(.medium)); app.window.onAction?(.faster); XCTAssertEqual(app.preferences.scrollSpeedWPM, 140)
        app.window.onAction?(.slower); XCTAssertEqual(app.preferences.scrollSpeedWPM, 130)
        app.prompter.move(to: 25); app.window.onAction?(.restart); XCTAssertEqual(app.prompter.offset, 0)
        let floating = app.prompter.floating; app.window.onAction?(.toggleDock); XCTAssertNotEqual(app.prompter.floating, floating, "Saved geometry: \(app.preferences.displayGeometries), selected display: \(app.window.selectedDisplayID), actual display: \(app.window.screen.map { DisplayGeometryService.id(for: $0) } ?? "none")")
        app.window.onAction?(.hide); XCTAssertFalse(app.window.visible); XCTAssertFalse(app.prompter.running)
        app.window.onAction?(.playPause); app.window.onAction?(.stop); XCTAssertFalse(app.prompter.running)
        XCTAssertEqual(permissions.microphoneRequests, 0); XCTAssertEqual(permissions.speechRequests, 0); XCTAssertEqual(permissions.screenRequests, 0)
    }
    @MainActor func testCueBackWorkspaceRecordAndQuitActions() throws {
        let (app, permissions, defaults, name) = try makeApp(); defer { app.stop(); defaults.removePersistentDomain(forName: name) }
        app.draft.cues = TelexCueService.parse(app.draft.body); app.prompter.script = app.draft; app.prompter.rebuildLines()
        app.prompter.move(to: 20)
        let cue = try XCTUnwrap(app.draft.cues.last)
        app.window.onAction?(.jumpToCue(cue.id)); XCTAssertGreaterThan(app.prompter.offset, 20)
        app.window.onAction?(.returnToSpot); XCTAssertEqual(app.prompter.offset, 20)
        var workspaceRequests = 0; app.openWorkspace = { workspaceRequests += 1 }
        app.window.onAction?(.workspace); XCTAssertEqual(workspaceRequests, 1)
        app.window.onAction?(.record); XCTAssertEqual(app.presentedSheet, .recording); XCTAssertEqual(permissions.screenRequests, 0)
        var quitRequested = false; app.quitApplication = { quitRequested = true }
        app.window.onAction?(.quit); XCTAssertTrue(quitRequested); XCTAssertFalse(app.prompter.running)
    }
    @MainActor func testInspectorSettingsApplyToNativePanelAndSpeedBounds() async throws {
        let (app, _, defaults, name) = try makeApp(); defer { app.window.invalidate(); defaults.removePersistentDomain(forName: name) }
        app.window.show()
        app.preferences.clickThroughEnabled = true; XCTAssertTrue(app.window.panel?.ignoresMouseEvents == true)
        app.preferences.clickThroughEnabled = false; XCTAssertFalse(app.window.panel?.ignoresMouseEvents == true)
        app.preferences.stealthModeEnabled = true; XCTAssertEqual(app.window.panel?.sharingType, NSWindow.SharingType.none)
        app.preferences.stealthModeEnabled = false
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertFalse(app.preferences.stealthModeEnabled)
        XCTAssertEqual(app.window.panel?.sharingType, .readOnly, "Actual sharing type: \(app.window.panel?.sharingType.rawValue ?? 999), requested Stealth: \(app.preferences.stealthModeEnabled)")
        app.window.setSize(width: 390, height: 200)
        XCTAssertEqual(app.prompter.panelWidth, 390); XCTAssertEqual(app.prompter.panelHeight, 200)
        app.preferences.mirrorHorizontally = true; app.preferences.mirrorVertically = true
        XCTAssertTrue(app.prompter.preferences.mirrorHorizontally); XCTAssertTrue(app.prompter.preferences.mirrorVertically)
        app.handlePrompterAction(.speed(.verySlow)); app.handlePrompterAction(.slower); XCTAssertEqual(app.preferences.scrollSpeedWPM, 40)
        app.handlePrompterAction(.speed(.veryHigh)); app.handlePrompterAction(.faster); XCTAssertEqual(app.preferences.scrollSpeedWPM, 300)
    }
    @MainActor func testScriptEditorCreateRenameDuplicatePinSearchAndDelete() async throws {
        let (app, _, defaults, name) = try makeApp()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        defer { app.stop(); defaults.removePersistentDomain(forName: name); try? FileManager.default.removeItem(at: directory) }
        app.create(); app.draft.title = "Demo Script"; app.draft.body = "# Intro\nA local script"; app.draft.tags = ["practice"]; app.draft.isPinned = true; app.edited()
        await app.flush(); XCTAssertEqual(app.saveStatus, "All changes saved")
        XCTAssertEqual(app.draft.cues.first?.title, "Intro")
        app.search = "practice"; XCTAssertEqual(app.filteredScripts.count, 1)
        app.search = ""; let before = app.scripts.count
        app.duplicate(); XCTAssertEqual(app.scripts.count, before + 1); XCTAssertTrue(app.draft.title.hasSuffix("copy"))
        await app.flush(); await app.deleteSelected(); XCTAssertEqual(app.scripts.count, before)
    }
    @MainActor func testShortcutConflictDoesNotBlockButtonsWithAnAlert() {
        let app = AppCoordinator(permissions: SilentPermissions(), hotkeys: ConflictingHotkeys())
        app.registerHotkeys()
        XCTAssertNotNil(app.hotkeyWarning); XCTAssertNil(app.errorMessage)
        XCTAssertTrue(app.hotkeyWarning?.contains("Other buttons still work") == true)
    }
    @MainActor func testTermsBlockPlaybackAndNeverAgreeAutomatically() throws {
        let (app, permissions, defaults, name) = try makeApp(accepted: false); defer { app.stop(); defaults.removePersistentDomain(forName: name) }
        app.window.onAction?(.playPause)
        XCTAssertFalse(app.prompter.running); XCTAssertEqual(app.presentedSheet, .terms)
        XCTAssertNil(app.preferences.acceptedTermsVersion); XCTAssertEqual(permissions.microphoneRequests, 0)
        app.acceptTerms()
        XCTAssertEqual(app.preferences.acceptedTermsVersion, AppTerms.version); XCTAssertNotNil(app.preferences.acceptedTermsAt)
        XCTAssertEqual(PreferencesStore(defaults: defaults).load().acceptedTermsVersion, AppTerms.version)
    }
    @MainActor func testIntroAndTourNeverStartMicrophone() throws {
        let (app, permissions, defaults, name) = try makeApp(); defer { app.stop(); defaults.removePersistentDomain(forName: name) }
        app.loading = false; app.introFinished(); XCTAssertFalse(app.showLaunchIntro); XCTAssertEqual(app.presentedSheet, .onboarding)
        app.completeOnboarding(); app.advanceFirstRun(); XCTAssertEqual(app.presentedSheet, .tour)
        app.completeTour(); app.advanceFirstRun(); XCTAssertNil(app.presentedSheet)
        XCTAssertEqual(permissions.microphoneRequests, 0); XCTAssertEqual(permissions.speechRequests, 0)
        var progress = TourProgress(); progress.back(); XCTAssertEqual(progress.index, 0)
        for _ in 0..<20 { progress.next() }; XCTAssertTrue(progress.isLast); XCTAssertEqual(progress.index, 4)
    }
}
