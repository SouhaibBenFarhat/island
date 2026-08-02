import Foundation
import ServiceManagement

enum LaunchAtLogin {
    /// SMAppService needs a real .app bundle; when running the bare binary
    /// during development there is nothing to register.
    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundlePath.hasSuffix(".app")
    }

    static var isEnabled: Bool {
        isAvailable && SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        guard isAvailable else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Island: failed to update launch-at-login: \(error)")
        }
    }
}
