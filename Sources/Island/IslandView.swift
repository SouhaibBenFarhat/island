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
        Button(action: toggleCollapsed) {
            IslandMark()
                .padding(.horizontal, 11)
                .frame(height: Theme.barHeight - 10)
        }
        .buttonStyle(.plain)
        .help("Show Island items")
        .background(DragCatcher(dragger: dragger))
        .islandSurface()
    }

    private var expandedBar: some View {
        HStack(spacing: Theme.itemSpacing) {
            Button(action: toggleCollapsed) {
                IslandMark().padding(.horizontal, 3)
            }
            .buttonStyle(.plain)
            .help("Collapse the island")

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
                        action: { state.insert(snippet) }
                    )
                }
                if !overflowSnippets.isEmpty { overflowMenu }
            }

            rule

            IconButton(symbol: "plus", help: "Add or edit items", action: onEdit)
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
        Button(action: onEdit) {
            Text("Add your first item")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }

    private var permissionChip: some View {
        Button(action: AccessibilityAccess.openSettings) {
            Label("Allow access", systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .medium))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
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
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
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
        }
        .buttonStyle(.plain)
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
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(
                    isHovering ? Theme.chipHover : Theme.chipRest,
                    in: RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: Theme.chipCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help)
    }
}

/// Lets you drag the island by its empty background.
///
/// It sits behind the chips as a plain SwiftUI layer, so a click on a chip
/// still reaches the button — an AppKit subview here would swallow every click.
struct DragCatcher: View {
    let dragger: PanelDragger

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { _ in dragger.followMouse() }
                    .onEnded { _ in dragger.finish() }
            )
    }
}

/// Moves the panel with the pointer.
///
/// SwiftUI's drag translation is measured inside a window that is itself
/// moving, so it feeds back on itself. Reading the screen position of the
/// mouse each step and applying the delta keeps the island under the cursor.
@MainActor
final class PanelDragger {
    weak var panel: NSPanel?
    var onFinish: (() -> Void)?

    private var lastMouse: CGPoint?

    func followMouse() {
        let mouse = NSEvent.mouseLocation
        defer { lastMouse = mouse }
        guard let panel, let last = lastMouse else { return }
        panel.setFrameOrigin(
            CGPoint(
                x: panel.frame.origin.x + (mouse.x - last.x),
                y: panel.frame.origin.y + (mouse.y - last.y)
            )
        )
    }

    func finish() {
        lastMouse = nil
        onFinish?()
    }
}
