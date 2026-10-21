import SwiftUI

struct WorkspaceView: View {
    @Bindable var app: AppCoordinator
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack { Image(nsImage: BrandAssets.logo).resizable().frame(width: 32, height: 32).accessibilityLabel("Telex M and X logo"); Text("Telex").font(.title2.bold()); Spacer(); Button { app.create() } label: { Image(systemName: "square.and.pencil") }.buttonStyle(.plain).help("New script") }.padding(20)
                Text("YOUR WORDS. YOUR PACE.").font(.system(size: 9, weight: .semibold, design: .monospaced)).tracking(1.5).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.bottom, 16)
                List(selection: Binding(get: { app.selectedID }, set: { if let id = $0 { app.select(id) } })) {
                    Section("Scripts") {
                        ForEach(app.filteredScripts) { script in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack { Text(script.title).font(.system(size: 13, weight: .medium)).lineLimit(1); Spacer(); if script.isPinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(DesignTokens.periwinkle) } }
                                Text("\(script.wordCount) words · \(script.updatedAt.formatted(date: .abbreviated, time: .omitted))").font(.caption2).foregroundStyle(.secondary)
                            }.padding(.vertical, 7).tag(script.id)
                        }
                    }
                    if !app.draft.cues.isEmpty {
                        Section("TELEX CUE") {
                            ForEach(app.draft.cues) { cue in Button { app.window.show(); app.prompter.jump(cue) } label: { Label(cue.title, systemImage: "number").font(.caption).lineLimit(1) }.buttonStyle(.plain).padding(.vertical, 3) }
                        }
                    }
                    if !app.unreadableFiles.isEmpty {
                        Section("Recovery") {
                            ForEach(app.unreadableFiles, id: \.self) { url in Button("Reveal unreadable script") { NSWorkspace.shared.activateFileViewerSelecting([url]) }.font(.caption).help("The original file is preserved") }
                        }
                    }
                }.listStyle(.sidebar)
                HStack { Image(systemName: "lock.shield"); Text("On your Mac. Only."); Spacer(); Button { app.importScript() } label: { Image(systemName: "square.and.arrow.down") }.buttonStyle(.plain).help("Import script") }.font(.caption).foregroundStyle(.secondary).padding(18)
            }.navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 290)
        } detail: {
            HSplitView {
                if app.loading { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
                else if app.selectedID == nil {
                    ContentUnavailableView { Label("Your next great take", systemImage: "text.viewfinder") } description: { Text("Start with a script, then keep your eyes on the camera.") } actions: { Button("Create script") { app.create() }.buttonStyle(.borderedProminent) }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else { ScriptEditorView(app: app).frame(minWidth: 400, maxWidth: .infinity) }
                PrompterInspectorView(app: app).frame(width: 285)
            }
        }
        .searchable(text: $app.search, placement: .sidebar, prompt: "Find a script")
        .toolbar { WorkspaceToolbar(app: app) }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            if let window = notification.object as? NSWindow, window.title == "Telex", !app.prompter.running { app.window.hide() }
        }
        .overlay { if app.showLaunchIntro { LaunchIntroView { app.introFinished() } } }
        .sheet(item: $app.presentedSheet, onDismiss: { app.advanceFirstRun() }) { sheet in
            switch sheet {
            case .terms: TermsView(app: app)
            case .onboarding: OnboardingView(app: app)
            case .recording: RecordingControlsView(app: app)
            case .tour: QuickTourView(app: app)
            }
        }
        .alert("Telex", isPresented: Binding(get: { app.errorMessage != nil }, set: { if !$0 { app.errorMessage = nil } })) {
            Button("OK") { app.errorMessage = nil }
            Button("Privacy Settings") { app.permissions.openSettings() }
        } message: { Text(app.errorMessage ?? "") }
        .confirmationDialog("Delete “\(app.draft.title)”?", isPresented: $app.confirmDelete) {
            Button("Delete Script", role: .destructive) { Task { await app.deleteSelected() } }
        } message: { Text("This removes the saved script from your Mac.") }
        .tint(DesignTokens.periwinkle)
        .preferredColorScheme(.dark)
    }
}
