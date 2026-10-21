import Foundation

struct ScriptCue: Codable, Sendable, Equatable, Identifiable {
    var id = UUID()
    var title: String
    var characterOffset: Int
    var lineIndex: Int
}

struct ScriptDocument: Codable, Sendable, Equatable, Identifiable {
    var schemaVersion = 1
    var id = UUID()
    var title = "Untitled Script"
    var body = ""
    var cues: [ScriptCue] = []
    var customTextColorHex: String?
    var customFontSize: Double?
    var targetWPM = 150
    var lastScrollOffsetY = 0.0
    var isPinned = false
    var tags: [String] = []
    var createdAt = Date()
    var updatedAt = Date()

    var wordCount: Int { body.split(whereSeparator: \.isWhitespace).count }
    mutating func validate() throws {
        guard schemaVersion == 1 else { throw TelexError.message("This script uses an unsupported version. The original file has been preserved.") }
        guard body.count <= 500_000 else { throw TelexError.message("Scripts must contain at most 500,000 characters.") }
        title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        if title.isEmpty { title = "Untitled Script" }
        targetWPM = min(300, max(40, targetWPM))
        lastScrollOffsetY = lastScrollOffsetY.isFinite ? max(0, lastScrollOffsetY) : 0
        if let size = customFontSize { customFontSize = size.isFinite ? min(42, max(14, size)) : 18 }
        cues = TelexCueService.parse(body, previous: cues)
        updatedAt = max(createdAt, updatedAt)
    }
    static let welcome = ScriptDocument(title: "Your first take", body: """
    # 1. Camera Eye Contact
    Speak naturally to the camera without looking like you're reading. Use it for video recordings, online meetings, presentations, and live demos.

    # 2. Voice & Hover Control
    As you speak, Telex scrolls smoothly at your pace and the visual beam responds to your voice volume. Hover your cursor over this window to pause instantly.

    # 3. Telex Cue Jumping
    When someone asks a question three topics away, click any Cue pill to jump straight to the section you need, then pick right back up where you left off.
    """)
}

enum TelexError: LocalizedError, Sendable {
    case message(String)
    case unreadableScriptFile(URL)
    case persistenceFailure(String)
    case permissionDenied(String)
    case captureFailure(String)
    case hotkeyConflict(String)
    var errorDescription: String? {
        switch self {
        case .message(let text): text
        case .unreadableScriptFile: "A script could not be read. Its original file is untouched."
        case .persistenceFailure(let reason): "Could not save your script. Your draft is still in the editor. \(reason)"
        case .permissionDenied(let kind): "Allow \(kind) in System Settings → Privacy & Security. Manual pacing remains available."
        case .captureFailure(let reason): "Recording failed: \(reason)"
        case .hotkeyConflict(let key): "The shortcut \(key) could not be registered. It may be in use."
        }
    }
}
