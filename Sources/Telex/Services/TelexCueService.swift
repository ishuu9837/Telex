import Foundation

struct TelexCueService: Sendable {
    private(set) var returnPositionStack: [Double] = []
    static func parse(_ body: String, previous: [ScriptCue] = []) -> [ScriptCue] {
        var result: [ScriptCue] = []
        var offset = 0
        var used = Set<UUID>()
        for (lineIndex, raw) in body.components(separatedBy: "\n").enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            var title: String?
            if line.hasPrefix("#") {
                let tail = line.drop(while: { $0 == "#" })
                if tail.first == " " { title = tail.trimmingCharacters(in: .whitespaces) }
            } else if line.lowercased().hasPrefix("[cue:"), line.hasSuffix("]") {
                title = String(line.dropFirst(5).dropLast()).trimmingCharacters(in: .whitespaces)
            }
            if let title, !title.isEmpty {
                let existing = previous.first { $0.title == title && !used.contains($0.id) }
                let id = existing?.id ?? UUID()
                used.insert(id)
                result.append(ScriptCue(id: id, title: title, characterOffset: offset, lineIndex: lineIndex))
            }
            offset += raw.count + 1
        }
        return result
    }
    mutating func jump(to position: Double, from current: Double) -> Double {
        returnPositionStack.append(current)
        return max(0, position)
    }
    mutating func returnToPreviousPosition() -> Double? { returnPositionStack.popLast() }
    mutating func reset() { returnPositionStack.removeAll() }
}
