import Foundation

enum PacingState: Equatable { case idle, countdown(Int), listening, speaking, silenceHold, hoverPaused, manualPaused }

struct VoicePacingStateMachine: Sendable {
    var threshold = -38.0
    var holdSeconds = 0.35
    private(set) var speaking = false
    private var lastSpeech: TimeInterval?
    mutating func update(level: Double, time: TimeInterval) -> Bool {
        if level >= threshold || (speaking && level >= threshold - 4) {
            speaking = true
            lastSpeech = time
        } else if let lastSpeech, time - lastSpeech >= holdSeconds { speaking = false }
        return speaking
    }
    static func shouldAdvance(running: Bool, hover: Bool, manual: Bool, voiceEnabled: Bool, speaking: Bool) -> Bool {
        running && !hover && !manual && (!voiceEnabled || speaking)
    }
}

struct VoicePacingEvent: Sendable {
    var speaking: Bool
    var levelDB: Double
    var intensity: Double { min(1, max(0, (levelDB + 55) / 40)) }
}
