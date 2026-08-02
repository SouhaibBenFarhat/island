import Foundation

/// One entry on the island: the short label you see on the chip, and the text
/// it inserts into whatever input you were typing in.
public struct Snippet: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var label: String
    public var content: String
    /// Optional tint — a dot on the chip, and the fill of its flower petal.
    public var color: SnippetColor?

    public init(
        id: UUID = UUID(),
        label: String = "",
        content: String = "",
        color: SnippetColor? = nil
    ) {
        self.id = id
        self.label = label
        self.content = content
        self.color = color
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        label = try container.decodeIfPresent(String.self, forKey: .label) ?? ""
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        // A colour name this build doesn't know — a palette entry added later,
        // or a hand-edited file — leaves the item uncoloured rather than
        // failing the whole library.
        let name = try? container.decodeIfPresent(String.self, forKey: .color)
        color = name.flatMap { $0 }.flatMap(SnippetColor.init(rawValue:))
    }

    /// One or two letters for the flower petal, where there's no room for the
    /// whole label.
    public var initials: String {
        let words = displayLabel
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" })
            .prefix(2)
        let letters = words.compactMap { $0.first }
        if letters.isEmpty { return "?" }
        return String(letters).uppercased()
    }

    /// What the chip shows. Falls back to the first line of the content, so an
    /// item you never labelled is still readable instead of a blank chip.
    public var displayLabel: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return Snippet.truncated(trimmed, to: Snippet.labelLimit) }

        let firstLine = content
            .split(separator: "\n", omittingEmptySubsequences: false)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""

        return firstLine.isEmpty ? "Untitled" : Snippet.truncated(firstLine, to: Snippet.labelLimit)
    }

    /// True when there is nothing to insert — used to skip no-op chips.
    public var isEmpty: Bool {
        content.isEmpty
    }

    /// One-line version of the content for the hover list. Line breaks and runs
    /// of whitespace collapse to single spaces so every row is the same height.
    public var contentPreview: String {
        let collapsed = content
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return Snippet.truncated(collapsed, to: Snippet.previewLimit)
    }

    static let labelLimit = 28
    static let previewLimit = 42

    /// Shortens with an ellipsis so long labels can't stretch the island off
    /// the screen. Counts characters (grapheme clusters), so emoji stay whole.
    static func truncated(_ text: String, to limit: Int) -> String {
        guard limit > 0 else { return "" }
        guard text.count > limit else { return text }
        return String(text.prefix(limit - 1)) + "…"
    }
}
