import Foundation

/// One entry on the island: the short label you see on the chip, and the text
/// it inserts into whatever input you were typing in.
public struct Snippet: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var label: String
    public var content: String

    public init(id: UUID = UUID(), label: String = "", content: String = "") {
        self.id = id
        self.label = label
        self.content = content
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
