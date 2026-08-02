import AppKit

/// Remembers which other app you were last in.
///
/// The island is a non-activating panel, so clicking a chip normally leaves the
/// other app frontmost and its text field focused. Opening Island's own editor
/// window breaks that, so we keep a handle on the last app that wasn't us and
/// bring it back before inserting.
@MainActor
final class FrontmostAppTracker {
    static let shared = FrontmostAppTracker()

    private(set) var lastExternalApp: NSRunningApplication?
    private var observer: NSObjectProtocol?

    private init() {}

    func start() {
        record(NSWorkspace.shared.frontmostApplication)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { FrontmostAppTracker.shared.record(app) }
        }
    }

    /// True when Island itself is frontmost, i.e. the target app needs waking up
    /// before we can paste into it.
    var isIslandFrontmost: Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
            == NSRunningApplication.current.processIdentifier
    }

    /// Brings the remembered app back to the front. Returns false when there is
    /// nothing to restore.
    @discardableResult
    func restoreExternalApp() -> Bool {
        guard let app = lastExternalApp, !app.isTerminated else { return false }
        return app.activate()
    }

    private func record(_ app: NSRunningApplication?) {
        guard let app,
              app.processIdentifier != NSRunningApplication.current.processIdentifier
        else { return }
        lastExternalApp = app
    }
}
