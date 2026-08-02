import AppKit
import ApplicationServices

/// Reads what's around the cursor in whatever text field currently has focus,
/// in whatever app that is.
///
/// Everything here is best-effort: plenty of apps (Electron ones especially)
/// expose no usable text over the Accessibility API. Every failure returns nil,
/// and the caller treats nil as "don't guess".
@MainActor
enum FocusedField {
    /// The character immediately before the insertion point, or nil when it
    /// can't be read — including when the cursor is at the very start.
    static func characterBeforeCursor() -> Character? {
        guard let element = focusedElement() else { return nil }
        guard let caret = caretOffset(of: element), caret > 0 else { return nil }

        // Ask for just the one character first — cheap, and the only thing that
        // works in fields that don't expose their whole value.
        if let character = character(before: caret, in: element) { return character }
        return characterFromWholeValue(before: caret, in: element)
    }

    // MARK: - Accessibility plumbing

    private static func focusedElement() -> AXUIElement? {
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            AXUIElementCreateSystemWide(),
            kAXFocusedUIElementAttribute as CFString,
            &focused
        )
        guard result == .success,
              let raw = focused,
              CFGetTypeID(raw) == AXUIElementGetTypeID()
        else { return nil }
        return (raw as! AXUIElement)
    }

    /// Where the cursor sits, as a UTF-16 offset — the unit the Accessibility
    /// API counts in.
    private static func caretOffset(of element: AXUIElement) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        ) == .success, let raw = value, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }

        var range = CFRange()
        guard AXValueGetValue(raw as! AXValue, .cfRange, &range) else { return nil }
        return range.location
    }

    private static func character(before caret: Int, in element: AXUIElement) -> Character? {
        var range = CFRange(location: caret - 1, length: 1)
        guard let rangeValue = AXValueCreate(.cfRange, &range) else { return nil }

        var text: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            rangeValue,
            &text
        ) == .success else { return nil }

        return (text as? String)?.first
    }

    /// Fallback for fields that don't answer the parameterized query but do
    /// hand over their whole value.
    private static func characterFromWholeValue(before caret: Int, in element: AXUIElement) -> Character? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value) == .success,
              let text = value as? String
        else { return nil }

        let utf16 = text.utf16
        guard caret <= utf16.count,
              let index = String.Index(utf16Offset: caret, in: text) as String.Index?,
              index > text.startIndex
        else { return nil }

        return text[text.index(before: index)]
    }
}
