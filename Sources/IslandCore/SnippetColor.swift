import Foundation

/// A colour channel triple, 0...1. Core has no AppKit, so it hands the app
/// numbers and lets it build the platform colour.
public struct RGB: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(_ red: Double, _ green: Double, _ blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// From a 0xRRGGBB literal, which is how the palette below reads best.
    public init(hex: UInt32) {
        self.init(
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255
        )
    }
}

/// The colour you can pin to an item.
///
/// A fixed palette rather than a free colour well: eight muted, print-ish tones
/// that sit together without any one of them shouting. `solid` is dark enough
/// to carry white text, which is what the flower petals need.
public enum SnippetColor: String, Codable, CaseIterable, Sendable {
    case terracotta
    case amber
    case olive
    case teal
    case slate
    case indigo
    case plum
    case rose

    public var title: String {
        switch self {
        case .terracotta: return "Terracotta"
        case .amber: return "Amber"
        case .olive: return "Olive"
        case .teal: return "Teal"
        case .slate: return "Slate"
        case .indigo: return "Indigo"
        case .plum: return "Plum"
        case .rose: return "Rose"
        }
    }

    /// Full-strength fill — petals, and the dot on a light background.
    public var solid: RGB {
        switch self {
        case .terracotta: return RGB(hex: 0xB4552E)
        case .amber: return RGB(hex: 0xB8862B)
        case .olive: return RGB(hex: 0x6E7F3F)
        case .teal: return RGB(hex: 0x2F7069)
        case .slate: return RGB(hex: 0x4A5B6E)
        case .indigo: return RGB(hex: 0x4C4A8C)
        case .plum: return RGB(hex: 0x7A3F63)
        case .rose: return RGB(hex: 0xA8434F)
        }
    }

    /// Lifted variant, for dots sitting on a dark background.
    public var light: RGB {
        switch self {
        case .terracotta: return RGB(hex: 0xE08B5E)
        case .amber: return RGB(hex: 0xE0B45E)
        case .olive: return RGB(hex: 0xA8BC76)
        case .teal: return RGB(hex: 0x6FB3AA)
        case .slate: return RGB(hex: 0x8CA3B8)
        case .indigo: return RGB(hex: 0x9A97D6)
        case .plum: return RGB(hex: 0xC186A8)
        case .rose: return RGB(hex: 0xE08691)
        }
    }
}
