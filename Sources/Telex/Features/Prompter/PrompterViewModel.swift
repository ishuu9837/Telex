import SwiftUI
import AppKit

struct ReadingLine: Identifiable, Equatable {
    var id: Int
    var text: String
    var characterOffset: Int
    var isCue: Bool
}

@MainActor @Observable final class PrompterViewModel {
    var preferences = AppPreferences()
    var script = ScriptDocument.welcome
    var offset = 0.0
    var hovering = false { didSet { if oldValue != hovering { onPlaybackChanged?() } } }
    var manualPaused = false { didSet { if oldValue != manualPaused { onPlaybackChanged?() } } }
    var running = false { didSet { if oldValue != running { onPlaybackChanged?() } } }
    var countdown = 0 { didSet { if oldValue != countdown { onPlaybackChanged?() } } }
    var speaking = false
    var levelDB = -120.0
    var floating = false
    var safeTop = 0.0
    var panelWidth = 300.0
    var panelHeight = 160.0
    var lines: [ReadingLine] = []
    var cueService = TelexCueService()
    var matchedTargetOffset = 0.0
    var transcriptPreview = ""
    var wordTrackingUnavailable = false
    var usesWordTracking: Bool { preferences.wordTrackingEnabled && !wordTrackingUnavailable }
    var onPlaybackChanged: (() -> Void)?
    var trackingStatus = "Waiting for script words"
    @ObservationIgnored private var aligner = TokenAlignmentAlgorithm(script: "")
    @ObservationIgnored private var alignmentBody = ""
    @ObservationIgnored private var finalWordMatched = false
    var onPositionChanged: ((Double) -> Void)?
    var onCompletion: (() -> Void)?
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var lastTime: Date?

    var fontSize: Double { script.customFontSize ?? preferences.fontSizePt }
    var lineHeight: Double { fontSize * preferences.lineSpacingMultiplier }
    var maxOffset: Double { max(0, Double(lines.count) * lineHeight) }
    var shouldAdvance: Bool {
        if preferences.voicePacingEnabled && usesWordTracking {
            return running && countdown == 0 && !manualPaused && !(hovering && preferences.hoverToPauseEnabled) && matchedTargetOffset > offset + 0.1
        }
        return countdown == 0 && VoicePacingStateMachine.shouldAdvance(running: running, hover: hovering && preferences.hoverToPauseEnabled, manual: manualPaused, voiceEnabled: preferences.voicePacingEnabled, speaking: speaking)
    }
    var state: PacingState {
        if countdown > 0 { return .countdown(countdown) }
        if !running { return .idle }
        if manualPaused { return .manualPaused }
        if hovering && preferences.hoverToPauseEnabled { return .hoverPaused }
        return shouldAdvance ? .speaking : .listening
    }
    var status: String {
        switch state {
        case .idle: "Ready for your next take"
        case .countdown(let n): "Starting in \(n)"
        case .hoverPaused: "Paused while hovering"
        case .manualPaused: "Pause locked"
        case .listening: !preferences.voicePacingEnabled ? "No microphone · ready" : usesWordTracking && preferences.voicePacingEnabled ? trackingStatus : "Listening for your voice"
        default: usesWordTracking && preferences.voicePacingEnabled ? "Following matched script words" : "Reading · \(preferences.scrollSpeedWPM) WPM"
        }
    }
    func rebuildLines() {
        let capacity = max(8, Int((panelWidth - 40) / (fontSize * 0.61)))
        var result: [ReadingLine] = []
        var characterOffset = 0
        let cues = TelexCueService.parse(script.body)
        for raw in script.body.components(separatedBy: "\n") {
            let cue = cues.first { $0.characterOffset == characterOffset }
            if let cue {
                result.append(ReadingLine(id: result.count, text: cue.title, characterOffset: characterOffset, isCue: true))
            } else {
                var current = "", lineStart = characterOffset, localOffset = 0
                for word in raw.split(separator: " ", omittingEmptySubsequences: false) {
                    if !current.isEmpty && current.count + word.count + 1 > capacity {
                        result.append(ReadingLine(id: result.count, text: current, characterOffset: lineStart, isCue: false))
                        current = ""; lineStart = characterOffset + localOffset
                    }
                    if !current.isEmpty { current += " " }
                    current += word; localOffset += word.count + 1
                }
                result.append(ReadingLine(id: result.count, text: current.isEmpty ? " " : current, characterOffset: lineStart, isCue: false))
            }
            characterOffset += raw.count + 1
        }
        lines = result
        offset = min(offset, maxOffset)
        if alignmentBody != script.body {
            alignmentBody = script.body
            aligner = TokenAlignmentAlgorithm(script: script.body)
            seekAlignment()
        }
    }
    func tick(_ time: Date) {
        defer { lastTime = time }
        guard let lastTime, shouldAdvance else { return }
        let dt = min(0.1, max(0, time.timeIntervalSince(lastTime)))
        if preferences.voicePacingEnabled && usesWordTracking {
            let distance = matchedTargetOffset - offset
            let next = distance < 0.5 ? matchedTargetOffset : offset + distance * min(1, dt * 8)
            offset = min(maxOffset, max(0, next)); onPositionChanged?(offset)
            if finalWordMatched && abs(matchedTargetOffset - offset) < 0.5 { running = false; onCompletion?() }
            return
        }
        let wordsPerLine = max(1, Double(script.wordCount) / Double(max(1, lines.count)))
        move(to: offset + dt * Double(preferences.scrollSpeedWPM) / 60 / wordsPerLine * lineHeight)
        if offset >= maxOffset && maxOffset > 0 { running = false; onCompletion?() }
    }
    func move(to value: Double) { offset = min(maxOffset, max(0, value)); matchedTargetOffset = offset; seekAlignment(); onPositionChanged?(offset) }
    func seekAlignment() {
        finalWordMatched = false
        let index = min(max(0, Int(offset / lineHeight)), max(0, lines.count - 1))
        aligner.seek(characterOffset: lines.indices.contains(index) ? lines[index].characterOffset : 0)
        matchedTargetOffset = offset
    }
    func beginRecognitionSession() { aligner.beginRecognitionSession(); transcriptPreview = "" }
    func receiveTranscript(_ text: String) {
        transcriptPreview = String(text.suffix(180))
        guard running, countdown == 0, !manualPaused, !(hovering && preferences.hoverToPauseEnabled) else { aligner.ignore(transcript: text); return }
        guard let index = aligner.update(transcript: text), aligner.words.indices.contains(index) else { trackingStatus = "Holding · repeat or off-script speech"; return }
        finalWordMatched = index == aligner.words.count - 1
        let word = aligner.words[index]
        guard let lineIndex = lines.lastIndex(where: { $0.characterOffset <= word.characterOffset }) else { return }
        let start = lines[lineIndex].characterOffset
        let end = lineIndex + 1 < lines.count ? lines[lineIndex + 1].characterOffset : script.body.count
        let fraction = min(0.9, max(0, Double(word.characterOffset - start) / Double(max(1, end - start))))
        matchedTargetOffset = max(offset, min(maxOffset, (Double(lineIndex) + fraction) * lineHeight))
        trackingStatus = "Following matched script words"
    }
    func jump(_ cue: ScriptCue) {
        let index = lines.firstIndex { $0.characterOffset >= cue.characterOffset } ?? 0
        move(to: cueService.jump(to: Double(index) * lineHeight, from: offset))
    }
    func returnToSpot() { if let value = cueService.returnToPreviousPosition() { move(to: value) } }
    func togglePause() {
        if !running { start() } else { manualPaused.toggle() }
    }
    func start() {
        lastTime = nil
        countdownTask?.cancel()
        if offset >= maxOffset { move(to: 0) }
        countdown = preferences.countdownSeconds
        manualPaused = false; seekAlignment(); running = true
        countdownTask = Task { [weak self] in
            while let self, self.countdown > 0 {
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
                self.countdown -= 1
            }
        }
    }
    func stop() { countdownTask?.cancel(); running = false; countdown = 0; speaking = false }
}
