import CoreGraphics

/// Geometry for the floating panel, in AppKit screen coordinates
/// (origin bottom-left, y grows upward).
public enum PanelPlacement {
    /// Gap between the island and the screen edge it starts against.
    public static let defaultTopInset: CGFloat = 14

    /// Moves `frame` so it sits fully inside `bounds`. Never resizes: if the
    /// island is wider or taller than the screen it is pinned to the top-left
    /// corner and allowed to overhang, which beats silently shrinking it.
    public static func clamp(_ frame: CGRect, into bounds: CGRect) -> CGRect {
        var result = frame

        if result.width >= bounds.width {
            result.origin.x = bounds.minX
        } else {
            result.origin.x = min(max(result.minX, bounds.minX), bounds.maxX - result.width)
        }

        if result.height >= bounds.height {
            result.origin.y = bounds.maxY - result.height
        } else {
            result.origin.y = min(max(result.minY, bounds.minY), bounds.maxY - result.height)
        }

        return result
    }

    /// Where a first-run island appears: centred horizontally, just under the
    /// top of the usable screen area (below the menu bar and the notch).
    public static func defaultOrigin(
        for size: CGSize,
        in bounds: CGRect,
        topInset: CGFloat = defaultTopInset
    ) -> CGPoint {
        let x = bounds.midX - size.width / 2
        let y = bounds.maxY - size.height - topInset
        return clamp(CGRect(origin: CGPoint(x: x, y: y), size: size), into: bounds).origin
    }

    /// Whether a remembered position is still usable. Unplugging the external
    /// display the island lived on would otherwise hide it forever.
    public static func isReasonablyVisible(
        _ frame: CGRect,
        in bounds: CGRect,
        minimumVisibleFraction: CGFloat = 0.5
    ) -> Bool {
        let area = frame.width * frame.height
        guard area > 0 else { return false }
        let visible = frame.intersection(bounds)
        guard !visible.isNull else { return false }
        return (visible.width * visible.height) / area >= minimumVisibleFraction
    }

    /// The screen a frame sits on: whichever it overlaps most. Nil when it
    /// overlaps none of them, which is what an unplugged display looks like.
    public static func bestScreen(for frame: CGRect, among screens: [CGRect]) -> CGRect? {
        var best: CGRect?
        var bestArea: CGFloat = 0
        for screen in screens {
            let overlap = frame.intersection(screen)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            if area > bestArea {
                bestArea = area
                best = screen
            }
        }
        return best
    }

    /// The frame to actually use, considering every connected display.
    ///
    /// A position saved on a second monitor has to be checked against that
    /// monitor, not the main one — otherwise every relaunch drags the island
    /// back to the built-in screen.
    public static func resolveFrame(
        savedOrigin: CGPoint?,
        size: CGSize,
        screens: [CGRect],
        preferred: CGRect,
        topInset: CGFloat = defaultTopInset
    ) -> CGRect {
        if let savedOrigin {
            let saved = CGRect(origin: savedOrigin, size: size)
            if let screen = bestScreen(for: saved, among: screens),
               isReasonablyVisible(saved, in: screen) {
                return clamp(saved, into: screen)
            }
        }
        return CGRect(origin: defaultOrigin(for: size, in: preferred, topInset: topInset), size: size)
    }

    /// Single-screen convenience.
    public static func resolveFrame(
        savedOrigin: CGPoint?,
        size: CGSize,
        in bounds: CGRect,
        topInset: CGFloat = defaultTopInset
    ) -> CGRect {
        resolveFrame(
            savedOrigin: savedOrigin,
            size: size,
            screens: [bounds],
            preferred: bounds,
            topInset: topInset
        )
    }
}
