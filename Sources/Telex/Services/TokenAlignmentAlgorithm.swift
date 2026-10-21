import Foundation

struct ScriptWord: Sendable, Equatable {
    var normalized: String
    var characterOffset: Int
}

/// Aligns complete partial transcripts, preserving progress across revisions and repeats.
struct TokenAlignmentAlgorithm: Sendable {
    var words: [ScriptWord]
    private(set) var currentIndex = -1
    private var previousTranscript: [String] = []
    private var consumedCount = 0

    init(script: String) { words = Self.tokenizeScript(script) }
    static func normalize(_ word: String) -> String {
        word.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .filter { $0.isLetter || $0.isNumber }
    }
    private static func lexemes(_ text: String) -> [ScriptWord] {
        var result: [ScriptWord] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: .byWords) { substring, range, _, _ in
            guard let substring else { return }
            let normalized = normalize(substring)
            if !normalized.isEmpty { result.append(ScriptWord(normalized: normalized, characterOffset: text.distance(from: text.startIndex, to: range.lowerBound))) }
        }
        return result
    }
    static func tokenizeScript(_ text: String) -> [ScriptWord] {
        let cueOffsets = Set(TelexCueService.parse(text).map(\.characterOffset))
        var result: [ScriptWord] = [], offset = 0
        for line in text.components(separatedBy: "\n") {
            if !cueOffsets.contains(offset) {
                result += lexemes(line).map { ScriptWord(normalized: $0.normalized, characterOffset: offset + $0.characterOffset) }
            }
            offset += line.count + 1
        }
        return result
    }
    mutating func seek(characterOffset: Int) {
        currentIndex = (words.firstIndex { $0.characterOffset >= characterOffset } ?? words.count) - 1
        beginRecognitionSession()
    }
    mutating func beginRecognitionSession() {
        previousTranscript = []; consumedCount = 0
    }
    mutating func ignore(transcript: String) {
        previousTranscript = Self.lexemes(transcript).map(\.normalized)
        consumedCount = previousTranscript.count
    }
    /// Returns the last matched script word. A repeated or revised transcript never moves backwards.
    mutating func update(transcript: String) -> Int? {
        let heard = Self.lexemes(transcript).map(\.normalized)
        guard heard != previousTranscript, !heard.isEmpty else { return nil }
        let common = zip(heard, previousTranscript).prefix { $0 == $1 }.count
        // Revisit corrected partial words without replaying already matched transcript prefixes.
        let start = min(consumedCount, common)
        previousTranscript = heard
        guard heard.count > start else { return nil }
        let oldIndex = currentIndex
        for heardIndex in start..<heard.count {
            guard heardIndex > 0 else { continue }
            let a = heard[heardIndex - 1], b = heard[heardIndex]
            // A repeated isolated word provides no new location information.
            guard a != b else { continue }
            let lower = max(1, currentIndex - 12)
            let upper = min(words.count - 1, max(currentIndex + 25, 25))
            guard lower <= upper else { continue }
            var candidates: [Int] = []
            for index in lower...upper where Self.matches(a, words[index - 1].normalized) && Self.matches(b, words[index].normalized) { candidates.append(index) }
            // Prefer a repeat near the current place over skipping to a later recurrence.
            if let repeated = candidates.filter({ $0 <= currentIndex }).max(), currentIndex - repeated <= 12 { continue }
            guard let next = candidates.first(where: { $0 > currentIndex }) else { continue }
            // A large forward jump requires a third consecutive matching word.
            if next > currentIndex + 5 {
                guard heardIndex >= 2, next >= 2, Self.matches(heard[heardIndex - 2], words[next - 2].normalized) else { continue }
            }
            currentIndex = next
        }
        consumedCount = max(consumedCount, heard.count - 1)
        return currentIndex > oldIndex ? currentIndex : nil
    }
    static func matches(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        guard a.count >= 5, b.count >= 5, abs(a.count - b.count) <= 1 else { return false }
        // Restrict fuzzy matches to one edit so unrelated speech cannot pull the script ahead.
        let lhs = Array(a), rhs = Array(b)
        var previous = Array(0...rhs.count)
        for (i, character) in lhs.enumerated() {
            var row = [i + 1]
            for (j, other) in rhs.enumerated() { row.append(min(row[j] + 1, previous[j + 1] + 1, previous[j] + (character == other ? 0 : 1))) }
            previous = row
        }
        return (previous.last ?? 2) <= 1
    }
}
