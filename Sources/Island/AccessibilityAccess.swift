import AppKit
import ApplicationServices

/// macOS won't let one app send key events to another without the user ticking
/// Privacy & Security → Accessibility. Island needs it for both insert methods.
enum AccessibilityAccess {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system's own "open Settings?" alert. Only prompts once per
    /// app version — after that macOS silently returns the current state, which
    /// is why `openSettings()` exists as the manual route.
    @discardableResult
    static func prompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
    }
}
