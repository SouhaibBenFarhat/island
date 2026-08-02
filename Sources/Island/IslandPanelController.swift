import AppKit
import Combine
import SwiftUI
import IslandCore

/// A borderless panel that floats above other apps without ever taking focus
/// from them.
final class IslandPanel: NSPanel {
    // Borderless panels can't become key by default; allowing it (together with
    // `becomesKeyOnlyIfNeeded`) means clicks reach the chips, while typing focus
    // stays in the app you were writing in.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Owns the island window: builds it, keeps it sized to its contents, keeps it
/// on screen, and remembers where you put it.
@MainActor
final class IslandPanelController {
    private let state: AppState
    private let panel: IslandPanel
    private let hostingView: NSHostingView<IslandView>
    private let dragger = PanelDragger()
    private var cancellables: Set<AnyCancellable> = []

    var isVisible: Bool { panel.isVisible }

    init(state: AppState, onEdit: @escaping () -> Void, onHide: @escaping () -> Void) {
        self.state = state

        panel = IslandPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: Theme.barHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false // handled by PanelDragger
        panel.animationBehavior = .utilityWindow
        panel.title = "Island"

        hostingView = NSHostingView(
            rootView: IslandView(state: state, dragger: dragger, onEdit: onEdit, onHide: onHide)
        )
        panel.contentView = hostingView

        dragger.panel = panel
        dragger.onFinish = { [weak self] in self?.rememberPosition() }

        // The bar changes width when items are added, renamed or removed.
        state.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.fitToContent() }
            .store(in: &cancellables)

        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.keepOnScreen() }
            .store(in: &cancellables)

        fitToContent()
        placeInitially()
    }

    // MARK: - Showing

    func show() {
        fitToContent()
        keepOnScreen()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func apply(visible: Bool) {
        visible ? show() : hide()
    }

    // MARK: - Layout

    /// Resize the window to whatever the SwiftUI bar currently wants to be.
    private func fitToContent() {
        let size = hostingView.fittingSize
        guard size.width > 0, size.height > 0 else { return }

        let current = panel.frame
        guard size != current.size else { return }

        // Pin the top-left corner: the bar grows rightwards and downwards from
        // where you put it, instead of sliding out from under the pointer or
        // creeping up the screen when it collapses.
        let origin = CGPoint(x: current.minX, y: current.maxY - size.height)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        keepOnScreen()
        panel.invalidateShadow()
    }

    private func placeInitially() {
        let screens = NSScreen.screens.map(\.visibleFrame)
        guard let preferred = NSScreen.main?.visibleFrame ?? screens.first else { return }
        let frame = PanelPlacement.resolveFrame(
            savedOrigin: state.settings.panelOrigin,
            size: panel.frame.size,
            screens: screens,
            preferred: preferred
        )
        panel.setFrame(frame, display: false)
    }

    private func keepOnScreen() {
        guard let bounds = currentScreenBounds() else { return }
        let clamped = PanelPlacement.clamp(panel.frame, into: bounds)
        if clamped != panel.frame {
            panel.setFrame(clamped, display: true)
        }
    }

    private func rememberPosition() {
        keepOnScreen()
        state.settings.panelOrigin = panel.frame.origin
    }

    /// The usable area of the display the island is actually on — menu bar and
    /// Dock excluded. Checks every screen, so an island parked on a second
    /// monitor isn't clamped against the built-in one.
    private func currentScreenBounds() -> CGRect? {
        let screens = NSScreen.screens.map(\.visibleFrame)
        return PanelPlacement.bestScreen(for: panel.frame, among: screens)
            ?? NSScreen.main?.visibleFrame
            ?? screens.first
    }
}
