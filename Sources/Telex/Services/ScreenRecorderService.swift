@preconcurrency import ScreenCaptureKit
@preconcurrency import AVFoundation
import AppKit
import Observation

struct RecordingTarget: Identifiable {
    var id: String
    var title: String
    var display: SCDisplay?
    var window: SCWindow?
}

@MainActor protocol ScreenRecorderServiceProtocol {
    func refreshTargets() async throws
    func start(target: RecordingTarget, url: URL, region: CGRect?, microphone: Bool, systemAudio: Bool) async throws
    func stop() async throws
}

// AVAssetWriter and capture delegates are confined to this single serial queue.
private final class RecordingPipeline: NSObject, SCStreamOutput, SCStreamDelegate, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "com.telex.mac.recording", qos: .userInitiated)
    private let writer: AVAssetWriter
    private let video: AVAssetWriterInput
    private let system: AVAssetWriterInput?
    private let microphone: AVAssetWriterInput?
    private var started = false
    private var finishing = false
    private var failure: String?
    var onFailure: (@Sendable (String) -> Void)?

    init(url: URL, width: Int, height: Int, microphone: Bool, systemAudio: Bool) throws {
        let mov = url.pathExtension.lowercased() == "mov"
        writer = try AVAssetWriter(outputURL: url, fileType: mov ? .mov : .mp4)
        writer.movieFragmentInterval = CMTime(seconds: 2, preferredTimescale: 600)
        video = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: mov ? AVVideoCodecType.hevc : AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height])
        video.expectsMediaDataInRealTime = true
        let audioSettings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 192000]
        system = systemAudio ? AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings) : nil
        self.microphone = microphone ? AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48000, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 96000]) : nil
        super.init()
        for input in [video, system, self.microphone].compactMap({ $0 }) {
            input.expectsMediaDataInRealTime = true
            guard writer.canAdd(input) else { throw TelexError.captureFailure("This encoder configuration is unavailable.") }
            writer.add(input)
        }
    }
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid, !finishing else { return }
        if type == .screen {
            guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                  let rawStatus = attachments.first?[.status] as? Int,
                  SCFrameStatus(rawValue: rawStatus) == .complete else { return }
            if !started {
                guard writer.startWriting() else { reportFailure(); return }
                writer.startSession(atSourceTime: sampleBuffer.presentationTimeStamp); started = true
            }
            append(sampleBuffer, to: video)
        } else if type == .audio, started, let system { append(sampleBuffer, to: system) }
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard started, !finishing, let microphone else { return }
        append(sampleBuffer, to: microphone)
    }
    private func append(_ buffer: CMSampleBuffer, to input: AVAssetWriterInput) {
        guard writer.status == .writing, input.isReadyForMoreMediaData else { return }
        if !input.append(buffer) { reportFailure() }
    }
    private func reportFailure() {
        guard failure == nil else { return }
        let reason = writer.error?.localizedDescription ?? "The encoder stopped accepting media."
        failure = reason; onFailure?(reason)
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) { onFailure?(error.localizedDescription) }
    func finish() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                self.finishing = true
                guard self.started else { self.writer.cancelWriting(); continuation.resume(throwing: TelexError.captureFailure("No video frames were received.")); return }
                self.video.markAsFinished(); self.system?.markAsFinished(); self.microphone?.markAsFinished()
                self.writer.finishWriting {
                    if self.writer.status == .completed { continuation.resume() }
                    else { continuation.resume(throwing: TelexError.captureFailure(self.writer.error?.localizedDescription ?? "The recording could not be finalized.")) }
                }
            }
        }
    }
}

@MainActor @Observable final class ScreenRecorderService: ScreenRecorderServiceProtocol {
    private(set) var targets: [RecordingTarget] = []
    private(set) var isRecording = false
    private(set) var microphoneActive = false
    private(set) var isBusy = false
    private(set) var lastRecordingURL: URL?
    var onFailure: ((String) -> Void)?
    @ObservationIgnored private var content: SCShareableContent?
    @ObservationIgnored private var stream: SCStream?
    @ObservationIgnored private var pipeline: RecordingPipeline?
    @ObservationIgnored private var micSession: AVCaptureSession?
    @ObservationIgnored private var healthTask: Task<Void, Never>?
    @ObservationIgnored private var outputURL: URL?

    static func excludedApplications(_ apps: [SCRunningApplication], bundleID: String = Bundle.main.bundleIdentifier ?? "com.telex.mac") -> [SCRunningApplication] {
        apps.filter { $0.bundleIdentifier == bundleID || $0.processID == ProcessInfo.processInfo.processIdentifier }
    }
    func refreshTargets() async throws {
        guard CGPreflightScreenCaptureAccess() else { throw TelexError.permissionDenied("Screen Recording") }
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        self.content = content
        targets = content.displays.map { RecordingTarget(id: "display-\($0.displayID)", title: "Display \($0.displayID) · \($0.width) × \($0.height)", display: $0) }
        targets += content.windows.filter { window in
            window.owningApplication?.processID != ProcessInfo.processInfo.processIdentifier && window.frame.width > 100 && window.frame.height > 100
        }.map { RecordingTarget(id: "window-\($0.windowID)", title: "\($0.owningApplication?.applicationName ?? "App") — \($0.title ?? "Window")", window: $0) }
    }
    func start(target: RecordingTarget, url: URL, region: CGRect?, microphone: Bool, systemAudio: Bool) async throws {
        guard !isRecording, !isBusy, let content else { throw TelexError.captureFailure("Select a capture source first.") }
        isBusy = true; defer { isBusy = false }
        let filter: SCContentFilter
        let size: CGSize
        if let display = target.display {
            filter = SCContentFilter(display: display, excludingApplications: Self.excludedApplications(content.applications), exceptingWindows: [])
            size = region?.size ?? CGSize(width: display.width, height: display.height)
        } else if let window = target.window {
            guard window.owningApplication?.processID != ProcessInfo.processInfo.processIdentifier else { throw TelexError.captureFailure("Telex windows cannot be recorded.") }
            filter = SCContentFilter(desktopIndependentWindow: window); size = window.frame.size
        } else { throw TelexError.captureFailure("The selected source is no longer available.") }
        let width = max(2, Int(size.width) / 2 * 2), height = max(2, Int(size.height) / 2 * 2)
        let config = SCStreamConfiguration()
        config.width = width; config.height = height; config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.queueDepth = 5; config.capturesAudio = systemAudio; config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000; config.channelCount = 2; config.showsCursor = true
        if let region, target.display != nil { config.sourceRect = region }
        let pipeline = try RecordingPipeline(url: url, width: width, height: height, microphone: microphone, systemAudio: systemAudio)
        pipeline.onFailure = { [weak self] reason in Task { @MainActor in
            guard let self, self.isRecording else { return }
            do { try await self.stop() } catch { self.onFailure?(error.localizedDescription) }
            self.onFailure?(reason)
        } }
        let stream = SCStream(filter: filter, configuration: config, delegate: pipeline)
        try stream.addStreamOutput(pipeline, type: .screen, sampleHandlerQueue: pipeline.queue)
        if systemAudio { try stream.addStreamOutput(pipeline, type: .audio, sampleHandlerQueue: pipeline.queue) }
        do {
            if microphone {
                guard let device = AVCaptureDevice.default(for: .audio) else { throw TelexError.permissionDenied("Microphone") }
                let session = AVCaptureSession()
                let input = try AVCaptureDeviceInput(device: device)
                let output = AVCaptureAudioDataOutput()
                guard session.canAddInput(input), session.canAddOutput(output) else { throw TelexError.captureFailure("Microphone capture is unavailable.") }
                session.addInput(input); session.addOutput(output); output.setSampleBufferDelegate(pipeline, queue: pipeline.queue)
                session.startRunning(); micSession = session; microphoneActive = true
            }
            self.pipeline = pipeline; self.stream = stream; outputURL = url
            try await stream.startCapture()
            isRecording = true
            healthTask = Task { [weak self] in
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(5)) } catch { return }
                    guard let self, self.isRecording else { return }
                    do {
                        let values = try url.deletingLastPathComponent().resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                        if let capacity = values.volumeAvailableCapacityForImportantUsage, capacity < 500_000_000 {
                            try await self.stop(); self.onFailure?("Recording stopped because disk space is low."); return
                        }
                    } catch { self.onFailure?(error.localizedDescription); return }
                }
            }
        } catch {
            micSession?.stopRunning(); micSession = nil; microphoneActive = false; self.stream = nil; self.pipeline = nil
            throw TelexError.captureFailure(error.localizedDescription)
        }
    }
    func stop() async throws {
        guard isRecording, !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        healthTask?.cancel(); healthTask = nil
        var streamError: Error?
        do { try await stream?.stopCapture() } catch { streamError = error }
        micSession?.stopRunning(); micSession = nil; microphoneActive = false
        do { try await pipeline?.finish(); lastRecordingURL = outputURL }
        catch { isRecording = false; stream = nil; pipeline = nil; throw error }
        isRecording = false; stream = nil; pipeline = nil
        if let streamError { throw TelexError.captureFailure("\(streamError.localizedDescription) The received frames were saved.") }
    }
}
