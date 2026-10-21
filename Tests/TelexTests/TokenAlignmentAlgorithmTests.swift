import XCTest
@testable import Telex

final class TokenAlignmentAlgorithmTests: XCTestCase {
    let script = "# Intro\nSpeak naturally to the camera without looking like you are reading. Use it for video recordings and online meetings."
    func testNormalReadingAndRepeatedPartialUpdates() {
        var aligner = TokenAlignmentAlgorithm(script: script)
        XCTAssertEqual(aligner.update(transcript: "Speak naturally"), 1)
        XCTAssertEqual(aligner.update(transcript: "Speak naturally to the camera"), 4)
        XCTAssertNil(aligner.update(transcript: "Speak naturally to the camera"))
        XCTAssertEqual(aligner.update(transcript: "Speak naturally to the camera without looking"), 6)
    }
    func testRepeatedWordsAndPhrasesDoNotAdvance() {
        var aligner = TokenAlignmentAlgorithm(script: script)
        _ = aligner.update(transcript: "Speak naturally to the camera")
        XCTAssertNil(aligner.update(transcript: "Speak naturally to the camera camera camera camera"))
        XCTAssertEqual(aligner.currentIndex, 4)
        XCTAssertNil(aligner.update(transcript: "Speak naturally to the camera camera camera camera to the camera to the camera"))
        XCTAssertEqual(aligner.currentIndex, 4)
        XCTAssertEqual(aligner.update(transcript: "Speak naturally to the camera camera camera camera to the camera to the camera without looking like"), 7)
    }
    func testOffScriptSpeechHoldsAndThenResumes() {
        var aligner = TokenAlignmentAlgorithm(script: script)
        _ = aligner.update(transcript: "Speak naturally to the camera")
        XCTAssertNil(aligner.update(transcript: "Speak naturally to the camera let me think about that question"))
        XCTAssertEqual(aligner.currentIndex, 4)
        XCTAssertEqual(aligner.update(transcript: "Speak naturally to the camera let me think about that question without looking like"), 7)
    }
    func testCueTextDoesNotEnterSpokenTokensAndOffsetsStayUnicodeSafe() {
        let text = "# Intro\nनमस्ते everyone 👋\n[Cue: Next]\nHello world"
        let words = TokenAlignmentAlgorithm.tokenizeScript(text)
        XCTAssertEqual(words.map(\.normalized), ["नमस्ते", "everyone", "hello", "world"])
        let hello = words.first { $0.normalized == "hello" }
        XCTAssertEqual(hello?.characterOffset, "# Intro\nनमस्ते everyone 👋\n[Cue: Next]\n".count)
    }
    func testRecognitionRolloverKeepsPlace() {
        var aligner = TokenAlignmentAlgorithm(script: script)
        _ = aligner.update(transcript: "Speak naturally to the camera")
        aligner.beginRecognitionSession()
        XCTAssertNil(aligner.update(transcript: "to the camera"))
        XCTAssertEqual(aligner.currentIndex, 4)
        XCTAssertEqual(aligner.update(transcript: "to the camera without looking"), 6)
    }
    func testRevisionsNeverMoveBackwards() {
        var aligner = TokenAlignmentAlgorithm(script: script)
        _ = aligner.update(transcript: "Speak naturally to the camera")
        XCTAssertNil(aligner.update(transcript: "Speak naturally to a camera"))
        XCTAssertEqual(aligner.currentIndex, 4)
    }
    @MainActor func testWordModeCannotScrollFromAudioVolumeAlone() {
        let model = PrompterViewModel()
        model.script = ScriptDocument(title: "Test", body: script)
        model.rebuildLines(); model.running = true; model.speaking = true
        model.preferences.wordTrackingEnabled = true; model.preferences.voicePacingEnabled = true
        XCTAssertFalse(model.shouldAdvance)
        model.receiveTranscript("Speak naturally to the camera")
        XCTAssertTrue(model.shouldAdvance)
        let target = model.matchedTargetOffset
        model.receiveTranscript("Speak naturally to the camera camera camera")
        XCTAssertEqual(model.matchedTargetOffset, target)
    }
    @MainActor func testPausedTranscriptsDoNotSkipScriptOnResume() {
        let model = PrompterViewModel()
        model.script = ScriptDocument(title: "Test", body: script)
        model.rebuildLines(); model.running = true; model.manualPaused = true
        model.receiveTranscript("Speak naturally to the camera")
        XCTAssertEqual(model.matchedTargetOffset, 0)
        model.manualPaused = false
        model.receiveTranscript("Speak naturally to the camera unrelated conversation")
        XCTAssertEqual(model.matchedTargetOffset, 0)
    }
}
