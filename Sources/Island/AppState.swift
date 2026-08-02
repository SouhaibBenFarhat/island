import AppKit
import Combine
import IslandCore

/// The single source of truth for snippets and settings, saved to disk on
/// every change.
@MainActor
final class AppState: ObservableObject {
    @Published private(set) var library: SnippetLibrary
    @Published var settings: Settings {
        didSet { if settings != oldValue { persistSettings() } }
    }

    /// Set right after an insert so the chip can flash a checkmark.
    @Published var lastInsertedID: Snippet.ID?

    /// Whether macOS lets us post key events yet. Refreshed on a timer because
    /// the system sends no notification when the user ticks the box.
    @Published private(set) var hasAccessibilityAccess: Bool

    private let libraryStore: JSONFileStore<SnippetLibrary>
    private let settingsStore: JSONFileStore<Settings>
    private var accessibilityTimer: Timer?
    private var flashTask: Task<Void, Never>?

    init(directory: URL = StorageLocation.applicationSupportDirectory()) {
        let libraryStore = JSONFileStore(
            url: StorageLocation.snippetsURL(in: directory),
            fallback: SnippetLibrary.starter
        )
        let settingsStore = JSONFileStore(
            url: StorageLocation.settingsURL(in: directory),
            fallback: Settings()
        )
        self.libraryStore = libraryStore
        self.settingsStore = settingsStore
        self.library = libraryStore.load()
        self.settings = settingsStore.load()
        self.hasAccessibilityAccess = AccessibilityAccess.isTrusted
    }

    // MARK: - Snippets

    @discardableResult
    func addSnippet() -> Snippet {
        let snippet = Snippet(label: "New item", content: "")
        library.append(snippet)
        persistLibrary()
        return snippet
    }

    func update(_ snippet: Snippet) {
        library.update(snippet)
        persistLibrary()
    }

    func remove(id: Snippet.ID) {
        library.remove(id: id)
        persistLibrary()
    }

    func move(from source: Int, to destination: Int) {
        library.move(from: source, to: destination)
        persistLibrary()
    }

    // MARK: - Inserting

    /// Expands placeholders and hands the result to the inserter.
    func insert(_ snippet: Snippet) {
        guard !snippet.isEmpty else { return }

        // Without the Accessibility permission the key events go nowhere, so
        // ask for it instead of failing quietly.
        guard AccessibilityAccess.isTrusted else {
            hasAccessibilityAccess = false
            AccessibilityAccess.prompt()
            return
        }

        let text: String
        if settings.expandPlaceholders {
            let context = PlaceholderContext(
                date: Date(),
                // Not the raw pasteboard: an insert still in flight has
                // Island's own text sitting on it.
                clipboard: TextInserter.userClipboardString,
                uuid: UUID()
            )
            text = PlaceholderExpander.expand(snippet.content, context: context)
        } else {
            text = snippet.content
        }

        TextInserter.insert(
            text,
            using: settings.insertMethod,
            spaceIfNeeded: settings.spaceBeforeInsert
        )
        flashInserted(snippet.id)
    }

    private func flashInserted(_ id: Snippet.ID) {
        flashTask?.cancel()
        lastInsertedID = id
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            self?.lastInsertedID = nil
        }
    }

    // MARK: - Accessibility permission

    func startWatchingAccessibilityAccess() {
        refreshAccessibilityAccess()
        accessibilityTimer?.invalidate()
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            MainActor.assumeIsolated { self.refreshAccessibilityAccess() }
        }
    }

    private func refreshAccessibilityAccess() {
        let trusted = AccessibilityAccess.isTrusted
        if trusted != hasAccessibilityAccess { hasAccessibilityAccess = trusted }
    }

    // MARK: - Persistence

    private func persistLibrary() {
        do {
            try libraryStore.save(library)
        } catch {
            NSLog("Island: could not save snippets: \(error)")
        }
    }

    private func persistSettings() {
        do {
            try settingsStore.save(settings)
        } catch {
            NSLog("Island: could not save settings: \(error)")
        }
    }
}
