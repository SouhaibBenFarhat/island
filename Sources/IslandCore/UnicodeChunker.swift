import Foundation

/// Splits text into pieces small enough to hand to one keyboard event.
///
/// `CGEvent.keyboardSetUnicodeString` takes UTF-16 and drops long strings, so
/// typed insertion has to go out in batches. Splitting on UTF-16 offsets alone
/// would cut emoji in half — half a surrogate pair types as `�` — so we only
/// ever break between whole characters.
public enum UnicodeChunker {
    /// Conservative batch size that every macOS version has accepted.
    public static let defaultLimit = 20

    public static func chunks(of text: String, limit: Int = defaultLimit) -> [String] {
        guard !text.isEmpty else { return [] }
        guard limit > 0 else { return [text] }

        var chunks: [String] = []
        var current = ""
        var currentUnits = 0

        for character in text {
            let units = String(character).utf16.count

            // A single character longer than the limit (a flag, a family emoji)
            // goes out on its own rather than being split.
            if units >= limit {
                if !current.isEmpty {
                    chunks.append(current)
                    current = ""
                    currentUnits = 0
                }
                chunks.append(String(character))
                continue
            }

            if currentUnits + units > limit {
                chunks.append(current)
                current = ""
                currentUnits = 0
            }

            current.append(character)
            currentUnits += units
        }

        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
