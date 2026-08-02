import XCTest
@testable import IslandCore

final class PanelPlacementTests: XCTestCase {
    /// A 1440×900 screen with the menu bar taken off the top.
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 875)
    private let barSize = CGSize(width: 320, height: 44)

    // MARK: - clamp

    func testFrameAlreadyInsideIsUnchanged() {
        let frame = CGRect(x: 100, y: 100, width: 320, height: 44)
        XCTAssertEqual(PanelPlacement.clamp(frame, into: screen), frame)
    }

    func testPullsBackFromTheRightEdge() {
        let frame = CGRect(x: 1400, y: 100, width: 320, height: 44)
        XCTAssertEqual(PanelPlacement.clamp(frame, into: screen).maxX, screen.maxX)
    }

    func testPullsBackFromTheLeftEdge() {
        let frame = CGRect(x: -80, y: 100, width: 320, height: 44)
        XCTAssertEqual(PanelPlacement.clamp(frame, into: screen).minX, screen.minX)
    }

    func testPullsBackFromTheTopAndBottom() {
        XCTAssertEqual(
            PanelPlacement.clamp(CGRect(x: 0, y: 900, width: 320, height: 44), into: screen).maxY,
            screen.maxY
        )
        XCTAssertEqual(
            PanelPlacement.clamp(CGRect(x: 0, y: -50, width: 320, height: 44), into: screen).minY,
            screen.minY
        )
    }

    func testClampingNeverChangesTheSize() {
        let frame = CGRect(x: 5_000, y: -5_000, width: 320, height: 44)
        XCTAssertEqual(PanelPlacement.clamp(frame, into: screen).size, frame.size)
    }

    func testAnOversizedBarIsPinnedToTheTopLeftInsteadOfShrunk() {
        let frame = CGRect(x: 50, y: 50, width: 2_000, height: 44)
        let clamped = PanelPlacement.clamp(frame, into: screen)
        XCTAssertEqual(clamped.minX, screen.minX)
        XCTAssertEqual(clamped.width, 2_000)
    }

    func testClampRespectsScreensThatDoNotStartAtZero() {
        // A second display to the left of the built-in one.
        let secondary = CGRect(x: -1_920, y: 0, width: 1_920, height: 1_080)
        let frame = CGRect(x: -2_500, y: 100, width: 320, height: 44)
        XCTAssertEqual(PanelPlacement.clamp(frame, into: secondary).minX, secondary.minX)
    }

    // MARK: - defaultOrigin

    func testDefaultOriginIsCentredNearTheTop() {
        let origin = PanelPlacement.defaultOrigin(for: barSize, in: screen)
        XCTAssertEqual(origin.x, screen.midX - barSize.width / 2)
        XCTAssertEqual(origin.y, screen.maxY - barSize.height - PanelPlacement.defaultTopInset)
    }

    func testDefaultOriginStaysOnScreen() {
        let huge = CGSize(width: 4_000, height: 44)
        let origin = PanelPlacement.defaultOrigin(for: huge, in: screen)
        XCTAssertEqual(origin.x, screen.minX)
    }

    // MARK: - visibility

    func testFullyVisibleFrameIsVisible() {
        XCTAssertTrue(
            PanelPlacement.isReasonablyVisible(CGRect(x: 10, y: 10, width: 320, height: 44), in: screen)
        )
    }

    func testFrameOnADisconnectedDisplayIsNotVisible() {
        let onOldExternalDisplay = CGRect(x: 3_000, y: 1_500, width: 320, height: 44)
        XCTAssertFalse(PanelPlacement.isReasonablyVisible(onOldExternalDisplay, in: screen))
    }

    func testMostlyOffScreenCountsAsNotVisible() {
        // 80 of 320 points showing — a quarter, below the half we ask for.
        let frame = CGRect(x: screen.maxX - 80, y: 100, width: 320, height: 44)
        XCTAssertFalse(PanelPlacement.isReasonablyVisible(frame, in: screen))
    }

    func testZeroSizedFrameIsNotVisible() {
        XCTAssertFalse(PanelPlacement.isReasonablyVisible(.zero, in: screen))
    }

    // MARK: - resolveFrame

    func testResolveUsesTheSavedPositionWhenItStillFits() {
        let saved = CGPoint(x: 200, y: 400)
        let frame = PanelPlacement.resolveFrame(savedOrigin: saved, size: barSize, in: screen)
        XCTAssertEqual(frame.origin, saved)
        XCTAssertEqual(frame.size, barSize)
    }

    func testResolveFallsBackToTheDefaultWhenTheSavedScreenIsGone() {
        let frame = PanelPlacement.resolveFrame(
            savedOrigin: CGPoint(x: 3_000, y: 1_500),
            size: barSize,
            in: screen
        )
        XCTAssertEqual(frame.origin, PanelPlacement.defaultOrigin(for: barSize, in: screen))
    }

    func testResolveWithNoSavedPositionUsesTheDefault() {
        let frame = PanelPlacement.resolveFrame(savedOrigin: nil, size: barSize, in: screen)
        XCTAssertEqual(frame.origin, PanelPlacement.defaultOrigin(for: barSize, in: screen))
    }

    func testResolveNudgesASlightlyOverhangingBarBackOn() {
        // Mostly visible, so it is kept — but pulled fully inside.
        let saved = CGPoint(x: screen.maxX - 200, y: 100)
        let frame = PanelPlacement.resolveFrame(savedOrigin: saved, size: barSize, in: screen)
        XCTAssertEqual(frame.maxX, screen.maxX)
        XCTAssertEqual(frame.minY, 100)
    }
}
