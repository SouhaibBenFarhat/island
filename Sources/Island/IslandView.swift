import SwiftUI
import IslandCore

/// The floating bar itself.
struct IslandView: View {
    @ObservedObject var state: AppState

    let dragger: PanelDragger
    var onEdit: () -> Void
    var onHide: () -> Void
    /// Hovering the collapsed pill opens the drop-down of every stored item.
    /// The expanded bar doesn't do this — the chips are already on screen, so
    /// a list on top of them is just noise.
    var onHandleHover: (Bool) -> Void = { _ in }
    var onShowList: () -> Void = {}

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
            .onHover(perform: onHandleHover)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Show Island items")
            .help("Hover to list your items · click to expand · drag to move")
            // No DragCatcher here: the pill *is* the handle, and a second
            // gesture over the same spot only causes trouble.
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
                if !overflowSnippets.isEmpty { overflowButton }
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

    /// The chips that didn't fit live in the drop-down, so this just opens it.
    private var overflowButton: some View {
        IconButton(
            symbol: "ellipsis",
            help: "\(overflowSnippets.count) more items — hover to list them all",
            dragger: dragger,
            action: onShowList
        )
        .onHover(perform: onHandleHover)
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
        HStack(spacing: 5) {
            if isConfirmed {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.accent)
            } else if let color = snippet.color {
                Circle()
                    .fill(color.dot)
                    .frame(width: 6, height: 6)
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

    /// How long after the button comes up we keep treating callbacks as the
    /// tail of the drag rather than a new click.
    private static let settleWindow: TimeInterval = 0.3

    weak var panel: NSPanel?
    /// Called once the drag is over, to save where the island ended up.
    var onFinish: (() -> Void)?
    /// Called the moment a drag really starts, before the window moves.
    var onDragStart: (() -> Void)?

    private enum Phase {
        case idle
        /// Mouse is down but hasn't travelled far enough to be a drag yet.
        case pressed(start: CGPoint)
        /// A drag is running, or has just finished and is still settling.
        case dragged
    }

    private var phase: Phase = .idle
    private var lastDragActivity: TimeInterval = -.infinity

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }
    private var isSettling: Bool { now - lastDragActivity < Self.settleWindow }
    private var isButtonDown: Bool { NSEvent.pressedMouseButtons & 1 != 0 }

    func update() {
        switch phase {
        case .idle:
            // Ignore the tail of a drag that just ended; starting a fresh press
            // here is what turned the end of a drag into a click.
            guard !isSettling else { return }
            phase = .pressed(start: NSEvent.mouseLocation)

        case .pressed(let start):
            let mouse = NSEvent.mouseLocation
            guard hypot(mouse.x - start.x, mouse.y - start.y) >= Self.dragThreshold else { return }
            beginDrag()

        case .dragged:
            // `performDrag` hands the drag to the window server and can return
            // straight away, so "still dragging" is the button still being
            // down — not whether that call has come back.
            if isButtonDown {
                lastDragActivity = now
                return
            }
            // Button is up. Hold on a little longer so the callbacks that close
            // out this drag can't be read as a press.
            guard !isSettling else { return }
            endDrag()
            phase = .pressed(start: NSEvent.mouseLocation)
        }
    }

    /// Ends the gesture. Returns true when it was a real drag, so the caller
    /// knows to skip the click action.
    ///
    /// More than one gesture can be live over the same spot (a chip and the bar
    /// behind it), so this has to answer "that was a drag" to *every* caller,
    /// not just the first — hence the settle window rather than a flag the
    /// first finisher consumes.
    @discardableResult
    func finish() -> Bool {
        var wasDrag = isSettling
        if case .dragged = phase {
            wasDrag = true
            endDrag()
        }
        phase = .idle
        return wasDrag
    }

    private func beginDrag() {
        guard let panel, let event = NSApp.currentEvent, event.type == .leftMouseDragged else {
            return // No usable event yet — try again on the next update.
        }
        phase = .dragged
        lastDragActivity = now
        onDragStart?()
        panel.performDrag(with: event)
    }

    /// Records the resting place. Called when the drag is genuinely over, not
    /// when `performDrag` returns — those are not the same moment.
    private func endDrag() {
        lastDragActivity = now
        onFinish?()
    }
}
