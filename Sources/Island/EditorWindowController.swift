import AppKit
import SwiftUI

/// Owns the "Island Items" window. Unlike the island itself this is an ordinary
/// window: it has text fields, so it does take focus.
@MainActor
final class EditorWindowController {
    private let state: AppState
    private var window: NSWindow?

    init(state: AppState) {
        self.state = state
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window

        if !window.isVisible { window.center() }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Island Items"
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: EditorView(state: state))
        window.setContentSize(NSSize(width: 720, height: 440))
        return window
    }
}
