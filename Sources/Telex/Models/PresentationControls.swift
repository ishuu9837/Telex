import Foundation

enum PacingMode: String, CaseIterable, Identifiable, Sendable {
    case noMicrophone, voiceLevel, scriptWords
    var id: Self { self }
    var title: String {
        switch self { case .noMicrophone: "No microphone"; case .voiceLevel: "Voice level"; case .scriptWords: "Script words (optional)" }
    }
}

enum SpeedPreset: Int, CaseIterable, Identifiable, Sendable {
    case verySlow = 40, slow = 80, medium = 130, mediumFast = 180, high = 240, veryHigh = 300
    var id: Int { rawValue }
    var title: String {
        switch self { case .verySlow: "Very slow"; case .slow: "Slow"; case .medium: "Medium"; case .mediumFast: "Medium fast"; case .high: "High"; case .veryHigh: "Very high" }
    }
    var label: String { "\(title) · \(rawValue) WPM" }
}

enum PrompterAction: Equatable, Sendable {
    case playPause, stop, show, hide, quit, toggleDock, record, workspace, restart, faster, slower, returnToSpot
    case jumpToCue(UUID), pacing(PacingMode), speed(SpeedPreset)
}

enum WorkspaceSheet: String, Identifiable { case terms, onboarding, recording, tour; var id: String { rawValue } }

struct TourProgress: Equatable {
    static let count = 5
    private(set) var index = 0
    var isLast: Bool { index == Self.count - 1 }
    mutating func next() { index = min(Self.count - 1, index + 1) }
    mutating func back() { index = max(0, index - 1) }
}
