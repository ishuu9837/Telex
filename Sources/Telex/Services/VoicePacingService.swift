import AVFoundation
import Accelerate
import Foundation
@preconcurrency import Speech

@MainActor protocol VoicePacingServiceProtocol: AnyObject {
    var isRunning: Bool { get }
    var onFailure: (@MainActor (String) -> Void)? { get set }
    func start(threshold: Double, holdMs: Int, speechLocale: String?, onTranscript: @escaping @MainActor @Sendable (String) -> Void, onSessionStarted: @escaping @MainActor @Sendable () -> Void, onEvent: @escaping @MainActor @Sendable (VoicePacingEvent) -> Void) throws
    func stop()
}

// Owned exclusively by the serial audio tap callback; never accessed from the UI.
final class VoiceFilter: @unchecked Sendable {
    private var scratch = [Float](repeating: 0, count: 16384)
    private var previousInput: Float = 0
    private var highPass: Float = 0
    private var lowPass: Float = 0
    private var machine: VoicePacingStateMachine
    private let speechRequest: SFSpeechAudioBufferRecognitionRequest?
    init(threshold: Double, holdMs: Int, speechRequest: SFSpeechAudioBufferRecognitionRequest?) { machine = VoicePacingStateMachine(threshold: threshold, holdSeconds: Double(holdMs) / 1000); self.speechRequest = speechRequest }
    func process(_ buffer: AVAudioPCMBuffer) -> VoicePacingEvent? {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return nil }
        speechRequest?.append(buffer)
        let rate = Float(buffer.format.sampleRate)
        let hp = rate / (rate + 2 * .pi * 85)
        let lp = (2 * Float.pi * 3400) / (rate + 2 * .pi * 3400)
        // Keep raw PCM unchanged for the recognizer; filter into reusable tap-owned storage.
        let count = min(Int(buffer.frameLength), scratch.count)
        for index in 0..<count {
            let sample = samples[index]
            highPass = hp * (highPass + sample - previousInput)
            previousInput = sample
            lowPass += lp * (highPass - lowPass)
            scratch[index] = lowPass
        }
        var rms: Float = 0
        scratch.withUnsafeBufferPointer { values in
            if let base = values.baseAddress { vDSP_rmsqv(base, 1, &rms, vDSP_Length(count)) }
        }
        let db = Double(20 * log10(max(rms, 0.000001)))
        return VoicePacingEvent(speaking: machine.update(level: db, time: ProcessInfo.processInfo.systemUptime), levelDB: db)
    }
}

@MainActor final class VoicePacingService: VoicePacingServiceProtocol {
    private var engine: AVAudioEngine?
    private var recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRequest: SFSpeechAudioBufferRecognitionRequest?
    private var rolloverTask: Task<Void, Never>?
    private var sessionID = UUID()
    static var onDeviceLanguages: [SpeechLanguage] {
        SFSpeechRecognizer.supportedLocales().compactMap { locale in
            guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.supportsOnDeviceRecognition else { return nil }
            return SpeechLanguage(id: locale.identifier, name: Locale.current.localizedString(forIdentifier: locale.identifier) ?? locale.identifier)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private(set) var isRunning = false
    private var configurationObserver: NSObjectProtocol?
    var onFailure: (@MainActor (String) -> Void)?
    func start(threshold: Double, holdMs: Int, speechLocale: String?, onTranscript: @escaping @MainActor @Sendable (String) -> Void, onSessionStarted: @escaping @MainActor @Sendable () -> Void, onEvent: @escaping @MainActor @Sendable (VoicePacingEvent) -> Void) throws {
        stop()
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw TelexError.message("No microphone input is available. Choose manual pacing or connect a microphone.") }
        let id = UUID(); sessionID = id
        if let speechLocale {
            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: speechLocale)), recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
                throw TelexError.message("On-device transcription is unavailable for this language. Download its speech assets in macOS settings, choose another language, or select Voice activity pacing.")
            }
            self.recognizer = recognizer
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = true
            request.taskHint = .dictation
            self.speechRequest = request
            onSessionStarted()
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                let transcript = result?.bestTranscription.formattedString
                let final = result?.isFinal ?? false
                let failure = error?.localizedDescription
                Task { @MainActor in
                    guard let self, self.sessionID == id else { return }
                    if let transcript { onTranscript(transcript) }
                    if let failure { self.stop(); self.onFailure?("On-device transcription stopped: \(failure). Press Play to reconnect or choose Voice activity pacing.") }
                    else if final {
                        do { try self.start(threshold: threshold, holdMs: holdMs, speechLocale: speechLocale, onTranscript: onTranscript, onSessionStarted: onSessionStarted, onEvent: onEvent) }
                        catch { self.stop(); self.onFailure?(error.localizedDescription) }
                    }
                }
            }
            rolloverTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(45)) } catch { return }
                guard let self, self.sessionID == id else { return }
                do { try self.start(threshold: threshold, holdMs: holdMs, speechLocale: speechLocale, onTranscript: onTranscript, onSessionStarted: onSessionStarted, onEvent: onEvent) }
                catch { self.stop(); self.onFailure?(error.localizedDescription) }
            }
        }
        let filter = VoiceFilter(threshold: threshold, holdMs: holdMs, speechRequest: speechRequest)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            guard let event = filter.process(buffer) else { return }
            Task { @MainActor in onEvent(event) }
        }
        self.engine = engine
        do { try engine.start(); isRunning = true } catch { stop(); throw TelexError.message("The microphone could not start: \(error.localizedDescription)") }
        configurationObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.sessionID == id else { return }
                self.stop()
                self.onFailure?("The audio device changed. Press Play to reconnect your microphone.")
            }
        }
    }
    func stop() {
        sessionID = UUID(); rolloverTask?.cancel(); rolloverTask = nil
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        configurationObserver = nil
        if let engine { engine.inputNode.removeTap(onBus: 0); engine.stop() }
        engine = nil; isRunning = false
        speechRequest?.endAudio(); recognitionTask?.cancel(); recognitionTask = nil; speechRequest = nil; recognizer = nil
    }
}
