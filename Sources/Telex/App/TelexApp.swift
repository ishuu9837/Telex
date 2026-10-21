import SwiftUI

@main struct TelexApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var app = AppCoordinator()
    @Environment(\.openWindow) private var openWindow
    var body: some Scene {
        Window("Telex", id: "workspace") {
            WorkspaceView(app: app)
                .frame(minWidth: 1000, minHeight: 650)
                .task { app.openWorkspace = { openWindow(id: "workspace") }; delegate.coordinator = app; await app.setup() }
                .onOpenURL { app.openURL($0) }
        }
        .defaultSize(width: 1220, height: 780)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Telex") { openWindow(id: "about") }
            }
            CommandGroup(replacing: .help) {
                Button("Quick Tour…") { openWindow(id: "workspace"); app.presentedSheet = .tour }
                Button("Terms of Service…") { openWindow(id: "workspace"); app.presentedSheet = .terms }
            }
            CommandGroup(replacing: .newItem) {
                Button("New Script") { app.create() }.keyboardShortcut("n")
                Button("Import Script…") { app.importScript() }.keyboardShortcut("o")
                Button("Export Script…") { app.exportScript() }.keyboardShortcut("e", modifiers: [.command, .shift])
                Button("Split into Cue") { app.splitCue() }.keyboardShortcut("k")
                Button("Save") { Task { await app.flush() } }.keyboardShortcut("s")
            }
        }
        Window("About Telex", id: "about") { AboutView() }.windowResizability(.contentSize)
        MenuBarExtra { MenuBarView(app: app) } label: {
            Image(nsImage: BrandAssets.menuMark).accessibilityLabel("Telex menu")
        }
        Settings { SettingsView(app: app) }
    }
}
