import AppKit
import Combine
import IslandCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let state = AppState()
    private var statusItem: NSStatusItem!
    private var panelController: IslandPanelController!
    private var editorController: EditorWindowController!
    private var cancellables: Set<AnyCancellable> = []

    // Menu items we need to tick, hide or retitle as things change.
    private let visibilityItem = NSMenuItem()
    private let launchAtLoginItem = NSMenuItem()
    private let placeholdersItem = NSMenuItem()
    private let spacingItem = NSMenuItem()
    private let accessibilityItem = NSMenuItem()
    private var insertMethodItems: [InsertMethod: NSMenuItem] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        FrontmostAppTracker.shared.start()

        editorController = EditorWindowController(state: state)
        panelController = IslandPanelController(
            state: state,
            onEdit: { [weak self] in self?.openEditor() },
            onHide: { [weak self] in self?.setIslandVisible(false) }
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = MenuBarIcon.make()
        statusItem.button?.toolTip = "Island"
        statusItem.menu = buildMenu()

        state.$settings
            .map(\.isIslandVisible)
            .removeDuplicates()
            .sink { [weak self] visible in self?.panelController.apply(visible: visible) }
            .store(in: &cancellables)

        state.startWatchingAccessibilityAccess()

        // First run: nothing works without Accessibility, so ask up front
        // rather than after the first click that silently does nothing.
        if !AccessibilityAccess.isTrusted {
            AccessibilityAccess.prompt()
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        visibilityItem.title = "Hide Island"
        visibilityItem.action = #selector(toggleIsland)
        visibilityItem.target = self
        menu.addItem(visibilityItem)

        let editItem = NSMenuItem(title: "Edit Items…", action: #selector(openEditor), keyEquivalent: "e")
        editItem.target = self
        menu.addItem(editItem)

        menu.addItem(.separator())

        let insertItem = NSMenuItem(title: "Insert With", action: nil, keyEquivalent: "")
        let insertMenu = NSMenu()
        for method in InsertMethod.allCases {
            let item = NSMenuItem(title: method.title, action: #selector(chooseInsertMethod(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = method.rawValue
            insertMenu.addItem(item)
            insertMethodItems[method] = item
        }
        insertItem.submenu = insertMenu
        menu.addItem(insertItem)

        placeholdersItem.title = "Expand {{placeholders}}"
        placeholdersItem.action = #selector(togglePlaceholders)
        placeholdersItem.target = self
        menu.addItem(placeholdersItem)

        spacingItem.title = "Add a Space When Needed"
        spacingItem.action = #selector(toggleSpacing)
        spacingItem.target = self
        spacingItem.toolTip = "Put a space in front of inserted text when a word already sits before the cursor"
        menu.addItem(spacingItem)

        launchAtLoginItem.title = "Launch at Login"
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        accessibilityItem.title = "Grant Accessibility Access…"
        accessibilityItem.action = #selector(openAccessibilitySettings)
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "Island \(Self.version)", action: #selector(openProjectPage), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit Island", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        visibilityItem.title = state.settings.isIslandVisible ? "Hide Island" : "Show Island"
        placeholdersItem.state = state.settings.expandPlaceholders ? .on : .off
        spacingItem.state = state.settings.spaceBeforeInsert ? .on : .off
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
        launchAtLoginItem.isHidden = !LaunchAtLogin.isAvailable
        accessibilityItem.isHidden = state.hasAccessibilityAccess
        for (method, item) in insertMethodItems {
            item.state = state.settings.insertMethod == method ? .on : .off
        }
    }

    // MARK: - Actions

    @objc private func toggleIsland() {
        setIslandVisible(!state.settings.isIslandVisible)
    }

    private func setIslandVisible(_ visible: Bool) {
        state.settings.isIslandVisible = visible
    }

    @objc private func openEditor() {
        editorController.show()
    }

    @objc private func togglePlaceholders() {
        state.settings.expandPlaceholders.toggle()
    }

    @objc private func toggleSpacing() {
        state.settings.spaceBeforeInsert.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
    }

    @objc private func chooseInsertMethod(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let method = InsertMethod(rawValue: raw)
        else { return }
        state.settings.insertMethod = method
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityAccess.prompt()
        AccessibilityAccess.openSettings()
    }

    @objc private func openProjectPage() {
        NSWorkspace.shared.open(URL(string: "https://souhaibbenfarhat.github.io/island/")!)
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}

/// The menu bar glyph: the same mark as the app icon — the island bar over two
/// lines of text — drawn as a template so macOS tints it for light, dark and
/// highlighted menu bars.
enum MenuBarIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 14), flipped: false) { _ in
            NSColor.black.setFill()

            func capsule(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
                NSBezierPath(
                    roundedRect: NSRect(x: x, y: y, width: width, height: height),
                    xRadius: height / 2,
                    yRadius: height / 2
                ).fill()
            }

            capsule(x: 1, y: 7.4, width: 16, height: 6)
            capsule(x: 1, y: 4.0, width: 16, height: 1.8)
            capsule(x: 1, y: 0.6, width: 10, height: 1.8)
            return true
        }
        image.isTemplate = true
        return image
    }
}
