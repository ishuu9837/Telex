import Foundation

enum AudioSessionDemand: Equatable, Sendable { case stopped, meter, voiceLevel, scriptWords }

enum AudioSessionPolicy {
    static func demand(reading: Bool, paused: Bool, countdown: Int, panelVisible: Bool, voiceEnabled: Bool, wordFollowing: Bool, meterVisible: Bool) -> AudioSessionDemand {
        if reading && !paused && countdown == 0 && panelVisible && voiceEnabled { return wordFollowing ? .scriptWords : .voiceLevel }
        return meterVisible ? .meter : .stopped
    }
}

struct SpeechLanguage: Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    static func preferred(requested: String, system: [String], available: [SpeechLanguage]) -> String? {
        func canonical(_ value: String) -> String { value.replacingOccurrences(of: "_", with: "-").lowercased() }
        for candidate in [requested] + system {
            if let match = available.first(where: { canonical($0.id) == canonical(candidate) }) { return match.id }
        }
        for candidate in system + [requested] {
            let language = canonical(candidate).split(separator: "-").first
            if let match = available.first(where: { canonical($0.id).split(separator: "-").first == language }) { return match.id }
        }
        return available.first?.id
    }
}
