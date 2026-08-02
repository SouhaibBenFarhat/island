import XCTest
@testable import IslandCore

final class HoverRegionTests: XCTestCase {
    /// The collapsed pill.
    private let anchor = CGRect(x: 500, y: 800, width: 41, height: 34)
    /// The drop-down under it, with the 8pt gap the app uses.
    private let panel = CGRect(x: 500, y: 634, width: 272, height: 158)

    private func keepsOpen(_ x: CGFloat, _ y: CGFloat, panel: CGRect? = nil) -> Bool {
        HoverRegion.keepsOpen(point: CGPoint(x: x, y: y), anchor: anchor, panel: panel)
    }

    func testOnTheIsland() {
        XCTAssertTrue(keepsOpen(anchor.midX, anchor.midY))
    }

    func testOnThePanel() {
        XCTAssertTrue(keepsOpen(panel.midX, panel.midY, panel: panel))
    }

    func testInTheGapBetweenThem() {
        // Crossing from the pill to the list passes through 8pt of nothing.
        // Losing the panel there would make it impossible to reach.
        let gapY = (anchor.minY + panel.maxY) / 2
        XCTAssertTrue(keepsOpen(anchor.midX, gapY, panel: panel))
    }

    func testWellAwayFromBoth() {
        XCTAssertFalse(keepsOpen(50, 50, panel: panel))
    }

    func testJustOutsideTheSlack() {
        XCTAssertFalse(keepsOpen(anchor.midX, anchor.maxY + HoverRegion.slack + 1))
    }

    func testJustInsideTheSlack() {
        XCTAssertTrue(keepsOpen(anchor.midX, anchor.maxY + HoverRegion.slack - 1))
    }

    func testWithNoPanelOnlyTheIslandCounts() {
        XCTAssertTrue(keepsOpen(anchor.midX, anchor.midY, panel: nil))
        XCTAssertFalse(keepsOpen(panel.midX, panel.midY, panel: nil))
    }

    func testCornersOfTheAnchor() {
        XCTAssertTrue(keepsOpen(anchor.minX, anchor.minY))
        XCTAssertTrue(keepsOpen(anchor.maxX, anchor.maxY))
    }

    func testAnEmptyOrNullRectNeverKeepsItOpen() {
        XCTAssertFalse(
            HoverRegion.keepsOpen(point: .zero, anchor: .zero, panel: nil)
        )
        XCTAssertFalse(
            HoverRegion.keepsOpen(point: CGPoint(x: 10, y: 10), anchor: .null, panel: .null)
        )
    }

    func testSlackIsWiderThanTheGapTheAppLeaves() {
        // The list sits 8pt below the island; the flower's own window covers
        // its gap. If slack ever drops below that the panel becomes unreachable.
        XCTAssertGreaterThan(HoverRegion.slack, 8)
    }

    func testAZeroSlackStillMatchesInsideTheRects() {
        XCTAssertTrue(
            HoverRegion.keepsOpen(
                point: CGPoint(x: anchor.midX, y: anchor.midY),
                anchor: anchor,
                panel: nil,
                slack: 0
            )
        )
        XCTAssertFalse(
            HoverRegion.keepsOpen(
                point: CGPoint(x: anchor.maxX + 1, y: anchor.midY),
                anchor: anchor,
                panel: nil,
                slack: 0
            )
        )
    }

    func testTheFlowerCaseWhereThePanelSurroundsTheIsland() {
        // The ring's window is centred on the pill, so the pill sits inside it.
        let ring = CGRect(x: anchor.midX - 79, y: anchor.midY - 79, width: 158, height: 158)
        XCTAssertTrue(keepsOpen(anchor.midX, anchor.midY, panel: ring))
        XCTAssertTrue(keepsOpen(ring.minX + 4, ring.midY, panel: ring))
        XCTAssertFalse(keepsOpen(ring.minX - HoverRegion.slack - 5, ring.midY, panel: ring))
    }
}
