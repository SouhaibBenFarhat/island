import CoreGraphics

/// Which way the flower opens, in AppKit angles: 0 points right, and the angle
/// grows counter-clockwise.
public struct RadialArc: Equatable, Sendable {
    public var start: CGFloat
    public var sweep: CGFloat

    public init(start: CGFloat, sweep: CGFloat) {
        self.start = start
        self.sweep = sweep
    }

    /// Petals all the way round, starting at the top.
    public static let fullCircle = RadialArc(start: .pi / 2, sweep: 2 * .pi)

    public var isFullCircle: Bool { sweep >= 2 * .pi - 0.0001 }
}

/// Geometry for the flower: circular quick-access buttons ringed around the
/// collapsed island.
public enum RadialLayout {
    public static let petalDiameter: CGFloat = 42
    /// Clear space between neighbouring petals.
    public static let petalGap: CGFloat = 8
    /// Never draw the ring tighter than this. Just clear of the collapsed
    /// pill's corners, so the petals sit close without touching it.
    public static let minimumRadius: CGFloat = 46

    /// How many petals the ring can carry before it stops being readable. Past
    /// this the last petal becomes an overflow that opens the full list, so a
    /// long library can't turn into an unusable wheel of tiny circles.
    public static let maximumPetals = 8

    /// Splits a library into the items that get their own petal and the count
    /// left over.
    public static func petalSplit(
        count: Int,
        maximum: Int = maximumPetals
    ) -> (shown: Int, overflow: Int) {
        guard maximum > 0 else { return (0, max(0, count)) }
        guard count > maximum else { return (max(0, count), 0) }
        let shown = maximum - 1
        return (shown, count - shown)
    }

    /// Radius that keeps `count` petals from touching along `arc`.
    public static func radius(
        count: Int,
        arc: RadialArc,
        petalDiameter: CGFloat = petalDiameter,
        gap: CGFloat = petalGap,
        minimum: CGFloat = minimumRadius
    ) -> CGFloat {
        guard count > 0, arc.sweep > 0 else { return minimum }
        // Arc length needed for the whole ring, spread over the sweep.
        let needed = CGFloat(count) * (petalDiameter + gap) / arc.sweep
        return max(minimum, needed)
    }

    /// Where each petal sits relative to the centre, in AppKit coordinates
    /// (y grows up).
    public static func offsets(count: Int, radius: CGFloat, arc: RadialArc) -> [CGPoint] {
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            // A full circle wraps, so the last petal must not land on the
            // first; a partial arc instead centres its petals inside the wedge.
            let step = arc.isFullCircle
                ? CGFloat(index) / CGFloat(count)
                : (CGFloat(index) + 0.5) / CGFloat(count)
            let angle = arc.start + arc.sweep * step
            return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
    }

    /// Which way to open, given how much room the island has around it.
    /// A full ring when there's space on every side, otherwise a half ring
    /// pointing at the roomiest direction.
    public static func arc(around frame: CGRect, in bounds: CGRect, reach: CGFloat) -> RadialArc {
        let up = bounds.maxY - frame.maxY
        let down = frame.minY - bounds.minY
        let left = frame.minX - bounds.minX
        let right = bounds.maxX - frame.maxX

        if min(min(up, down), min(left, right)) >= reach { return .fullCircle }

        let most = max(max(up, down), max(left, right))
        if most == right { return RadialArc(start: -.pi / 2, sweep: .pi) }
        if most == left { return RadialArc(start: .pi / 2, sweep: .pi) }
        if most == up { return RadialArc(start: 0, sweep: .pi) }
        return RadialArc(start: .pi, sweep: .pi)
    }

    /// A direction and a size, settled together.
    public struct Plan: Equatable, Sendable {
        public var arc: RadialArc
        public var radius: CGFloat

        public init(arc: RadialArc, radius: CGFloat) {
            self.arc = arc
            self.radius = radius
        }
    }

    /// Works out how the ring should open around `frame`.
    ///
    /// Direction and size depend on each other: the same petals spread over a
    /// half ring need twice the radius they need on a full one. Choosing the
    /// direction from the full-circle radius and *then* drawing the bigger half
    /// ring is how petals end up off the screen — the room was measured against
    /// a ring that was never drawn.
    ///
    /// So this tries each candidate at the size it would actually be drawn, and
    /// keeps whichever puts the most petals fully on screen. Ties go to the
    /// earlier candidate, and the candidates are ordered by preference: a full
    /// ring first, then the direction with the most room around the island.
    public static func plan(count: Int, around frame: CGRect, in bounds: CGRect) -> Plan {
        let full = radius(count: count, arc: .fullCircle)
        guard count > 0 else { return Plan(arc: .fullCircle, radius: full) }

        let preferred = arc(around: frame, in: bounds, reach: full + petalDiameter / 2)
        var candidates: [RadialArc] = [.fullCircle, preferred]
        candidates.append(contentsOf: [
            RadialArc(start: -.pi / 2, sweep: .pi), // opens right
            RadialArc(start: .pi / 2, sweep: .pi), // opens left
            RadialArc(start: 0, sweep: .pi), // opens up
            RadialArc(start: .pi, sweep: .pi), // opens down
        ])

        let centre = CGPoint(x: frame.midX, y: frame.midY)
        var best = Plan(arc: .fullCircle, radius: full)
        var bestOnScreen = -1

        for candidate in candidates {
            let candidateRadius = radius(count: count, arc: candidate)
            let onScreen = offsets(count: count, radius: candidateRadius, arc: candidate)
                .lazy
                .map { offset in
                    CGRect(
                        x: centre.x + offset.x - petalDiameter / 2,
                        y: centre.y + offset.y - petalDiameter / 2,
                        width: petalDiameter,
                        height: petalDiameter
                    )
                }
                .filter(bounds.contains)
                .count

            if onScreen > bestOnScreen {
                bestOnScreen = onScreen
                best = Plan(arc: candidate, radius: candidateRadius)
            }
            if onScreen == count { break } // Can't do better than all of them.
        }

        return best
    }

    /// Slack around the ring. A window clips its contents, and a petal is
    /// bigger than its circle: it carries a drop shadow and grows a little
    /// under the pointer. Without this the outer edge of every petal is cut.
    public static let panelBleed: CGFloat = 12

    /// Size of the window that has to hold the whole ring.
    public static func panelSize(
        radius: CGFloat,
        petalDiameter: CGFloat = petalDiameter,
        bleed: CGFloat = panelBleed
    ) -> CGSize {
        let side = (radius + petalDiameter / 2 + bleed) * 2
        return CGSize(width: side, height: side)
    }
}
