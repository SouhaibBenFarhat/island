import Foundation

/// The ordered list of snippets shown on the island.
///
/// Every mutation is total: bad indexes and unknown ids are ignored rather than
/// trapping, because the UI can hand us a stale id right after a delete.
public struct SnippetLibrary: Codable, Equatable, Sendable {
    public private(set) var snippets: [Snippet]

    public init(snippets: [Snippet] = []) {
        self.snippets = snippets
    }

    public var count: Int { snippets.count }
    public var isEmpty: Bool { snippets.isEmpty }

    public subscript(id: Snippet.ID) -> Snippet? {
        snippets.first { $0.id == id }
    }

    public func index(of id: Snippet.ID) -> Int? {
        snippets.firstIndex { $0.id == id }
    }

    /// Adds at the end. Ids are unique, so re-adding an existing one updates it.
    @discardableResult
    public mutating func append(_ snippet: Snippet) -> Snippet {
        if let existing = index(of: snippet.id) {
            snippets[existing] = snippet
        } else {
            snippets.append(snippet)
        }
        return snippet
    }

    /// Replaces an existing snippet. Unknown ids are ignored.
    public mutating func update(_ snippet: Snippet) {
        guard let index = index(of: snippet.id) else { return }
        snippets[index] = snippet
    }

    public mutating func remove(id: Snippet.ID) {
        snippets.removeAll { $0.id == id }
    }

    /// Moves one snippet so that it ends up at `destination` in the new array.
    /// Both indexes are clamped, so a drag past either end just parks it there.
    public mutating func move(from source: Int, to destination: Int) {
        guard !snippets.isEmpty else { return }
        let from = min(max(source, 0), snippets.count - 1)
        let to = min(max(destination, 0), snippets.count - 1)
        guard from != to else { return }
        let moved = snippets.remove(at: from)
        snippets.insert(moved, at: to)
    }

    /// What a fresh install starts with — enough to show what the app does
    /// without anyone reading the README first.
    ///
    /// Stored, not computed: a computed version would mint new ids on every
    /// access, so a store's fallback would never compare equal to it.
    public static let starter = SnippetLibrary(snippets: [
        Snippet(label: "Email", content: "you@example.com"),
        Snippet(label: "Signature", content: "Best,\nSouhaib"),
        Snippet(label: "Today", content: "{{date}}"),
    ])
}
