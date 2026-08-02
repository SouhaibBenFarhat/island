import AppKit
import IslandCore

/// Puts text into whatever text field is focused in another app.
///
/// Both routes post synthetic key events, so both need the Accessibility
/// permission. Check `AccessibilityAccess.isTrusted` before calling.
@MainActor
enum TextInserter {
    /// How long to wait for a re-activated app to be ready for key events.
    private static let activationDelay = Duration.milliseconds(140)
    /// How long to leave our text on the clipboard before putting the old
    /// contents back. Long enough for the target app to service the paste.
    private static let clipboardRestoreDelay = Duration.milliseconds(450)
    /// Gap between typed batches, so fast key posting doesn't outrun the
    /// receiving app's input queue.
    private static let typingDelay = Duration.milliseconds(4)

    static func insert(_ text: String, using method: InsertMethod, spaceIfNeeded: Bool) {
        guard !text.isEmpty else { return }

        // Clicking a chip doesn't activate Island, but opening the editor
        // window does — put the other app back in front first.
        let tracker = FrontmostAppTracker.shared
        let reactivated = tracker.isIslandFrontmost && tracker.restoreExternalApp()

        Task { @MainActor in
            if reactivated { try? await Task.sleep(for: activationDelay) }

            // Read the cursor's surroundings only now: before this point the
            // target app may not be frontmost, and the focused element would be
            // the wrong one.
            let payload = spaceIfNeeded
                ? InsertionSpacing.prepare(text, precedingCharacter: FocusedField.characterBeforeCursor())
                : text

            switch method {
            case .paste: await pasteViaClipboard(payload)
            case .type: await typeCharacters(payload)
            }
        }
    }

    // MARK: - Paste

    private static func pasteViaClipboard(_ text: String) async {
        let pasteboard = NSPasteboard.general
        let snapshot = ClipboardSnapshot(of: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let ourChangeCount = pasteboard.changeCount

        postCommandV()

        try? await Task.sleep(for: clipboardRestoreDelay)
        // If something else has written to the clipboard in the meantime, that
        // is now the user's clipboard — don't stomp on it.
        guard pasteboard.changeCount == ourChangeCount else { return }
        snapshot.restore(to: pasteboard)
    }

    private static func postCommandV() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        // Stop physically-held keys from leaking into our synthetic ⌘V.
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let vKeyCode: CGKeyCode = 0x09
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    // MARK: - Type

    private static func typeCharacters(_ text: String) async {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        for chunk in UnicodeChunker.chunks(of: text) {
            let utf16 = Array(chunk.utf16)
            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else { continue }

            // No virtual key — the payload is the string itself, so the current
            // keyboard layout can't mangle it.
            keyDown.flags = []
            keyUp.flags = []
            keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)

            try? await Task.sleep(for: typingDelay)
        }
    }
}

/// A copy of the clipboard, taken before we overwrite it and put back after.
private struct ClipboardSnapshot {
    /// Skip anything huge (a screenshot, a big file promise) — holding it in
    /// memory for half a second isn't worth it, and text is what people care
    /// about getting back.
    private static let maximumItemSize = 4 * 1_024 * 1_024

    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(of pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            var contents: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                guard let data = item.data(forType: type),
                      data.count <= Self.maximumItemSize
                else { continue }
                contents[type] = data
            }
            return contents
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }

        let restored = items.compactMap { contents -> NSPasteboardItem? in
            guard !contents.isEmpty else { return nil }
            let item = NSPasteboardItem()
            for (type, data) in contents {
                item.setData(data, forType: type)
            }
            return item
        }

        guard !restored.isEmpty else { return }
        pasteboard.writeObjects(restored)
    }
}
