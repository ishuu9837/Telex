import XCTest
import SwiftUI
@testable import Telex

final class DisplayGeometryServiceTests: XCTestCase {
    let frame = CGRect(x: 0, y: 0, width: 1512, height: 982)
    func testDockedShapeCoversUpperSidesWithoutSteppedShoulders() {
        let path = NotchExtensionShape(floating: false, safeTop: 38).path(in: CGRect(x: 0, y: 0, width: 400, height: 140))
        XCTAssertTrue(path.contains(CGPoint(x: 30, y: 5)))
        XCTAssertTrue(path.contains(CGPoint(x: 370, y: 5)))
        XCTAssertTrue(path.contains(CGPoint(x: 200, y: 5)))
        XCTAssertTrue(path.contains(CGPoint(x: 200, y: 100)))
    }
    func testPanelHasStraightSidesAndOnlyBottomRoundedCorners() {
        let rect = CGRect(x: 0, y: 0, width: 420, height: 160)
        for floating in [true, false] {
            let path = NotchExtensionShape(floating: floating, safeTop: 38).path(in: rect)
            var curves = 0
            path.forEach { element in
                switch element { case .quadCurve, .curve: curves += 1; default: break }
            }
            XCTAssertFalse(path.contains(CGPoint(x: 0.1, y: 159.9)))
            XCTAssertFalse(path.contains(CGPoint(x: 419.9, y: 159.9)))
            XCTAssertEqual(curves, 2); XCTAssertEqual(path.boundingRect, rect)
            for point in [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 419.9, y: 0.1), CGPoint(x: 0.1, y: 80), CGPoint(x: 419.9, y: 80)] { XCTAssertTrue(path.contains(point)) }
        }
    }
    func testNotchCannotBeNarrowerThanPhysicalHardware() {
        let metrics = DisplayMetrics(frame: frame, visibleFrame: frame, safeTop: 38, notchWidth: 300)
        let result = DisplayGeometryService.dockedFrame(metrics: metrics, size: CGSize(width: 210, height: 140))
        XCTAssertEqual(result.width, 344)
    }
    func testNotchAlignsWithPhysicalTop() {
        let metrics = DisplayMetrics(frame: frame, visibleFrame: CGRect(x: 0, y: 40, width: 1512, height: 904), safeTop: 38, notchWidth: 204)
        let result = DisplayGeometryService.dockedFrame(metrics: metrics, size: CGSize(width: 248, height: 160))
        XCTAssertEqual(result.maxY, frame.maxY); XCTAssertEqual(result.midX, frame.midX)
        XCTAssertEqual(result.width, 248)
    }
    func testExternalDisplayUsesVisibleTopAndNegativeOrigin() {
        let external = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let metrics = DisplayMetrics(frame: external, visibleFrame: CGRect(x: -1920, y: 0, width: 1920, height: 1055), safeTop: 0, notchWidth: 0)
        let result = DisplayGeometryService.dockedFrame(metrics: metrics, size: CGSize(width: 300, height: 160))
        XCTAssertEqual(result.maxY, 1055); XCTAssertEqual(result.midX, -960)
    }
    func testWorkspaceMovesBelowCapsuleAndPreservesAvailableSpace() {
        let bounds = CGRect(x: 0, y: 40, width: 1512, height: 904)
        let capsule = CGRect(x: 600, y: 822, width: 300, height: 160)
        let workspace = CGRect(x: 140, y: 180, width: 1220, height: 780)
        let adjusted = DisplayGeometryService.workspaceFrame(workspace, avoiding: capsule, within: bounds)
        XCTAssertLessThan(adjusted.maxY, capsule.minY)
        XCTAssertTrue(bounds.contains(adjusted))
        XCTAssertFalse(adjusted.intersects(capsule))
    }
    func testClampingRecoversDisconnectedMonitorFrame() {
        let result = DisplayGeometryService.clamp(CGRect(x: 4000, y: -1000, width: 840, height: 520), to: frame)
        XCTAssertTrue(frame.contains(result))
        let oversized = DisplayGeometryService.clamp(CGRect(x: -10, y: -20, width: 9000, height: 8000), to: frame)
        XCTAssertEqual(oversized, frame)
    }
}
