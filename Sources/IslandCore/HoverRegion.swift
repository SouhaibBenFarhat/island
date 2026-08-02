import CoreGraphics

/// Decides whether a hover-driven panel should stay open, from where the
/// pointer actually is.
///
/// The panels used to trust `mouseEntered`/`mouseExited` alone. Those go
/// missing whenever something moves under the pointer without it moving —
/// switching Space (an app going full screen), plugging or unplugging a
/// display, a window ordering out. A swallowed exit leaves the panel stuck
/// open, and a swallowed enter leaves it stuck shut. Checking the pointer's
/// real position can't get stuck either way.
public enum HoverRegion {
    /// How far outside a region still counts as "on it". Covers the gap
    /// between the island and the panel below it, so crossing that gap slowly
    /// doesn't dismiss the panel.
    public static let slack: CGFloat = 14

    /// True when a pointer at `point` should keep the panel open.
    ///
    /// - Parameters:
    ///   - anchor: the island itself.
    ///   - panel: the open panel, or nil when it isn't showing.
    public static func keepsOpen(
        point: CGPoint,
        anchor: CGRect,
        panel: CGRect?,
        slack: CGFloat = slack
    ) -> Bool {
        if contains(anchor, point, slack: slack) { return true }
        if let panel, contains(panel, point, slack: slack) { return true }
        return false
    }

    private static func contains(_ rect: CGRect, _ point: CGPoint, slack: CGFloat) -> Bool {
        guard !rect.isNull, !rect.isEmpty else { return false }
        return rect.insetBy(dx: -slack, dy: -slack).contains(point)
    }
}
