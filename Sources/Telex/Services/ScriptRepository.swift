import Foundation
import AppKit

struct ScriptLibrary: Sendable { var scripts: [ScriptDocument]; var unreadableFiles: [URL] }
protocol ScriptRepositoryProtocol: Sendable {
    func loadAll() async throws -> ScriptLibrary
    func save(_ script: ScriptDocument) async throws
    func delete(_ id: UUID) async throws
}
actor ScriptRepository: ScriptRepositoryProtocol {
    let directory: URL
    init(directory: URL = URL.applicationSupportDirectory.appending(path: "Telex/Scripts")) { self.directory = directory }
    private func prepare() throws { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
    func loadAll() throws -> ScriptLibrary {
        try prepare()
        var library = ScriptLibrary(scripts: [], unreadableFiles: [])
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }
        for url in files {
            do {
                let decoder = Self.decoder()
                var script = try decoder.decode(ScriptDocument.self, from: Data(contentsOf: url))
                guard url.deletingPathExtension().lastPathComponent == script.id.uuidString else { throw TelexError.unreadableScriptFile(url) }
                try script.validate()
                library.scripts.append(script)
            } catch { library.unreadableFiles.append(url) }
        }
        if files.isEmpty {
            var sample = ScriptDocument.welcome
            try sample.validate(); try save(sample); library.scripts = [sample]
        }
        return library
    }
    func save(_ script: ScriptDocument) throws {
        var checked = script
        try checked.validate()
        try prepare()
        let url = directory.appendingPathComponent("\(checked.id).json")
        if FileManager.default.fileExists(atPath: url.path) {
            let decoder = Self.decoder()
            guard let existing = try? decoder.decode(ScriptDocument.self, from: Data(contentsOf: url)), existing.schemaVersion == 1 else { throw TelexError.unreadableScriptFile(url) }
            if existing.updatedAt > checked.updatedAt { return }
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: date))
        }
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let temporary = directory.appendingPathComponent(".\(UUID()).tmp")
        do {
            try encoder.encode(checked).write(to: temporary)
            let handle = try FileHandle(forWritingTo: temporary)
            try handle.synchronize(); try handle.close()
            if FileManager.default.fileExists(atPath: url.path) { _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary) }
            else { try FileManager.default.moveItem(at: temporary, to: url) }
        } catch {
            if FileManager.default.fileExists(atPath: temporary.path) { try? FileManager.default.removeItem(at: temporary) }
            throw TelexError.persistenceFailure(error.localizedDescription)
        }
    }
    private static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
        }
        return decoder
    }
    func delete(_ id: UUID) throws { try FileManager.default.removeItem(at: directory.appendingPathComponent("\(id).json")) }
    static func importText(at url: URL) throws -> ScriptDocument {
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size < 10_000_000 else { throw TelexError.message("This file is too large to import.") }
        let body: String
        if url.pathExtension.lowercased() == "rtf" {
            body = try NSAttributedString(url: url, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil).string
        } else { body = try String(contentsOf: url, encoding: .utf8) }
        var script = ScriptDocument(title: url.deletingPathExtension().lastPathComponent, body: body)
        try script.validate(); return script
    }
    static func export(_ script: ScriptDocument, to url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        if url.pathExtension.lowercased() == "rtf" {
            let text = NSAttributedString(string: script.body)
            try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]).write(to: url, options: .atomic)
        } else { try script.body.write(to: url, atomically: true, encoding: .utf8) }
    }
}
