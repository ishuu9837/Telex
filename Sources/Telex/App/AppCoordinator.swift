import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor @Observable final class AppCoordinator {
    let prompter = PrompterViewModel()
    let window: PrompterWindowService
    let recorder = ScreenRecorderService()
    let permissions: any PermissionServiceProtocol
    let repository: ScriptRepository
    let preferencesStore: PreferencesStore
    let voice: any VoicePacingServiceProtocol
    let hotkeys: any GlobalHotkeyServiceProtocol
    var hotkeyWarning: String?
    let tourSound = TourSoundService()
    @ObservationIgnored private let playbackClock: PrompterPlaybackClock
    @ObservationIgnored var quitApplication: () -> Void = { NSApplication.shared.terminate(nil) }
    @ObservationIgnored var openWorkspace: (() -> Void)?
    var showLaunchIntro = true
    var presentedSheet: WorkspaceSheet? {
        didSet {
            if presentedSheet != nil {
                prompter.stop(); meterClients.removeAll(); window.hide(); reconcileAudio()
            }
        }
    }
    var showOnboarding: Bool {
        get { presentedSheet == .onboarding }
        set { if newValue { presentedSheet = .onboarding } else if presentedSheet == .onboarding { presentedSheet = nil } }
    }
    var showRecording: Bool {
        get { presentedSheet == .recording }
        set { if newValue { presentedSheet = .recording } else if presentedSheet == .recording { presentedSheet = nil } }
    }
    var scripts: [ScriptDocument] = []
    var unreadableFiles: [URL] = []
    var selectedID: UUID?
    var draft = ScriptDocument()
    var search = ""
    var errorMessage: String?
    var saveStatus = "All changes saved"
    var loading = true
    var confirmDelete = false
    var speechLanguages: [SpeechLanguage] = []
    var speechNotice: String?
    var speechPermissionDenied = false
    var speechPermissionGranted = false
    var microphoneActivity: String {
        if recorder.microphoneActive { return "Recording" }
        switch audioDemand {
        case .stopped: return "Off"
        case .meter: return "Input level test"
        case .voiceLevel: return "Voice-level pacing"
        case .scriptWords: return "Script-word following"
        }
    }
    private(set) var audioDemand = AudioSessionDemand.stopped
    @ObservationIgnored private var meterClients = Set<UUID>()
    @ObservationIgnored private var microphoneBlocked = false
    @ObservationIgnored private var shuttingDown = false
    @ObservationIgnored private var autosaveTask: Task<Void, Never>?
    @ObservationIgnored private var voiceTask: Task<Void, Never>?
    @ObservationIgnored private var voiceGeneration = 0
    @ObservationIgnored private var positionTask: Task<Void, Never>?
    @ObservationIgnored private var setupDone = false
    @ObservationIgnored private var voiceConfiguration = ""
    private var requestedVoiceConfiguration: String { "\(preferences.voicePacingEnabled)-\(preferences.wordTrackingEnabled)-\(preferences.speechLocaleIdentifier)-\(preferences.micSensitivityDB)-\(preferences.silenceHoldMs)" }
    @ObservationIgnored private var dirty: [UUID: ScriptDocument] = [:]

    init(voice: any VoicePacingServiceProtocol = VoicePacingService(), permissions: any PermissionServiceProtocol = PermissionService(), preferencesStore: PreferencesStore = PreferencesStore(), repository: ScriptRepository = ScriptRepository(), surfaceProvider: (() -> DisplaySurface?)? = nil, hotkeys: any GlobalHotkeyServiceProtocol = GlobalHotkeyService()) {
        self.voice = voice; self.permissions = permissions; self.hotkeys = hotkeys
        self.preferencesStore = preferencesStore; self.repository = repository
        window = PrompterWindowService(model: prompter, surfaceProvider: surfaceProvider)
        playbackClock = PrompterPlaybackClock(model: prompter)
        prompter.onPlaybackChanged = { [weak self] in
            guard let self else { return }
            self.playbackClock.setRunning(self.prompter.running)
            self.reconcileAudio()
        }
        playbackClock.refreshPointer = { [weak self] in self?.window.refreshPointer() }
        window.onAction = { [weak self] action in self?.handlePrompterAction(action) }
        window.onVisibilityChanged = { [weak self] in
            guard let self else { return }
            if !self.window.visible { self.prompter.stop() }
            self.reconcileAudio()
        }
        voice.onFailure = { [weak self] message in self?.handleVoiceFailure(message) }
    }
    func refreshSpeechLanguages() {
        prompter.wordTrackingUnavailable = false
        speechNotice = nil
        speechLanguages = VoicePacingService.onDeviceLanguages
        speechPermissionDenied = permissions.speechDenied
        speechPermissionGranted = permissions.speechGranted
        if let id = SpeechLanguage.preferred(requested: preferences.speechLocaleIdentifier, system: Locale.preferredLanguages + [Locale.current.identifier], available: speechLanguages) {
            prompter.preferences.speechLocaleIdentifier = id
        } else { prompter.preferences.speechLocaleIdentifier = "" }
        if speechPermissionDenied { speechNotice = "Speech Recognition permission is denied. Using voice-level pacing instead. You can enable permission in Privacy Settings." }
        else if speechLanguages.isEmpty { speechNotice = "No on-device recognition languages are available. Using voice-level pacing instead." }
    }
    var preferences: AppPreferences {
        get { prompter.preferences }
        set { prompter.preferences = newValue; preferencesChanged() }
    }
    var filteredScripts: [ScriptDocument] {
        scripts.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.body.localizedCaseInsensitiveContains(search) || $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(search) }) }
            .sorted { a, b in a.isPinned != b.isPinned ? a.isPinned : a.updatedAt > b.updatedAt }
    }
    func enableOptionalTranscription() async {
        let granted = await permissions.requestSpeechRecognition()
        refreshSpeechLanguages()
        if !granted { speechNotice = "Apple Speech Recognition permission was not granted. Using voice-level pacing instead." }
        preferencesChanged()
    }
    func registerHotkeys() {
        do { try hotkeys.register(); hotkeyWarning = nil }
        catch { hotkeyWarning = error.localizedDescription + " Other buttons still work. Quit another Telex instance or release the shortcut, then retry." }
    }
    func setup() async {
        guard !setupDone else { return }; setupDone = true
        prompter.preferences = preferencesStore.load()
        if preferences.wordTrackingEnabled { refreshSpeechLanguages() }
        else { speechPermissionDenied = permissions.speechDenied; speechPermissionGranted = permissions.speechGranted }
        persistPreferences()
        window.geometryChanged = { [weak self] _, _ in self?.persistPreferences() }
        prompter.onPositionChanged = { [weak self] value in
            guard let self, self.selectedID != nil else { return }
            self.draft.lastScrollOffsetY = value
            if self.positionTask == nil {
                self.positionTask = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(2)) } catch { return }
                    guard let self else { return }; self.edited(); self.positionTask = nil
                }
            }
        }
        prompter.onCompletion = { [weak self] in self?.reconcileAudio(); self?.edited() }
        recorder.onFailure = { [weak self] message in self?.errorMessage = message }
        hotkeys.onAction = { [weak self] action in self?.handleHotkey(action) }
        registerHotkeys()
        do {
            let library = try await repository.loadAll()
            scripts = library.scripts; unreadableFiles = library.unreadableFiles
            if let first = scripts.sorted(by: { $0.updatedAt > $1.updatedAt }).first { select(first.id) }
        } catch { errorMessage = error.localizedDescription }
        loading = false
        if !showLaunchIntro { advanceFirstRun() }
    }
    func select(_ id: UUID) {
        guard let script = scripts.first(where: { $0.id == id }) else { return }
        prompter.stop(); window.hide(); reconcileAudio()
        selectedID = id; draft = dirty[id] ?? script
        prompter.script = draft; prompter.offset = draft.lastScrollOffsetY
        prompter.preferences.scrollSpeedWPM = draft.targetWPM
        prompter.cueService.reset(); prompter.rebuildLines()
    }
    func edited() {
        guard selectedID == draft.id else { return }
        draft.updatedAt = Date(); draft.targetWPM = preferences.scrollSpeedWPM
        draft.cues = TelexCueService.parse(draft.body, previous: draft.cues)
        prompter.script = draft; prompter.rebuildLines()
        if let index = scripts.firstIndex(where: { $0.id == draft.id }) { scripts[index] = draft }
        dirty[draft.id] = draft
        saveStatus = "Saving…"
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
            await self?.flush()
        }
    }
    func flush() async {
        let pending = dirty
        for (id, script) in pending {
            do {
                try await repository.save(script)
                if dirty[id]?.updatedAt == script.updatedAt { dirty.removeValue(forKey: id) }
            } catch { errorMessage = error.localizedDescription; saveStatus = "Draft kept in memory"; return }
        }
        if dirty.isEmpty { saveStatus = "All changes saved" }
        persistPreferences()
    }
    func create() {
        let script = ScriptDocument()
        scripts.append(script); select(script.id); edited()
    }
    func duplicate() {
        var copy = draft; copy.id = UUID(); copy.title += " copy"; copy.createdAt = Date(); copy.updatedAt = Date(); copy.lastScrollOffsetY = 0
        scripts.append(copy); select(copy.id); edited()
    }
    func deleteSelected() async {
        guard let id = selectedID else { return }
        autosaveTask?.cancel(); positionTask?.cancel(); positionTask = nil
        await flush()
        guard dirty[id] == nil else { return }
        do {
            try await repository.delete(id)
            scripts.removeAll { $0.id == id }; selectedID = nil; prompter.stop(); window.hide(); reconcileAudio()
            if let first = scripts.first { select(first.id) } else { draft = ScriptDocument(); prompter.script = draft; prompter.rebuildLines() }
        } catch { errorMessage = error.localizedDescription }
    }
    func importScript() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.plainText, .utf8PlainText, .rtf, UTType(filenameExtension: "md") ?? .plainText]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            do { let script = try ScriptRepository.importText(at: url); scripts.append(script); select(script.id); edited() }
            catch { errorMessage = error.localizedDescription }
        }
    }
    func exportScript() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.plainText, .rtf, UTType(filenameExtension: "md") ?? .plainText]
        panel.nameFieldStringValue = draft.title + ".md"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try ScriptRepository.export(draft, to: url) } catch { errorMessage = error.localizedDescription }
    }
    func splitCue() { draft.body += "\n\n# New cue\n"; edited() }
    func persistPreferences() {
        do { try preferencesStore.save(prompter.preferences) } catch { errorMessage = error.localizedDescription }
    }
    func preferencesChanged() {
        if voiceConfiguration != requestedVoiceConfiguration { prompter.wordTrackingUnavailable = false }
        prompter.preferences.validate(); persistPreferences(); window.layout(); prompter.rebuildLines()
        if selectedID != nil { edited() }
        reconcileAudio()
    }
    func playPause() {
        guard requireTerms() else { return }
        guard selectedID != nil else { create(); errorMessage = "Add text to your script before starting."; return }
        guard !draft.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { errorMessage = "Add text to your script before starting."; return }
        window.show()
        microphoneBlocked = false
        if prompter.running { prompter.manualPaused.toggle(); return }
        prompter.start(); reconcileAudio()
    }
    func setMeterVisible(_ id: UUID, visible: Bool) {
        if visible { if meterClients.insert(id).inserted { microphoneBlocked = false } } else { meterClients.remove(id) }
        reconcileAudio()
    }
    func beginEditing() { prompter.stop(); window.hide(); reconcileAudio() }
    func reconcileAudio() {
        let desired = shuttingDown || microphoneBlocked ? AudioSessionDemand.stopped : AudioSessionPolicy.demand(
            reading: prompter.running, paused: prompter.manualPaused || (prompter.hovering && preferences.hoverToPauseEnabled), countdown: prompter.countdown,
            panelVisible: window.visible, voiceEnabled: preferences.voicePacingEnabled,
            wordFollowing: prompter.usesWordTracking, meterVisible: !meterClients.isEmpty)
        if desired == audioDemand && voiceConfiguration == requestedVoiceConfiguration { return }
        voiceGeneration += 1; let generation = voiceGeneration
        voiceTask?.cancel(); voiceTask = nil; voice.stop()
        prompter.speaking = false; prompter.levelDB = -120
        audioDemand = desired; voiceConfiguration = requestedVoiceConfiguration
        guard desired != .stopped else { return }
        voiceTask = Task { [weak self] in
            guard let self else { return }
            let granted = await self.permissions.requestMicrophone()
            guard !Task.isCancelled, generation == self.voiceGeneration else { return }
            guard granted else {
                self.microphoneBlocked = true; self.prompter.stop(); self.reconcileAudio()
                self.errorMessage = TelexError.permissionDenied("Microphone").localizedDescription; return
            }
            var locale: String?
            if desired == .scriptWords {
                if self.speechLanguages.isEmpty {
                    self.fallBackToVoiceLevel("No on-device recognition languages are available."); return
                }
                guard self.permissions.speechGranted else {
                    self.speechPermissionDenied = self.permissions.speechDenied
                    self.fallBackToVoiceLevel(self.permissions.speechDenied ? "Speech Recognition permission is denied." : "Apple transcription is not enabled. It is optional and will not be requested automatically."); return
                }
                locale = self.preferences.speechLocaleIdentifier
            }
            do {
                try self.voice.start(threshold: self.preferences.micSensitivityDB, holdMs: self.preferences.silenceHoldMs,
                    speechLocale: locale, onTranscript: { [weak self] in self?.prompter.receiveTranscript($0) },
                    onSessionStarted: { [weak self] in self?.prompter.beginRecognitionSession() },
                    onEvent: { [weak self] event in
                        guard let self, generation == self.voiceGeneration else { return }
                        self.prompter.speaking = event.speaking; self.prompter.levelDB = event.levelDB
                    })
                if desired == .scriptWords { self.speechNotice = nil }
            } catch {
                if desired == .scriptWords { self.fallBackToVoiceLevel(error.localizedDescription) }
                else { self.microphoneBlocked = true; self.prompter.stop(); self.reconcileAudio(); self.errorMessage = error.localizedDescription }
            }
        }
    }
    private func fallBackToVoiceLevel(_ reason: String) {
        prompter.wordTrackingUnavailable = true
        prompter.transcriptPreview = ""
        speechNotice = reason + " Using voice-level pacing instead."
        reconcileAudio()
    }
    private func handleVoiceFailure(_ message: String) {
        if audioDemand == .scriptWords { fallBackToVoiceLevel(message) }
        else { microphoneBlocked = true; prompter.stop(); reconcileAudio(); errorMessage = message }
    }
    func stop() { prompter.stop(); reconcileAudio(); if NSApplication.shared.isActive { window.hide() }; edited() }
    func handleHotkey(_ id: UInt32) {
        guard requireTerms() else { return }
        switch id {
        case 0: playPause()
        case 1: window.toggle()
        case 2: window.toggleDock()
        case 3: preferences.clickThroughEnabled.toggle()
        case 4: showRecording = true
        case 5: preferences.scrollSpeedWPM += 10
        case 6: preferences.scrollSpeedWPM -= 10
        case 7, 8:
            let cues = draft.cues
            let current = prompter.lines.indices.last { Double($0) * prompter.lineHeight <= prompter.offset } ?? 0
            let char = prompter.lines.indices.contains(current) ? prompter.lines[current].characterOffset : 0
            if id == 7, let cue = cues.first(where: { $0.characterOffset > char }) { prompter.jump(cue) }
            if id == 8, let cue = cues.last(where: { $0.characterOffset < char }) { prompter.jump(cue) }
        case 9: prompter.returnToSpot()
        case 10: prompter.move(to: prompter.offset - prompter.lineHeight)
        case 11: prompter.move(to: prompter.offset + prompter.lineHeight)
        case 20...28: let index = Int(id - 20); if draft.cues.indices.contains(index) { prompter.jump(draft.cues[index]) }
        default: break
        }
    }
    func openURL(_ url: URL) {
        guard url.scheme == "telex", requireTerms() else { return }
        switch (url.host, url.path) {
        case ("prompter", "/toggle"): window.toggle()
        case ("prompter", "/play-pause"): playPause()
        case ("recording", "/toggle"): showRecording = true
        case ("prompter", "/stealth"):
            if let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "enabled" })?.value, ["true", "false"].contains(value) { preferences.stealthModeEnabled = value == "true" }
        default: break
        }
    }
    func introFinished() {
        guard showLaunchIntro else { return }
        showLaunchIntro = false
        if !loading { advanceFirstRun() }
    }
    var termsAccepted: Bool { preferences.acceptedTermsVersion == AppTerms.version }
    @discardableResult private func requireTerms() -> Bool {
        guard termsAccepted else { openWorkspace?(); presentedSheet = .terms; return false }
        return true
    }
    func acceptTerms() {
        prompter.preferences.acceptedTermsVersion = AppTerms.version
        prompter.preferences.acceptedTermsAt = Date()
        persistPreferences(); presentedSheet = nil
    }
    func advanceFirstRun() {
        guard !showLaunchIntro else { return }
        if !termsAccepted { presentedSheet = .terms }
        else if !preferences.hasCompletedOnboarding { presentedSheet = .onboarding }
        else if !preferences.hasCompletedTour { presentedSheet = .tour }
    }
    func completeOnboarding() { preferences.hasCompletedOnboarding = true; presentedSheet = nil }
    func completeTour() { preferences.hasCompletedTour = true; tourSound.stop(); presentedSheet = nil }
    func calibrateSensitivityFromVoice() {
        guard audioDemand != .stopped, prompter.levelDB.isFinite, prompter.levelDB > -70 else {
            errorMessage = "Start a microphone test, speak at your normal volume, then adjust sensitivity from your voice."; return
        }
        preferences.micSensitivityDB = min(-15, max(-55, prompter.levelDB - 8))
    }
    func setPacingMode(_ mode: PacingMode) {
        if mode == .noMicrophone { meterClients.removeAll() }
        preferences.pacingMode = mode
        if mode == .scriptWords { refreshSpeechLanguages(); preferencesChanged() }
        prompter.transcriptPreview = ""
    }
    func handlePrompterAction(_ action: PrompterAction) {
        if action == .quit { stop(); tourSound.stop(); quitApplication(); return }
        guard requireTerms() else { return }
        switch action {
        case .playPause: playPause()
        case .stop: stop()
        case .show: window.show()
        case .hide: window.hide()
        case .toggleDock: window.toggleDock()
        case .record: openWorkspace?(); showRecording = true; NSApplication.shared.activate(ignoringOtherApps: true)
        case .workspace: openWorkspace?(); NSApplication.shared.activate(ignoringOtherApps: true)
        case .restart: prompter.move(to: 0)
        case .faster: preferences.scrollSpeedWPM += 10
        case .slower: preferences.scrollSpeedWPM -= 10
        case .returnToSpot: prompter.returnToSpot()
        case .jumpToCue(let id): if let cue = draft.cues.first(where: { $0.id == id }) { prompter.jump(cue) }
        case .pacing(let mode): setPacingMode(mode)
        case .speed(let preset): preferences.scrollSpeedWPM = preset.rawValue
        case .quit: break
        }
    }
    func shutdown() async -> Bool {
        shuttingDown = true; playbackClock.stop(); tourSound.stop(); reconcileAudio()
        if recorder.isRecording {
            do { try await recorder.stop() } catch { errorMessage = error.localizedDescription; shuttingDown = false; return false }
        }
        autosaveTask?.cancel(); positionTask?.cancel(); stop(); await flush()
        guard dirty.isEmpty else { shuttingDown = false; return false }
        hotkeys.unregister(); window.invalidate(); return true
    }
}
