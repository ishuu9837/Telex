import AVFoundation
import Speech
import AppKit

@MainActor protocol PermissionServiceProtocol: AnyObject {
    var speechDenied: Bool { get }
    var speechGranted: Bool { get }
    func requestSpeechRecognition() async -> Bool
    func openSettings(_ pane: String)
    func requestMicrophone() async -> Bool
    func requestScreenCapture() -> Bool
}
@MainActor final class PermissionService: PermissionServiceProtocol {
    func requestMicrophone() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .audio)
        default: false
        }
    }
    var speechGranted: Bool { SFSpeechRecognizer.authorizationStatus() == .authorized }
    var speechDenied: Bool { [.denied, .restricted].contains(SFSpeechRecognizer.authorizationStatus()) }
    func requestSpeechRecognition() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return true }
        if SFSpeechRecognizer.authorizationStatus() != .notDetermined { return false }
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in continuation.resume(returning: status == .authorized) }
        }
    }
    func requestScreenCapture() -> Bool { CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() }
    func openSettings(_ pane: String = "Privacy_Microphone") {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
    }
}

extension PermissionServiceProtocol {
    func openSettings() { openSettings("Privacy_Microphone") }
}
