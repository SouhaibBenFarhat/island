import SwiftUI
import IslandCore

/// The floating bar itself.
struct IslandView: View {
    @ObservedObject var state: AppState

    let dragger: PanelDragger
    var onEdit: () -> Void
    var onHide: () -> Void

    var body: some View {
        Group {
            if state.settings.isCollapsed {
                collapsedBar
            } else {
                expandedBar
            }
        }
        .fixedSize()
        .contextMenu {
            Button("Edit Items…", action: onEdit)
            Button(state.settings.isCollapsed ? "Expand" : "Collapse") { toggleCollapsed() }
            Divider()
            Button("Hide Island", action: onHide)
        }
    }

    // MARK: - Layouts

    private var collapsedBar: some View {
        IslandMark()
            .padding(.horizontal, 11)
            .frame(height: Theme.barHeight - 10)
            .contentShape(Rectangle())
            .islandDraggable(dragger, onTap: toggleCollapsed)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Show Island items")
            .help("Click to show your items · drag to move")
            .background(DragCatcher(dragger: dragger))
            .islandSurface()
    }

    private var expandedBar: some View {
        HStack(spacing: Theme.itemSpacing) {
            IslandMark()
                .padding(.horizontal, 3)
                .frame(height: Theme.barHeight)
                .contentShape(Rectangle())
                .islandDraggable(dragger, onTap: toggleCollapsed)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Collapse the island")
                .help("Click to collapse · drag to move")

            rule

            if !state.hasAccessibilityAccess {
                permissionChip
            }

            if state.library.isEmpty {
                emptyHint
            } else {
                ForEach(visibleSnippets) { snippet in
                    SnippetChip(
                        snippet: snippet,
                        isConfirmed: state.lastInsertedID == snippet.id,
                        dragger: dragger,
                        action: { state.insert(snippet) }
                    )
                }
                if !overflowSnippets.isEmpty { overflowMenu }
            }

            rule

            IconButton(symbol: "plus", help: "Add or edit items", dragger: dragger, action: onEdit)
        }
        .padding(.horizontal, Theme.barPadding)
        .frame(height: Theme.barHeight)
        .background(DragCatcher(dragger: dragger))
        .islandSurface()
    }

    // MARK: - Pieces

    private var rule: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(width: 1, height: 18)
    }

    private var emptyHint: some View {
        Text("Add your first item")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .frame(height: 26)
            .contentShape(Rectangle())
            .islandDraggable(dragger, onTap: onEdit)
            .accessibilityAddTraits(.isButton)
    }

    private var permissionChip: some View {
        Label("Allow access", systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 11, weight: .medium))
            .labelStyle(.titleAndIcon)
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous))
            .islandDraggable(dragger, onTap: AccessibilityAccess.openSettings)
            .accessibilityAddTraits(.isButton)
            .help("Island needs Accessibility access to type into other apps")
    }

    private var overflowMenu: some View {
        Menu {
            ForEach(overflowSnippets) { snippet in
                Button(snippet.displayLabel) { state.insert(snippet) }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Theme.chipRest, in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 26)
        .help("\(overflowSnippets.count) more items")
    }

    // MARK: - Data

    private var visibleSnippets: [Snippet] {
        Array(state.library.snippets.prefix(Theme.maximumVisibleChips))
    }

    private var overflowSnippets: [Snippet] {
        Array(state.library.snippets.dropFirst(Theme.maximumVisibleChips))
    }

    private func toggleCollapsed() {
        state.settings.isCollapsed.toggle()
    }
}

/// One clickable item. Flashes a tick after inserting so you know it landed,
/// since the text appears in a different app.
struct SnippetChip: View {
    let snippet: Snippet
    let isConfirmed: Bool
    let dragger: PanelDragger
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            if isConfirmed {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.accent)
            }
            Text(snippet.displayLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isConfirmed ? Theme.accent : Color.primary.opacity(0.85))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(background, in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous))
        .islandDraggable(dragger, onTap: action)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(snippet.displayLabel)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .animation(.easeOut(duration: 0.12), value: isConfirmed)
        .help(snippet.content.isEmpty ? "This item has no text yet" : snippet.content)
    }

    private var background: Color {
        if isConfirmed { return Theme.accent.opacity(0.14) }
        return isHovering ? Theme.chipHover : Theme.chipRest
    }
}

/// Square icon button matching the chips.
struct IconButton: View {
    let symbol: String
    let help: String
    let dragger: PanelDragger
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 26, height: 26)
            .background(
                isHovering ? Theme.chipHover : Theme.chipRest,
                in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous))
            .islandDraggable(dragger, onTap: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(help)
            .onHover { isHovering = $0 }
            .help(help)
    }
}

/// Lets you drag the island by its empty background.
///
/// It sits behind the chips as a plain SwiftUI layer, so a click on a chip
/// still reaches the chip — an AppKit subview here would swallow every click.
struct DragCatcher: View {
    let dragger: PanelDragger

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .islandDraggable(dragger)
    }
}

extension View {
    /// Makes this view move the island when dragged, and run `onTap` when it's
    /// clicked without moving.
    ///
    /// Every part of the bar uses this, so you can grab the island anywhere —
    /// including on a chip — without losing the click that inserts its text.
    func islandDraggable(_ dragger: PanelDragger, onTap: @escaping () -> Void = {}) -> some View {
        gesture(
            // minimumDistance 0 so a plain click is still delivered here; the
            // drag/click split is decided by how far the pointer actually moved.
            DragGesture(minimumDistance: 0)
                .onChanged { _ in dragger.update() }
                .onEnded { _ in if !dragger.finish() { onTap() } }
        )
    }
}

/// Moves the panel with the pointer.
///
/// SwiftUI decides *what* you grabbed; AppKit does the moving. Nudging the
/// window from inside `onChanged` fights itself — SwiftUI measures the drag
/// inside the very window being moved, so each step feeds back into the next
/// and the island stutters. `performDrag(with:)` hands the whole thing to the
/// window server, which tracks the pointer exactly.
@MainActor
final class PanelDragger {
    /// How far the pointer must travel before this counts as a drag rather
    /// than a click. Small enough to feel immediate, large enough that a shaky
    /// click on a chip still inserts its text.
    static let dragThreshold: CGFloat = 3

    weak var panel: NSPanel?
    var onFinish: (() -> Void)?

    private enum Phase {
        case idle
        /// Mouse is down but hasn't travelled far enough to be a drag yet.
        case pressed(start: CGPoint)
        /// A drag ran to completion; the click that ends it must be swallowed.
        case dragged
    }

    private var phase: Phase = .idle

    func update() {
        switch phase {
        case .pressed(let start):
            let mouse = NSEvent.mouseLocation
            guard hypot(mouse.x - start.x, mouse.y - start.y) >= Self.dragThreshold else { return }
            beginDrag()

        case .idle:
            phase = .pressed(start: NSEvent.mouseLocation)

        case .dragged:
            // `performDrag` swallows the mouse-up, so SwiftUI may never send
            // .onEnded and clear this. If the button is down again it's a new
            // gesture; otherwise it's a stray event from the one just finished.
            guard NSEvent.pressedMouseButtons & 1 != 0 else { return }
            phase = .pressed(start: NSEvent.mouseLocation)
        }
    }

    /// Ends the gesture. Returns true when it was a real drag, so the caller
    /// knows to skip the click action.
    @discardableResult
    func finish() -> Bool {
        if case .dragged = phase {
            phase = .idle
            return true
        }
        phase = .idle
        return false
    }

    private func beginDrag() {
        guard let panel, let event = NSApp.currentEvent, event.type == .leftMouseDragged else {
            return // No usable event yet — try again on the next update.
        }
        phase = .dragged
        panel.performDrag(with: event) // Blocks until you let go.
        onFinish?()
    }
}
