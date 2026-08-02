import AppKit

// Exit early if another instance is already running (e.g. login item + manual launch).
if let bundleID = Bundle.main.bundleIdentifier,
   NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).count > 1 {
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    // Accessory: menu bar item only, no Dock icon, and — importantly — clicking
    // the island never takes focus away from the app you are typing in.
    app.setActivationPolicy(.accessory)
    app.run()
}
