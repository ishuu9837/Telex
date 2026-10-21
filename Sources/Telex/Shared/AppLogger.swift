import OSLog

enum AppLogger {
    static let lifecycle = Logger(subsystem: "com.telex.mac", category: "Lifecycle")
    static let signposter = OSSignposter(subsystem: "com.telex.mac", category: "Performance")
}
