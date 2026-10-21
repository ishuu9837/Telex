import XCTest
@testable import Telex

final class PrompterViewModelTests: XCTestCase {
    @MainActor func testCueJumpUsesWrappedLineAndReturnsExactSpot() {
        let model = PrompterViewModel()
        model.script = ScriptDocument(title: "Test", body: "# Intro\nThis paragraph wraps over several lines because the panel is narrow.\n# End\nGoodbye")
        model.script.cues = TelexCueService.parse(model.script.body)
        model.panelWidth = 210; model.rebuildLines(); model.offset = 22.5
        let cue = model.script.cues[1]
        model.jump(cue)
        XCTAssertGreaterThan(model.offset, 22.5)
        model.returnToSpot(); XCTAssertEqual(model.offset, 22.5)
        model.manualPaused = true; model.running = true; model.hovering = true
        XCTAssertFalse(model.shouldAdvance); model.hovering = false; XCTAssertFalse(model.shouldAdvance)
    }
    @MainActor func testStealthStatusIsHonestForNewerOS() {
        XCTAssertTrue(CaptureExclusionService.status(enabled: true, majorVersion: 15).contains("Limited"))
        XCTAssertTrue(CaptureExclusionService.status(enabled: true, majorVersion: 14).contains("best effort"))
        XCTAssertEqual(CaptureExclusionService.status(enabled: false, majorVersion: 27), "Stealth off")
    }
}
