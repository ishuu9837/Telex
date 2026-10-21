import AppKit
import SwiftUI

@MainActor protocol PrompterWindowServiceProtocol { func show(); func hide(); func layout() }
@MainActor struct WeakPrompterWindow {
    weak var service: PrompterWindowService?
    var panel: TeleprompterPanel? { service?.panel }
    var onAction: ((PrompterAction) -> Void)? { service?.onAction }
    func resize(translation: CGSize, horizontal: Bool, vertical: Bool) { service?.resize(translation: translation, horizontal: horizontal, vertical: vertical) }
    func endResize() { service?.endResize() }
    func moveFloating(by translation: CGSize, startingAt origin: CGPoint) { service?.moveFloating(by: translation, startingAt: origin) }
}
final class TeleprompterPanel: NSPanel {
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class TrackingHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    var hoverChanged: ((Bool) -> Void)?
    var scrolled: ((Double) -> Void)?
    private var area: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let tracking = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        area = tracking; addTrackingArea(tracking)
    }
    override func mouseEntered(with event: NSEvent) { hoverChanged?(true) }
    override func mouseExited(with event: NSEvent) { hoverChanged?(false) }
    override func scrollWheel(with event: NSEvent) { scrolled?(event.scrollingDeltaY) }
}

@MainActor @Observable final class PrompterWindowService: NSObject, PrompterWindowServiceProtocol, NSWindowDelegate {
    private(set) var visible = false { didSet { if oldValue != visible { onVisibilityChanged?() } } }
    @ObservationIgnored var onVisibilityChanged: (() -> Void)?
    var selectedDisplayID = ""
    @ObservationIgnored var panel: TeleprompterPanel?
    @ObservationIgnored let model: PrompterViewModel
    @ObservationIgnored var geometryChanged: ((String, DisplayPrompterGeometry) -> Void)?
    @ObservationIgnored var onAction: ((PrompterAction) -> Void)?
    @ObservationIgnored private let surfaceProvider: (() -> DisplaySurface?)?
    @ObservationIgnored private var screenObserver: NSObjectProtocol?
    @ObservationIgnored private var applyingFrame = false
    @ObservationIgnored private var configuredStealth: Bool?
    @ObservationIgnored private var resizeStart: NSRect?
    init(model: PrompterViewModel, surfaceProvider: (() -> DisplaySurface?)? = nil) {
        self.model = model; self.surfaceProvider = surfaceProvider
        super.init()
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.layout() }
        }
    }
    var screen: NSScreen? { NSScreen.screens.first { DisplayGeometryService.id(for: $0) == selectedDisplayID } ?? NSScreen.main ?? NSScreen.screens.first }
    private var surface: DisplaySurface? {
        if let surfaceProvider { return surfaceProvider() }
        guard let screen else { return nil }
        return DisplaySurface(id: DisplayGeometryService.id(for: screen), metrics: DisplayGeometryService.metrics(for: screen))
    }
    private func preparePanel() {
        guard panel == nil else { return }
        let panel = TeleprompterPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.backgroundColor = .clear; panel.isOpaque = false; panel.hidesOnDeactivate = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false; panel.becomesKeyOnlyIfNeeded = true; panel.delegate = self
        panel.minSize = NSSize(width: 210, height: 76); panel.maxSize = NSSize(width: 840, height: 520)
        let host = TrackingHostingView(rootView: PrompterCapsuleView(model: model, window: WeakPrompterWindow(service: self)))
        host.hoverChanged = { [weak model] value in model?.hovering = value }
        host.scrolled = { [weak model] delta in guard let model else { return }; model.move(to: model.offset - delta) }
        panel.contentView = host; self.panel = panel
        configuredStealth = model.preferences.stealthModeEnabled
        CaptureExclusionService().apply(to: panel, enabled: model.preferences.stealthModeEnabled)
    }
    func show() {
        preparePanel()
        layout(); panel?.orderFrontRegardless(); visible = true; arrangeWorkspace()
    }
    func refreshPointer() {
        guard visible, let panel else { return }
        model.hovering = panel.frame.contains(NSEvent.mouseLocation)
    }
    func moveFloating(by translation: CGSize, startingAt origin: CGPoint) {
        guard model.floating, let panel else { return }
        panel.setFrameOrigin(CGPoint(x: origin.x + translation.width, y: origin.y - translation.height))
    }
    private func arrangeWorkspace() {
        guard let panel, let screen = panel.screen ?? screen else { return }
        for workspace in NSApplication.shared.windows where !(workspace is NSPanel) && workspace.title == "Telex" && workspace.isVisible {
            guard !workspace.styleMask.contains(.fullScreen), workspace.frame.intersects(panel.frame) else { continue }
            let adjusted = DisplayGeometryService.workspaceFrame(workspace.frame, avoiding: panel.frame, within: screen.visibleFrame)
            workspace.setFrame(adjusted, display: true)
        }
    }
    func hide() { panel?.orderOut(nil); visible = false; model.hovering = false }
    func invalidate() {
        hide()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        panel?.contentView = nil; panel?.close(); panel = nil
    }
    func toggle() { if visible { hide() } else { show() } }
    func layout() {
        // WindowServer may retain a live window's old sharing flag. Create a fresh
        // native panel when protection changes instead of relying on that mutation.
        if let oldPanel = panel, configuredStealth != model.preferences.stealthModeEnabled {
            oldPanel.delegate = nil; oldPanel.contentView = nil; oldPanel.close()
            panel = nil; preparePanel()
        }
        guard let panel, let surface else { return }
        applyingFrame = true; defer { applyingFrame = false }
        let id = surface.id
        let metrics = surface.metrics
        let stored = model.preferences.displayGeometries[id] ?? DisplayPrompterGeometry()
        model.floating = stored.floating
        model.safeTop = stored.floating ? 0 : Double(metrics.safeTop)
        let size = CGSize(width: stored.width, height: stored.height)
        let frame: CGRect
        if stored.floating {
            let candidate = CGRect(x: stored.x, y: stored.y, width: size.width, height: size.height)
            frame = DisplayGeometryService.clamp(candidate, to: metrics.visibleFrame)
        } else { frame = DisplayGeometryService.dockedFrame(metrics: metrics, size: size) }
        panel.hasShadow = false
        panel.setFrame(frame, display: true)
        model.panelWidth = frame.width; model.panelHeight = frame.height; model.rebuildLines()
        if visible { arrangeWorkspace() }
        panel.ignoresMouseEvents = model.preferences.clickThroughEnabled
        CaptureExclusionService().apply(to: panel, enabled: model.preferences.stealthModeEnabled)
        if visible { panel.orderFrontRegardless() }
    }
    func setSize(width: Double? = nil, height: Double? = nil) {
        guard let surface else { return }
        let id = surface.id
        var value = model.preferences.displayGeometries[id] ?? DisplayPrompterGeometry()
        if let width { value.width = min(840, max(210, width)) }
        if let height { value.height = min(520, max(76, height)) }
        model.preferences.displayGeometries[id] = value
        model.panelWidth = value.width; model.panelHeight = value.height; model.rebuildLines()
        geometryChanged?(id, value); layout()
    }
    func resize(translation: CGSize, horizontal: Bool, vertical: Bool) {
        if resizeStart == nil { resizeStart = panel?.frame }
        guard let start = resizeStart else { return }
        setSize(width: horizontal ? start.width + translation.width * (model.floating ? 1 : 2) : nil, height: vertical ? start.height + translation.height : nil)
    }
    func endResize() { resizeStart = nil }
    func toggleDock() {
        guard let surface else { return }
        let id = surface.id
        var value = model.preferences.displayGeometries[id] ?? DisplayPrompterGeometry()
        value.floating.toggle()
        if value.floating, let frame = panel?.frame { value.x = frame.minX; value.y = frame.minY - 70 }
        model.preferences.displayGeometries[id] = value; geometryChanged?(id, value); layout()
    }
    func windowDidMove(_ notification: Notification) {
        guard !applyingFrame, model.floating, let panel, let screen = panel.screen else { return }
        let id = DisplayGeometryService.id(for: screen)
        selectedDisplayID = id
        var value = model.preferences.displayGeometries[id] ?? DisplayPrompterGeometry()
        value.floating = true
        value.x = panel.frame.minX; value.y = panel.frame.minY; value.width = panel.frame.width; value.height = panel.frame.height
        model.floating = true; model.safeTop = 0
        model.preferences.displayGeometries[id] = value; geometryChanged?(id, value)
    }
}
