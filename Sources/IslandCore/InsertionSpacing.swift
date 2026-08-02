import Foundation

/// Decides whether inserted text needs a space in front of it.
///
/// Clicking an item in the middle of a sentence should read as if you'd typed
/// it: `Ping me on you@example.com`, not `Ping me onyou@example.com`. The rule
/// only looks at the character right before the cursor, so it works the same
/// in every app.
public enum InsertionSpacing {
    /// Characters after which a space would be wrong. Openers and quotes bind
    /// tightly to what follows — `(you@example.com`, not `( you@example.com`.
    public static let noSpaceAfter: Set<Character> = ["(", "[", "{", "<", "\"", "'", "/"]

    public static func needsLeadingSpace(
        precedingCharacter: Character?,
        insertedText: String
    ) -> Bool {
        // Nothing before the cursor, or we couldn't read it — don't guess.
        guard let precedingCharacter else { return false }
        // Nothing to insert.
        guard let first = insertedText.first else { return false }
        // Already separated on one side or the other.
        guard !precedingCharacter.isWhitespace, !first.isWhitespace else { return false }
        return !noSpaceAfter.contains(precedingCharacter)
    }

    /// The text to actually insert.
    public static func prepare(_ text: String, precedingCharacter: Character?) -> String {
        needsLeadingSpace(precedingCharacter: precedingCharacter, insertedText: text)
            ? " " + text
            : text
    }
}
