import Foundation

struct DisplayPrompterGeometry: Codable, Equatable, Sendable {
    var floating = false
    var x = 0.0
    var y = 0.0
    var width = 300.0
    var height = 160.0
}

struct AppPreferences: Codable, Equatable, Sendable {
    var fontSizePt = 18.0
    var lineSpacingMultiplier = 1.38
    var scriptTextColorHex = "#F5F5FA"
    var scrollSpeedWPM = 150
    var voicePacingEnabled = true
    var wordTrackingEnabled = false
    var pacingPreferenceVersion = 3
    var speechLocaleIdentifier = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
    var micSensitivityDB = -38.0
    var silenceHoldMs = 350
    var voiceBeamEnabled = true
    var hoverToPauseEnabled = true
    var readingBandEnabled = true
    var countdownSeconds = 3
    var mirrorHorizontally = false
    var mirrorVertically = false
    var clickThroughEnabled = false
    var stealthModeEnabled = true
    var displayGeometries: [String: DisplayPrompterGeometry] = [:]
    var hasCompletedOnboarding = false
    var acceptedTermsVersion: String?
    var acceptedTermsAt: Date?
    var hasCompletedTour = false
    var tourSoundsEnabled = true
    var pacingMode: PacingMode {
        get { !voicePacingEnabled ? .noMicrophone : wordTrackingEnabled ? .scriptWords : .voiceLevel }
        set { voicePacingEnabled = newValue != .noMicrophone; wordTrackingEnabled = newValue == .scriptWords }
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case acceptedTermsVersion, acceptedTermsAt, hasCompletedTour, tourSoundsEnabled, pacingPreferenceVersion, fontSizePt, lineSpacingMultiplier, scriptTextColorHex, scrollSpeedWPM, voicePacingEnabled, wordTrackingEnabled, speechLocaleIdentifier, micSensitivityDB, silenceHoldMs, voiceBeamEnabled, hoverToPauseEnabled, readingBandEnabled, countdownSeconds, mirrorHorizontally, mirrorVertically, clickThroughEnabled, stealthModeEnabled, displayGeometries, hasCompletedOnboarding
    }
    init() {}
    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fontSizePt = try c.decodeIfPresent(Double.self, forKey: .fontSizePt) ?? fontSizePt
        lineSpacingMultiplier = try c.decodeIfPresent(Double.self, forKey: .lineSpacingMultiplier) ?? lineSpacingMultiplier
        scriptTextColorHex = try c.decodeIfPresent(String.self, forKey: .scriptTextColorHex) ?? scriptTextColorHex
        scrollSpeedWPM = try c.decodeIfPresent(Int.self, forKey: .scrollSpeedWPM) ?? scrollSpeedWPM
        voicePacingEnabled = try c.decodeIfPresent(Bool.self, forKey: .voicePacingEnabled) ?? voicePacingEnabled
        wordTrackingEnabled = try c.decodeIfPresent(Bool.self, forKey: .wordTrackingEnabled) ?? false
        let previousVersion = try c.decodeIfPresent(Int.self, forKey: .pacingPreferenceVersion) ?? 1
        if previousVersion < 3 { wordTrackingEnabled = false }
        speechLocaleIdentifier = try c.decodeIfPresent(String.self, forKey: .speechLocaleIdentifier) ?? speechLocaleIdentifier
        micSensitivityDB = try c.decodeIfPresent(Double.self, forKey: .micSensitivityDB) ?? micSensitivityDB
        silenceHoldMs = try c.decodeIfPresent(Int.self, forKey: .silenceHoldMs) ?? silenceHoldMs
        voiceBeamEnabled = try c.decodeIfPresent(Bool.self, forKey: .voiceBeamEnabled) ?? voiceBeamEnabled
        hoverToPauseEnabled = try c.decodeIfPresent(Bool.self, forKey: .hoverToPauseEnabled) ?? hoverToPauseEnabled
        readingBandEnabled = try c.decodeIfPresent(Bool.self, forKey: .readingBandEnabled) ?? readingBandEnabled
        countdownSeconds = try c.decodeIfPresent(Int.self, forKey: .countdownSeconds) ?? countdownSeconds
        mirrorHorizontally = try c.decodeIfPresent(Bool.self, forKey: .mirrorHorizontally) ?? mirrorHorizontally
        mirrorVertically = try c.decodeIfPresent(Bool.self, forKey: .mirrorVertically) ?? mirrorVertically
        clickThroughEnabled = try c.decodeIfPresent(Bool.self, forKey: .clickThroughEnabled) ?? clickThroughEnabled
        stealthModeEnabled = try c.decodeIfPresent(Bool.self, forKey: .stealthModeEnabled) ?? stealthModeEnabled
        displayGeometries = try c.decodeIfPresent([String: DisplayPrompterGeometry].self, forKey: .displayGeometries) ?? displayGeometries
        acceptedTermsVersion = try c.decodeIfPresent(String.self, forKey: .acceptedTermsVersion)
        acceptedTermsAt = try c.decodeIfPresent(Date.self, forKey: .acceptedTermsAt)
        hasCompletedTour = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedTour) ?? false
        tourSoundsEnabled = try c.decodeIfPresent(Bool.self, forKey: .tourSoundsEnabled) ?? true
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? hasCompletedOnboarding
    }
    mutating func validate() {
        speechLocaleIdentifier = speechLocaleIdentifier.replacingOccurrences(of: "_", with: "-")
        fontSizePt = Self.clamp(fontSizePt, 14...42, fallback: 18)
        lineSpacingMultiplier = Self.clamp(lineSpacingMultiplier, 1.2...1.8, fallback: 1.38)
        micSensitivityDB = Self.clamp(micSensitivityDB, -55 ... -15, fallback: -38)
        scrollSpeedWPM = min(300, max(40, scrollSpeedWPM))
        silenceHoldMs = min(1000, max(150, silenceHoldMs))
        if ![0, 3, 5, 10].contains(countdownSeconds) { countdownSeconds = 3 }
        if !Self.validHex(scriptTextColorHex) { scriptTextColorHex = "#F5F5FA" }
        for (id, var geometry) in displayGeometries {
            geometry.width = Self.clamp(geometry.width, 210...840, fallback: 300)
            geometry.height = Self.clamp(geometry.height, 76...520, fallback: 160)
            if !geometry.x.isFinite { geometry.x = 0 }
            if !geometry.y.isFinite { geometry.y = 0 }
            displayGeometries[id] = geometry
        }
    }
    static func validHex(_ text: String) -> Bool {
        text.count == 7 && text.first == "#" && text.dropFirst().allSatisfy(\.isHexDigit)
    }
    static func clamp(_ value: Double, _ range: ClosedRange<Double>, fallback: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
    }
}
