import XCTest
@testable import Telex

final class PreferencesStoreTests: XCTestCase {
    func testValidationRejectsInvalidAndNonfiniteValues() {
        var value = AppPreferences()
        value.fontSizePt = .nan; value.lineSpacingMultiplier = 9; value.micSensitivityDB = -100
        value.scrollSpeedWPM = 900; value.silenceHoldMs = 0; value.scriptTextColorHex = "hello"; value.countdownSeconds = 99
        value.validate()
        XCTAssertEqual(value.fontSizePt, 18); XCTAssertEqual(value.lineSpacingMultiplier, 1.8)
        XCTAssertEqual(value.micSensitivityDB, -55); XCTAssertEqual(value.scrollSpeedWPM, 300)
        XCTAssertEqual(value.silenceHoldMs, 150); XCTAssertEqual(value.scriptTextColorHex, "#F5F5FA"); XCTAssertEqual(value.countdownSeconds, 3)
    }
    func testOlderPreferencesKeepSettingsAndMigrateToOptInScriptFollowing() throws {
        let json = Data("{\"fontSizePt\":24,\"stealthModeEnabled\":false,\"speechLocaleIdentifier\":\"en_IN\"}".utf8)
        var value = try JSONDecoder().decode(AppPreferences.self, from: json)
        value.validate()
        XCTAssertEqual(value.fontSizePt, 24)
        XCTAssertFalse(value.stealthModeEnabled)
        XCTAssertFalse(value.wordTrackingEnabled)
        XCTAssertEqual(value.speechLocaleIdentifier, "en-IN")
    }
    func testWordFollowingRemainsExplicitOptInAfterSavingNewVersion() throws {
        XCTAssertFalse(AppPreferences().wordTrackingEnabled)
        var value = AppPreferences(); value.wordTrackingEnabled = true
        let decoded = try JSONDecoder().decode(AppPreferences.self, from: JSONEncoder().encode(value))
        XCTAssertTrue(decoded.wordTrackingEnabled)
    }
    @MainActor func testStoreRoundTripAndCorruptDataRecovery() throws {
        let name = "TelexTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = PreferencesStore(defaults: defaults)
        var value = AppPreferences(); value.scrollSpeedWPM = 220; value.clickThroughEnabled = true
        try store.save(value)
        XCTAssertEqual(store.load().scrollSpeedWPM, 220)
        XCTAssertFalse(store.load().clickThroughEnabled)
        defaults.set(Data("bad".utf8), forKey: "Telex.preferences")
        XCTAssertEqual(store.load(), AppPreferences())
    }
}
