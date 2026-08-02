import AppKit
import Combine
import SwiftUI
import IslandCore

/// The drop-down that appears under the island when you hover its handle:
/// every stored item, with a preview of what it will insert.
///
/// It exists because the bar only has room for a handful of chips, and because
/// a label alone doesn't tell you what an item actually contains.
@MainActor
final class ItemListPanelController {
    /// How long the pointer must rest on the pill before the list appears.
    /// Short enough to feel instant; the tiny pause is only there so crossing
    /// the pill on the way somewhere else doesn't flash the list open.
    private static let openDelay = Duration.milliseconds(90)
    /// Grace period after the pointer leaves, so you can cross the gap between
    /// the island and the list without it vanishing.
    private static let closeDelay = Duration.milliseconds(260)
    /// Gap between the island and the list.
    private static let gap: CGFloat = 8

    private let state: AppState
    private let panel: IslandPanel
    private let hostingView: NSHostingView<ItemListView>
    private let anchorFrame: () -> CGRect

    private var isOverHandle = false
    private var isOverList = false
    private var openTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    init(state: AppState, anchorFrame: @escaping () -> CGRect, onEdit: @escaping () -> Void) {
        self.state = state
        self.anchorFrame = anchorFrame

        panel = IslandPanel(
            contentRect: NSRect(x: 0, y: 0, width: ItemListView.width, height: 200),
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
        panel.animationBehavior = .utilityWindow
        panel.title = "Island Items"

        // Built here so the view can call back into this controller.
        var view = ItemListView(state: state)
        hostingView = NSHostingView(rootView: view)
        panel.contentView = hostingView

        view.onHover = { [weak self] hovering in self?.listHover(hovering) }
        view.onPick = { [weak self] snippet in
            state.insert(snippet)
            self?.hideNow()
        }
        view.onEdit = { [weak self] in
            onEdit()
            self?.hideNow()
        }
        hostingView.rootView = view

        // Re-fit while open: renaming an item changes how tall the list is.
        state.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self, self.panel.isVisible else { return }
                self.position()
            }
            .store(in: &cancellables)
    }

    // MARK: - Hover

    func handleHover(_ hovering: Bool) {
        isOverHandle = hovering
        hovering ? scheduleOpen() : scheduleClose()
    }

    private func listHover(_ hovering: Bool) {
        isOverList = hovering
        hovering ? cancelClose() : scheduleClose()
    }

    /// Opens straight away — used when the "more items" button is clicked
    /// rather than hovered.
    func showImmediately() {
        openTask?.cancel()
        cancelClose()
        present()
    }

    func hideNow() {
        openTask?.cancel()
        closeTask?.cancel()
        isOverHandle = false
        isOverList = false
        panel.orderOut(nil)
    }

    private func scheduleOpen() {
        cancelClose()
        guard !panel.isVisible else { return }
        openTask?.cancel()
        openTask = Task { [weak self] in
            try? await Task.sleep(for: Self.openDelay)
            guard !Task.isCancelled, let self, self.isOverHandle else { return }
            self.present()
        }
    }

    private func scheduleClose() {
        openTask?.cancel()
        closeTask?.cancel()
        closeTask = Task { [weak self] in
            try? await Task.sleep(for: Self.closeDelay)
            guard !Task.isCancelled, let self else { return }
            guard !self.isOverHandle, !self.isOverList else { return }
            self.panel.orderOut(nil)
        }
    }

    private func cancelClose() {
        closeTask?.cancel()
        closeTask = nil
    }

    // MARK: - Placement

    private func present() {
        guard !state.library.isEmpty else { return }
        position()
        panel.orderFrontRegardless()
        panel.invalidateShadow()
    }

    /// Sits under the island, left edges aligned. Flips above when there isn't
    /// room below, and is pulled back onto the screen either way.
    private func position() {
        let size = hostingView.fittingSize
        guard size.width > 0, size.height > 0 else { return }

        let anchor = anchorFrame()
        let screens = NSScreen.screens.map(\.visibleFrame)
        let bounds = PanelPlacement.bestScreen(for: anchor, among: screens)
            ?? NSScreen.main?.visibleFrame
            ?? screens.first
            ?? anchor

        var origin = CGPoint(x: anchor.minX, y: anchor.minY - Self.gap - size.height)
        if origin.y < bounds.minY {
            origin.y = anchor.maxY + Self.gap
        }

        let frame = PanelPlacement.clamp(CGRect(origin: origin, size: size), into: bounds)
        panel.setFrame(frame, display: true)
    }
}

/// The list itself.
struct ItemListView: View {
    static let width: CGFloat = 272
    private static let rowHeight: CGFloat = 38
    private static let maximumListHeight: CGFloat = 320

    @ObservedObject var state: AppState

    var onHover: (Bool) -> Void = { _ in }
    var onPick: (Snippet) -> Void = { _ in }
    var onEdit: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(spacing: 2) {
                    ForEach(state.library.snippets) { snippet in
                        ItemRow(snippet: snippet) { onPick(snippet) }
                    }
                }
                .padding(6)
            }
            .frame(height: listHeight)
            .scrollIndicators(.automatic)

            Divider().opacity(0.6)

            Button(action: onEdit) {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3").font(.system(size: 10))
                    Text("Edit items…").font(.system(size: 11.5))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: Self.width)
        .islandSurface()
        .onHover(perform: onHover)
    }

    private var listHeight: CGFloat {
        let wanted = CGFloat(state.library.count) * Self.rowHeight + 12
        return min(max(wanted, Self.rowHeight), Self.maximumListHeight)
    }
}

/// One row: the label, and a one-line preview of what it inserts.
private struct ItemRow: View {
    let snippet: Snippet
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(snippet.color?.dot ?? NeutralSwatch.dot)
                    .frame(width: 7, height: 7)
                VStack(alignment: .leading, spacing: 1) {
                    Text(snippet.displayLabel)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.9))
                        .lineLimit(1)
                    Text(snippet.isEmpty ? "No text yet" : snippet.contentPreview)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                isHovering ? Theme.chipHover : Color.clear,
                in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(snippet.isEmpty ? "This item has no text yet" : snippet.content)
    }
}
