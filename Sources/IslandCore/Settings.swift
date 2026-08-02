import Foundation

/// How the snippet text reaches the app you were typing in.
public enum InsertMethod: String, Codable, CaseIterable, Sendable {
    /// Put the text on the clipboard, press ⌘V, then put the old clipboard back.
    /// Fast and works everywhere, including Electron apps.
    case paste
    /// Send the text as key events. Slower, but never touches the clipboard.
    case type

    public var title: String {
        switch self {
        case .paste: return "Paste (⌘V)"
        case .type: return "Type character by character"
        }
    }
}

/// User preferences plus the bits of window state we want back after a restart.
///
/// Decoding fills in defaults for anything missing, so an older settings file
/// (or a hand-edited one) still loads instead of resetting everything.
public struct Settings: Codable, Equatable, Sendable {
    public var insertMethod: InsertMethod
    public var expandPlaceholders: Bool
    public var isIslandVisible: Bool
    public var isCollapsed: Bool
    /// Bottom-left corner of the panel in screen points, nil until first move.
    public var panelOriginX: Double?
    public var panelOriginY: Double?

    public init(
        insertMethod: InsertMethod = .paste,
        expandPlaceholders: Bool = true,
        isIslandVisible: Bool = true,
        isCollapsed: Bool = false,
        panelOriginX: Double? = nil,
        panelOriginY: Double? = nil
    ) {
        self.insertMethod = insertMethod
        self.expandPlaceholders = expandPlaceholders
        self.isIslandVisible = isIslandVisible
        self.isCollapsed = isCollapsed
        self.panelOriginX = panelOriginX
        self.panelOriginY = panelOriginY
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Settings()
        self.insertMethod = try container.decodeIfPresent(InsertMethod.self, forKey: .insertMethod)
            ?? defaults.insertMethod
        self.expandPlaceholders = try container.decodeIfPresent(Bool.self, forKey: .expandPlaceholders)
            ?? defaults.expandPlaceholders
        self.isIslandVisible = try container.decodeIfPresent(Bool.self, forKey: .isIslandVisible)
            ?? defaults.isIslandVisible
        self.isCollapsed = try container.decodeIfPresent(Bool.self, forKey: .isCollapsed)
            ?? defaults.isCollapsed
        self.panelOriginX = try container.decodeIfPresent(Double.self, forKey: .panelOriginX)
        self.panelOriginY = try container.decodeIfPresent(Double.self, forKey: .panelOriginY)
    }

    /// Both coordinates or nothing — half a saved position is no position.
    public var panelOrigin: CGPoint? {
        get {
            guard let x = panelOriginX, let y = panelOriginY else { return nil }
            return CGPoint(x: x, y: y)
        }
        set {
            panelOriginX = newValue.map { Double($0.x) }
            panelOriginY = newValue.map { Double($0.y) }
        }
    }
}
