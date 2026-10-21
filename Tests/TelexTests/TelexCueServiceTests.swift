import XCTest
@testable import Telex

final class TelexCueServiceTests: XCTestCase {
    func testUnicodeOffsetsAndStableCueIDs() {
        let text = "Hello 👋🏽\n# Intro\nA paragraph\n## Roadmap\n[Cue: Q&A]\n#not a heading"
        let cues = TelexCueService.parse(text)
        XCTAssertEqual(cues.map(\.title), ["Intro", "Roadmap", "Q&A"])
        XCTAssertEqual(cues[0].characterOffset, "Hello 👋🏽\n".count)
        XCTAssertEqual(cues[1].lineIndex, 3)
        let reparsed = TelexCueService.parse(text + "\nMore", previous: cues)
        XCTAssertEqual(cues.map(\.id), reparsed.map(\.id))
    }
    func testNestedJumpsReturnInReverseOrder() {
        var service = TelexCueService()
        XCTAssertEqual(service.jump(to: 400, from: 100), 400)
        XCTAssertEqual(service.jump(to: 900, from: 450), 900)
        XCTAssertEqual(service.returnToPreviousPosition(), 450)
        XCTAssertEqual(service.returnToPreviousPosition(), 100)
        XCTAssertNil(service.returnToPreviousPosition())
    }
    func testDuplicateTitlesHaveDistinctStableIDs() {
        let cues = TelexCueService.parse("# Same\n# Same")
        XCTAssertNotEqual(cues[0].id, cues[1].id)
        XCTAssertEqual(TelexCueService.parse("# Same\n# Same", previous: cues), cues)
    }
}
