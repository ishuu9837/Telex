import XCTest
@testable import Telex

final class VoicePacingStateMachineTests: XCTestCase {
    func testSpeechStartsImmediatelyAndSilenceHoldPreventsStutter() {
        var machine = VoicePacingStateMachine()
        XCTAssertFalse(machine.update(level: -60, time: 0))
        XCTAssertTrue(machine.update(level: -30, time: 1))
        XCTAssertTrue(machine.update(level: -65, time: 1.1))
        XCTAssertTrue(machine.update(level: -65, time: 1.34))
        XCTAssertFalse(machine.update(level: -65, time: 1.36))
    }
    func testHysteresisAndNoiseRejection() {
        var machine = VoicePacingStateMachine()
        XCTAssertFalse(machine.update(level: -40, time: 0))
        XCTAssertTrue(machine.update(level: -37, time: 1))
        XCTAssertTrue(machine.update(level: -40, time: 2))
        XCTAssertTrue(machine.update(level: -50, time: 2.2))
        XCTAssertFalse(machine.update(level: -50, time: 2.4))
    }
    func testHoverExitCannotOverrideManualPause() {
        let advance = VoicePacingStateMachine.shouldAdvance
        XCTAssertFalse(advance(true, true, false, false, true))
        XCTAssertTrue(advance(true, false, false, false, false))
        XCTAssertFalse(advance(true, false, true, false, true))
        XCTAssertFalse(advance(true, false, false, true, false))
        XCTAssertFalse(advance(false, false, false, false, true))
    }
}
