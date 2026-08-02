import Foundation

/// Everything a placeholder can need, passed in rather than read from the
/// system, so expansion is a pure function and easy to test.
public struct PlaceholderContext: Sendable {
    public var date: Date
    public var clipboard: String
    public var uuid: UUID
    public var timeZone: TimeZone
    public var locale: Locale

    public init(
        date: Date,
        clipboard: String = "",
        uuid: UUID = UUID(),
        timeZone: TimeZone = .current,
        locale: Locale = Locale(identifier: "en_US_POSIX")
    ) {
        self.date = date
        self.clipboard = clipboard
        self.uuid = uuid
        self.timeZone = timeZone
        self.locale = locale
    }
}

/// Replaces `{{token}}` markers in a snippet's content at insert time.
///
/// Supported tokens (case-insensitive):
///
///   `{{date}}`            2026-08-02
///   `{{time}}`            14:39
///   `{{datetime}}`        2026-08-02 14:39
///   `{{date:MMM d, yyyy}}` any DateFormatter pattern
///   `{{clipboard}}`       whatever is on the clipboard right now
///   `{{uuid}}`            a fresh UUID
///
/// A token it doesn't know is left exactly as written, so text that happens to
/// contain `{{` (Handlebars, Jinja, Vue) survives untouched.
public enum PlaceholderExpander {
    public static let openMarker = "{{"
    public static let closeMarker = "}}"

    public static func expand(_ template: String, context: PlaceholderContext) -> String {
        guard template.contains(openMarker) else { return template }

        var output = ""
        var cursor = template.startIndex

        while let open = template.range(of: openMarker, range: cursor..<template.endIndex) {
            guard let close = template.range(of: closeMarker, range: open.upperBound..<template.endIndex) else {
                break // Unclosed marker — the rest is literal text.
            }

            let token = String(template[open.upperBound..<close.lowerBound])
            output += template[cursor..<open.lowerBound]
            output += resolve(token, context: context) ?? "\(openMarker)\(token)\(closeMarker)"
            cursor = close.upperBound
        }

        output += template[cursor...]
        return output
    }

    /// Returns nil for tokens we don't handle, which keeps them literal.
    private static func resolve(_ rawToken: String, context: PlaceholderContext) -> String? {
        let token = rawToken.trimmingCharacters(in: .whitespaces)
        let name: String
        let argument: String?

        if let colon = token.firstIndex(of: ":") {
            name = String(token[token.startIndex..<colon]).lowercased()
            argument = String(token[token.index(after: colon)...])
        } else {
            name = token.lowercased()
            argument = nil
        }

        switch name {
        case "date":
            return format(context, pattern: argument ?? "yyyy-MM-dd")
        case "time":
            return format(context, pattern: argument ?? "HH:mm")
        case "datetime":
            return format(context, pattern: argument ?? "yyyy-MM-dd HH:mm")
        case "clipboard":
            return context.clipboard
        case "uuid":
            return context.uuid.uuidString
        default:
            return nil
        }
    }

    private static func format(_ context: PlaceholderContext, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = context.locale
        formatter.timeZone = context.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: context.date)
    }
}
