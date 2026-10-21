import AppKit

struct DisplayMetrics: Sendable {
    var frame: CGRect
    var visibleFrame: CGRect
    var safeTop: CGFloat
    var notchWidth: CGFloat
}
struct DisplaySurface: Sendable { var id: String; var metrics: DisplayMetrics }
protocol DisplayGeometryServiceProtocol { static func dockedFrame(metrics: DisplayMetrics, size: CGSize) -> CGRect }
enum DisplayGeometryService: DisplayGeometryServiceProtocol {
    static func dockedFrame(metrics: DisplayMetrics, size: CGSize) -> CGRect {
        let width = min(max(max(210, metrics.notchWidth + 44), size.width), min(840, metrics.frame.width))
        let height = min(max(76, size.height), min(520, metrics.visibleFrame.height))
        let top = metrics.safeTop > 0 ? metrics.frame.maxY : metrics.visibleFrame.maxY
        return CGRect(x: metrics.frame.midX - width / 2, y: top - height, width: width, height: height)
    }
    static func workspaceFrame(_ frame: CGRect, avoiding panel: CGRect, within bounds: CGRect) -> CGRect {
        guard frame.intersects(panel) else { return frame }
        let top = panel.minY - 12
        let height = min(frame.height, max(0, top - bounds.minY))
        return CGRect(x: min(max(frame.minX, bounds.minX), max(bounds.minX, bounds.maxX - frame.width)), y: top - height, width: min(frame.width, bounds.width), height: height)
    }
    static func clamp(_ frame: CGRect, to bounds: CGRect) -> CGRect {
        let width = min(frame.width, bounds.width), height = min(frame.height, bounds.height)
        return CGRect(x: min(max(frame.minX, bounds.minX), bounds.maxX - width), y: min(max(frame.minY, bounds.minY), bounds.maxY - height), width: width, height: height)
    }
    @MainActor static func metrics(for screen: NSScreen) -> DisplayMetrics {
        let notchWidth: CGFloat
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea { notchWidth = right.minX - left.maxX } else { notchWidth = 0 }
        return DisplayMetrics(frame: screen.frame, visibleFrame: screen.visibleFrame, safeTop: screen.safeAreaInsets.top, notchWidth: notchWidth)
    }
    @MainActor static func id(for screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return screen.localizedName }
        let displayID = CGDirectDisplayID(number.uint32Value)
        if let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() { return CFUUIDCreateString(nil, uuid) as String }
        return number.stringValue
    }
}
