import AppKit
import SwiftUI
import IslandCore

/// Shared look of the island: flat surfaces, hairline rules, one warm accent.
/// No gradients, no glows — it should read like a well-set page, not a toy.
enum Theme {
    static let barHeight: CGFloat = 44
    static let barCornerRadius: CGFloat = 14
    static let chipCornerRadius: CGFloat = 7
    static let barPadding: CGFloat = 7
    static let itemSpacing: CGFloat = 5

    /// How many chips fit on the bar before the rest move into the overflow
    /// menu. Keeps the island from growing wider than the screen.
    static let maximumVisibleChips = 10

    /// Terracotta. Used sparingly — a confirmation tick, a warning, nothing else.
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.87, green: 0.54, blue: 0.37, alpha: 1)
            : NSColor(srgbRed: 0.70, green: 0.32, blue: 0.17, alpha: 1)
    })

    static let hairline = Color.primary.opacity(0.10)
    static let chipRest = Color.primary.opacity(0.055)
    static let chipHover = Color.primary.opacity(0.11)
}

/// The island's background: a material panel with a hairline edge.
struct IslandSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.barCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.barCornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func islandSurface() -> some View { modifier(IslandSurface()) }
}

extension NSColor {
    convenience init(_ rgb: RGB) {
        self.init(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }
}

extension Color {
    init(_ rgb: RGB) {
        self.init(nsColor: NSColor(rgb))
    }
}

extension SnippetColor {
    /// Petal fill — always the full-strength tone, so white text reads on it in
    /// either appearance.
    var fill: Color { Color(solid) }

    /// The dot on a chip, which sits on the window background and so has to
    /// change with the appearance.
    var dot: Color {
        Color(nsColor: NSColor(name: nil) { [solid, light] appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(light)
                : NSColor(solid)
        })
    }
}

/// What an item with no colour set looks like.
enum NeutralSwatch {
    static let fill = Color(white: 0.36)
    static let dot = Color.primary.opacity(0.28)
}

/// The app mark: the island bar, and under it the two lines of text it feeds.
struct IslandMark: View {
    var width: CGFloat = 19
    var opacity: Double = 0.82

    var body: some View {
        VStack(alignment: .leading, spacing: width * 0.115) {
            Capsule(style: .continuous).frame(width: width, height: width * 0.42)
            Capsule(style: .continuous).frame(width: width, height: width * 0.11)
            Capsule(style: .continuous).frame(width: width * 0.62, height: width * 0.11)
        }
        .foregroundStyle(Color.primary.opacity(opacity))
    }
}
