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

    // MARK: - plan: direction and size chosen together

    /// Every petal the plan produces, as a rect on screen.
    private func petalRects(_ plan: RadialLayout.Plan, count: Int, around frame: CGRect) -> [CGRect] {
        let centre = CGPoint(x: frame.midX, y: frame.midY)
        return RadialLayout.offsets(count: count, radius: plan.radius, arc: plan.arc).map { offset in
            CGRect(
                x: centre.x + offset.x - RadialLayout.petalDiameter / 2,
                y: centre.y + offset.y - RadialLayout.petalDiameter / 2,
                width: RadialLayout.petalDiameter,
                height: RadialLayout.petalDiameter
            )
        }
    }

    func testPlanInTheMiddleOfAScreenIsAFullRing() {
        let plan = RadialLayout.plan(count: 6, around: pill, in: screen)
        XCTAssertTrue(plan.arc.isFullCircle)
        XCTAssertEqual(plan.radius, RadialLayout.radius(count: 6, arc: .fullCircle))
    }

    func testPlanKeepsEveryPetalOnScreenNearAnEdge() {
        let nearTop = CGRect(x: 1260, y: screen.maxY - 40, width: 41, height: 34)
        let plan = RadialLayout.plan(count: 6, around: nearTop, in: screen)
        for rect in petalRects(plan, count: 6, around: nearTop) {
            XCTAssertTrue(screen.contains(rect), "petal \(rect) escaped the screen")
        }
    }

    /// The regression: the direction used to be chosen against the full-circle
    /// radius, then the ring was drawn at the much larger half-ring radius, so
    /// petals landed off the screen in the direction that was meant to have room.
    func testPlanSizesTheRingItActuallyDraws() {
        let nearTop = CGRect(x: 1260, y: screen.maxY - 40, width: 41, height: 34)
        let count = 8

        let oldFullRadius = RadialLayout.radius(count: count, arc: .fullCircle)
        let oldArc = RadialLayout.arc(
            around: nearTop, in: screen, reach: oldFullRadius + RadialLayout.petalDiameter / 2
        )
        let oldPlan = RadialLayout.Plan(
            arc: oldArc,
            radius: RadialLayout.radius(count: count, arc: oldArc)
        )
        let newPlan = RadialLayout.plan(count: count, around: nearTop, in: screen)

        let oldOnScreen = petalRects(oldPlan, count: count, around: nearTop).filter(screen.contains).count
        let newOnScreen = petalRects(newPlan, count: count, around: nearTop).filter(screen.contains).count
        XCTAssertGreaterThanOrEqual(newOnScreen, oldOnScreen)
    }

    func testPlanIsAtLeastAsGoodAsAnySingleCandidateEverywhere() {
        let candidates: [RadialArc] = [
            .fullCircle,
            RadialArc(start: -.pi / 2, sweep: .pi),
            RadialArc(start: .pi / 2, sweep: .pi),
            RadialArc(start: 0, sweep: .pi),
            RadialArc(start: .pi, sweep: .pi),
        ]

        for count in [1, 3, 6, 8] {
            for x in stride(from: CGFloat(4), through: screen.maxX - 45, by: 505) {
                for y in stride(from: CGFloat(4), through: screen.maxY - 38, by: 340) {
                    let frame = CGRect(x: x, y: y, width: 41, height: 34)
                    let chosen = RadialLayout.plan(count: count, around: frame, in: screen)
                    let chosenOnScreen = petalRects(chosen, count: count, around: frame)
                        .filter(screen.contains).count

                    for candidate in candidates {
                        let rival = RadialLayout.Plan(
                            arc: candidate,
                            radius: RadialLayout.radius(count: count, arc: candidate)
                        )
                        let rivalOnScreen = petalRects(rival, count: count, around: frame)
                            .filter(screen.contains).count
                        XCTAssertGreaterThanOrEqual(
                            chosenOnScreen, rivalOnScreen,
                            "at \(frame.origin) with \(count) petals a different arc did better"
                        )
                    }
                }
            }
        }
    }

    func testPlanWithNoPetals() {
        let plan = RadialLayout.plan(count: 0, around: pill, in: screen)
        XCTAssertEqual(plan.radius, RadialLayout.minimumRadius)
    }

    func testPlanOnATinyScreenStillReturnsSomething() {
        let tiny = CGRect(x: 0, y: 0, width: 200, height: 150)
        let plan = RadialLayout.plan(count: 8, around: CGRect(x: 80, y: 60, width: 41, height: 34), in: tiny)
        XCTAssertGreaterThan(plan.radius, 0)
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
