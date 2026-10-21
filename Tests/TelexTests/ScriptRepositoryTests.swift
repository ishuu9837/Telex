import XCTest
@testable import Telex

final class ScriptRepositoryTests: XCTestCase, @unchecked Sendable {
    func temporary() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("TelexTests-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    func testAtomicSaveUpdateLoadAndDelete() async throws {
        let directory = try temporary(); defer { try? FileManager.default.removeItem(at: directory) }
        let repo = ScriptRepository(directory: directory)
        var script = ScriptDocument(title: "Test", body: "# Intro\nHello")
        try await repo.save(script)
        script.body = "# Revised\nUpdated"; script.updatedAt = Date().addingTimeInterval(1)
        try await repo.save(script)
        var result = try await repo.loadAll()
        XCTAssertEqual(result.scripts.count, 1); XCTAssertEqual(result.scripts[0].body, script.body)
        XCTAssertEqual(result.scripts[0].cues.first?.title, "Revised")
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: directory.path).contains { $0.hasSuffix(".tmp") })
        try await repo.delete(script.id)
        // Empty libraries seed the welcome script on the next launch.
        result = try await repo.loadAll(); XCTAssertEqual(result.scripts.count, 1)
        XCTAssertNotEqual(result.scripts[0].id, script.id)
    }
    func testMalformedFilePreservedAndNotOverwritten() async throws {
        let directory = try temporary(); defer { try? FileManager.default.removeItem(at: directory) }
        let repo = ScriptRepository(directory: directory)
        let script = ScriptDocument()
        let url = directory.appendingPathComponent("\(script.id).json")
        let original = Data("{broken".utf8); try original.write(to: url)
        let result = try await repo.loadAll()
        XCTAssertTrue(result.scripts.isEmpty); XCTAssertEqual(result.unreadableFiles.map { $0.resolvingSymlinksInPath() }, [url.resolvingSymlinksInPath()])
        do { try await repo.save(script); XCTFail("Must refuse to overwrite malformed data") } catch { }
        XCTAssertEqual(try Data(contentsOf: url), original)
    }
    func testStaleWriteCannotReplaceNewerScript() async throws {
        let directory = try temporary(); defer { try? FileManager.default.removeItem(at: directory) }
        let repo = ScriptRepository(directory: directory)
        var script = ScriptDocument(title: "Newest")
        script.updatedAt = Date(timeIntervalSince1970: 2_000_000_000.8)
        try await repo.save(script)
        script.title = "Stale"; script.updatedAt = Date(timeIntervalSince1970: 2_000_000_000.2)
        try await repo.save(script)
        let result = try await repo.loadAll(); XCTAssertEqual(result.scripts[0].title, "Newest")
    }
    func testTextMarkdownAndRTFRoundTrip() throws {
        let directory = try temporary(); defer { try? FileManager.default.removeItem(at: directory) }
        let script = ScriptDocument(title: "Unicode", body: "# Intro\nHello नमस्ते 👋")
        for ext in ["txt", "md", "rtf"] {
            let url = directory.appendingPathComponent("Example.\(ext)")
            try ScriptRepository.export(script, to: url)
            XCTAssertEqual(try ScriptRepository.importText(at: url).body, script.body)
        }
    }
}
