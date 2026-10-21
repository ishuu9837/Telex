import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var coordinator: AppCoordinator?
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let coordinator else { return .terminateNow }
        Task { sender.reply(toApplicationShouldTerminate: await coordinator.shutdown()) }
        return .terminateLater
    }
}
