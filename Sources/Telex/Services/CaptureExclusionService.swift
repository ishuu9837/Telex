import AppKit

@MainActor protocol CaptureExclusionServiceProtocol { func apply(to window: NSWindow, enabled: Bool) }
@MainActor struct CaptureExclusionService: CaptureExclusionServiceProtocol {
    static func status(enabled: Bool, majorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) -> String {
        guard enabled else { return "Stealth off" }
        return majorVersion >= 15 ? "Stealth Limited · macOS 15 or later" : "Stealth active · best effort"
    }
    static func toggleLabel(enabled: Bool, majorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) -> String {
        guard enabled else { return "Activate Stealth" }
        return majorVersion >= 15 ? "Stealth: Limited" : "Stealth: Active (best effort)"
    }
    static let guidance = "Other apps may capture the panel when sharing the entire display. Share an individual application window, use a second display, or hide Telex. Built-in display recording uses an exclusion filter; verify a test recording before relying on it. Stealth does not hide macOS microphone or recording privacy indicators."
    func apply(to window: NSWindow, enabled: Bool) { window.sharingType = enabled ? .none : .readOnly }
}
