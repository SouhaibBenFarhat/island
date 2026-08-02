import XCTest
@testable import IslandCore

final class RadialLayoutTests: XCTestCase {
    private let screen = CGRect(x: 0, y: 0, width: 2560, height: 1410)
    private let pill = CGRect(x: 1260, y: 700, width: 41, height: 34)

    // MARK: - How many petals

    func testEverythingFitsUnderTheCap() {
        let split = RadialLayout.petalSplit(count: 5, maximum: 8)
        XCTAssertEqual(split.shown, 5)
        XCTAssertEqual(split.overflow, 0)
    }

    func testExactlyTheCapStillFits() {
        let split = RadialLayout.petalSplit(count: 8, maximum: 8)
        XCTAssertEqual(split.shown, 8)
        XCTAssertEqual(split.overflow, 0)
    }

    func testPastTheCapTheLastPetalBecomesOverflow() {
        // 20 items: 7 get a petal, the 8th petal stands for the other 13.
        let split = RadialLayout.petalSplit(count: 20, maximum: 8)
        XCTAssertEqual(split.shown, 7)
        XCTAssertEqual(split.overflow, 13)
        XCTAssertEqual(split.shown + split.overflow, 20, "every item is accounted for")
    }

    func testTheRingNeverGrowsPastTheCap() {
        for count in 1...200 {
            let split = RadialLayout.petalSplit(count: count)
            let drawn = split.shown + (split.overflow > 0 ? 1 : 0)
            XCTAssertLessThanOrEqual(drawn, RadialLayout.maximumPetals)
        }
    }

    func testEmptyLibrary() {
        let split = RadialLayout.petalSplit(count: 0)
        XCTAssertEqual(split.shown, 0)
        XCTAssertEqual(split.overflow, 0)
    }

    func testNonsenseMaximum() {
        let split = RadialLayout.petalSplit(count: 5, maximum: 0)
        XCTAssertEqual(split.shown, 0)
        XCTAssertEqual(split.overflow, 5)
    }

    // MARK: - Radius

    func testSmallRingUsesTheMinimumRadius() {
        let radius = RadialLayout.radius(count: 2, arc: .fullCircle)
        XCTAssertEqual(radius, RadialLayout.minimumRadius)
    }

    func testRadiusGrowsWithTheNumberOfPetals() {
        let small = RadialLayout.radius(count: 3, arc: .fullCircle)
        let large = RadialLayout.radius(count: 8, arc: .fullCircle)
        XCTAssertGreaterThan(large, small)
    }

    func testAHalfRingNeedsMoreRoomThanAFullOne() {
        let full = RadialLayout.radius(count: 8, arc: .fullCircle)
        let half = RadialLayout.radius(count: 8, arc: RadialArc(start: 0, sweep: .pi))
        XCTAssertGreaterThan(half, full)
    }

    func testPetalsNeverOverlap() {
        for count in 1...RadialLayout.maximumPetals {
            let arc = RadialArc.fullCircle
            let radius = RadialLayout.radius(count: count, arc: arc)
            let points = RadialLayout.offsets(count: count, radius: radius, arc: arc)
            guard count > 1 else { continue }
            for (index, point) in points.enumerated() {
                let next = points[(index + 1) % points.count]
                let gap = hypot(next.x - point.x, next.y - point.y)
                XCTAssertGreaterThanOrEqual(
                    gap, RadialLayout.petalDiameter,
                    "petals \(index) and \(index + 1) of \(count) overlap"
                )
            }
        }
    }

    func testZeroCountFallsBackToTheMinimum() {
        XCTAssertEqual(RadialLayout.radius(count: 0, arc: .fullCircle), RadialLayout.minimumRadius)
    }

    // MARK: - Offsets

    func testNoPetalsNoOffsets() {
        XCTAssertTrue(RadialLayout.offsets(count: 0, radius: 60, arc: .fullCircle).isEmpty)
    }

    func testEveryPetalSitsOnTheCircle() {
        let points = RadialLayout.offsets(count: 6, radius: 80, arc: .fullCircle)
        XCTAssertEqual(points.count, 6)
        for point in points {
            XCTAssertEqual(hypot(point.x, point.y), 80, accuracy: 0.0001)
        }
    }

    func testAFullCircleDoesNotPutTheLastPetalOnTheFirst() {
        let points = RadialLayout.offsets(count: 4, radius: 80, arc: .fullCircle)
        let first = points[0]
        let last = points[3]
        XCTAssertGreaterThan(hypot(last.x - first.x, last.y - first.y), 1)
    }

    func testFullCircleStartsAtTheTop() {
        let points = RadialLayout.offsets(count: 4, radius: 80, arc: .fullCircle)
        XCTAssertEqual(points[0].x, 0, accuracy: 0.0001)
        XCTAssertEqual(points[0].y, 80, accuracy: 0.0001)
    }

    func testASinglePetalOnAnArcSitsInTheMiddleOfIt() {
        // Arc pointing right: -90°…+90°, so the middle is straight right.
        let arc = RadialArc(start: -.pi / 2, sweep: .pi)
        let points = RadialLayout.offsets(count: 1, radius: 70, arc: arc)
        XCTAssertEqual(points[0].x, 70, accuracy: 0.0001)
        XCTAssertEqual(points[0].y, 0, accuracy: 0.0001)
    }

    func testArcPetalsStayWithinTheWedge() {
        let arc = RadialArc(start: 0, sweep: .pi) // upper half
        for point in RadialLayout.offsets(count: 5, radius: 70, arc: arc) {
            XCTAssertGreaterThanOrEqual(point.y, -0.0001, "a petal escaped below the arc")
        }
    }

    // MARK: - Which way it opens

    func testPlentyOfRoomGivesAFullRing() {
        XCTAssertEqual(RadialLayout.arc(around: pill, in: screen, reach: 120), .fullCircle)
    }

    func testNearTheTopItOpensDownwards() {
        let nearTop = CGRect(x: 1260, y: screen.maxY - 40, width: 41, height: 34)
        let arc = RadialLayout.arc(around: nearTop, in: screen, reach: 120)
        // Straight down is -y.
        let point = RadialLayout.offsets(count: 1, radius: 70, arc: arc)[0]
        XCTAssertLessThan(point.y, 0)
    }

    func testNearTheBottomItOpensUpwards() {
        let nearBottom = CGRect(x: 1260, y: 6, width: 41, height: 34)
        let arc = RadialLayout.arc(around: nearBottom, in: screen, reach: 120)
        XCTAssertGreaterThan(RadialLayout.offsets(count: 1, radius: 70, arc: arc)[0].y, 0)
    }

    func testNearTheRightEdgeItOpensLeftwards() {
        let nearRight = CGRect(x: screen.maxX - 50, y: 700, width: 41, height: 34)
        let arc = RadialLayout.arc(around: nearRight, in: screen, reach: 120)
        XCTAssertLessThan(RadialLayout.offsets(count: 1, radius: 70, arc: arc)[0].x, 0)
    }

    func testNearTheLeftEdgeItOpensRightwards() {
        let nearLeft = CGRect(x: 8, y: 700, width: 41, height: 34)
        let arc = RadialLayout.arc(around: nearLeft, in: screen, reach: 120)
        XCTAssertGreaterThan(RadialLayout.offsets(count: 1, radius: 70, arc: arc)[0].x, 0)
    }

    func testAHalfRingIsNotAFullOne() {
        let nearTop = CGRect(x: 1260, y: screen.maxY - 40, width: 41, height: 34)
        XCTAssertFalse(RadialLayout.arc(around: nearTop, in: screen, reach: 120).isFullCircle)
        XCTAssertTrue(RadialArc.fullCircle.isFullCircle)
    }

    // MARK: - Panel size

    func testPanelIsSquareAndHoldsTheWholeRing() {
        let size = RadialLayout.panelSize(radius: 80)
        XCTAssertEqual(size.width, size.height)
        XCTAssertEqual(
            size.width,
            (80 + RadialLayout.petalDiameter / 2 + RadialLayout.panelBleed) * 2
        )
    }

    func testPanelLeavesRoomForShadowsAndTheHoverGrow() {
        // Sized to the ring alone, the outer edge of every petal gets clipped.
        let ringOnly = (80 + RadialLayout.petalDiameter / 2) * 2
        XCTAssertGreaterThan(RadialLayout.panelSize(radius: 80).width, ringOnly)
    }
}
