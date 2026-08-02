import AppKit
import Combine
import SwiftUI
import IslandCore

/// The flower: quick-access items as coloured circles ringed around the
/// collapsed island. An alternative to the drop-down list, not an addition —
/// hovering the pill opens whichever one you've chosen.
@MainActor
final class RadialPanelController {
    private static let openDelay = Duration.milliseconds(90)
    private static let closeDelay = Duration.milliseconds(260)

    private let state: AppState
    private let panel: IslandPanel
    private let hostingView: NSHostingView<RadialView>
    private let anchorFrame: () -> CGRect
    private let onOverflow: () -> Void

    /// How often the open panel re-checks where the pointer really is.
    private static let watchInterval = Duration.milliseconds(150)

    private var isOverPill = false
    private var isOverFlower = false
    private var openTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var watchTask: Task<Void, Never>?

    /// The truth about whether the flower should stay up.
    ///
    /// The hover flags are only ever a trigger. macOS skips mouseEntered and
    /// mouseExited when the thing under a still pointer changes — an app going
    /// full screen, a display being plugged in, a window ordering out — and a
    /// swallowed event used to latch the flower open or shut for good.
    private var pointerIsInRange: Bool {
        HoverRegion.keepsOpen(
            point: NSEvent.mouseLocation,
            anchor: anchorFrame(),
            panel: panel.isVisible ? panel.frame : nil
        )
    }

    init(
        state: AppState,
        anchorFrame: @escaping () -> CGRect,
        onOverflow: @escaping () -> Void
    ) {
        self.state = state
        self.anchorFrame = anchorFrame
        self.onOverflow = onOverflow

        panel = IslandPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        // A notch below the island, so the pill always stays clickable through
        // the middle of the ring.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // the petals carry their own
        panel.animationBehavior = .utilityWindow
        panel.title = "Island Quick Access"

        hostingView = NSHostingView(rootView: RadialView(state: state, plan: .empty))
        panel.contentView = hostingView
    }

    // MARK: - Hover

    func handleHover(_ hovering: Bool) {
        isOverPill = hovering
        hovering ? scheduleOpen() : scheduleClose()
    }

    private func flowerHover(_ hovering: Bool) {
        isOverFlower = hovering
        hovering ? cancelClose() : scheduleClose()
    }

    func hideNow() {
        openTask?.cancel()
        closeTask?.cancel()
        watchTask?.cancel()
        watchTask = nil
        isOverPill = false
        isOverFlower = false
        panel.orderOut(nil)
    }

    private func scheduleOpen() {
        cancelClose()
        openTask?.cancel()
        openTask = Task { [weak self] in
            try? await Task.sleep(for: Self.openDelay)
            guard !Task.isCancelled, let self, self.isOverPill else { return }
            // Always present, even when the panel is already ordered in. Using
            // isVisible as a gate here is what made a stale window swallow
            // every later hover; presenting again just re-places it.
            self.present()
        }
    }

    private func scheduleClose() {
        openTask?.cancel()
        closeTask?.cancel()
        closeTask = Task { [weak self] in
            try? await Task.sleep(for: Self.closeDelay)
            guard !Task.isCancelled, let self else { return }
            guard !self.pointerIsInRange else { return }
            self.hideNow()
        }
    }

    private func cancelClose() {
        closeTask?.cancel()
        closeTask = nil
    }

    /// While the flower is up, keep checking that the pointer is still on it.
    /// This is the backstop that makes a missed mouseExited harmless.
    private func startWatching() {
        guard watchTask == nil else { return }
        watchTask = Task { [weak self] in
            while true {
                try? await Task.sleep(for: Self.watchInterval)
                guard !Task.isCancelled, let self else { return }
                guard self.panel.isVisible else { self.watchTask = nil; return }
                guard !self.pointerIsInRange else { continue }
                self.hideNow()
                return
            }
        }
    }

    // MARK: - Building the ring

    private func present() {
        let snippets = state.library.snippets
        guard !snippets.isEmpty else { return }

        let anchor = anchorFrame()
        let screens = NSScreen.screens.map(\.visibleFrame)
        let bounds = PanelPlacement.bestScreen(for: anchor, among: screens)
            ?? NSScreen.main?.visibleFrame
            ?? anchor

        let split = RadialLayout.petalSplit(count: snippets.count)
        var petals = snippets.prefix(split.shown).map(Petal.item)
        if split.overflow > 0 { petals.append(.more(split.overflow)) }

        let plan = RadialLayout.plan(count: petals.count, around: anchor, in: bounds)
        let offsets = RadialLayout.offsets(count: petals.count, radius: plan.radius, arc: plan.arc)
        let size = RadialLayout.panelSize(radius: plan.radius)

        hostingView.rootView = RadialView(
            state: state,
            plan: RadialPlan(petals: petals, offsets: offsets, side: size.width),
            onHover: { [weak self] in self?.flowerHover($0) },
            onPick: { [weak self] snippet in
                self?.state.insert(snippet)
                self?.hideNow()
            },
            onMore: { [weak self] in
                self?.hideNow()
                self?.onOverflow()
            }
        )

        let centre = CGPoint(x: anchor.midX, y: anchor.midY)
        panel.setFrame(
            NSRect(
                x: centre.x - size.width / 2,
                y: centre.y - size.height / 2,
                width: size.width,
                height: size.height
            ),
            display: true
        )
        panel.orderFrontRegardless()
        startWatching()
    }
}

/// One thing on the ring.
enum Petal: Identifiable {
    case item(Snippet)
    /// Stands for the items that didn't fit; opens the full list.
    case more(Int)

    var id: String {
        switch self {
        case .item(let snippet): return snippet.id.uuidString
        case .more: return "more"
        }
    }
}

/// Everything the view needs, worked out by the controller.
struct RadialPlan {
    var petals: [Petal]
    var offsets: [CGPoint]
    var side: CGFloat

    static let empty = RadialPlan(petals: [], offsets: [], side: 1)
}

struct RadialView: View {
    @ObservedObject var state: AppState
    let plan: RadialPlan

    var onHover: (Bool) -> Void = { _ in }
    var onPick: (Snippet) -> Void = { _ in }
    var onMore: () -> Void = {}

    var body: some View {
        ZStack {
            // Tracks the pointer across the whole ring without swallowing
            // clicks, so the pill in the middle stays usable.
            HoverTracker(onHover: onHover)

            ForEach(Array(plan.petals.enumerated()), id: \.element.id) { index, petal in
                petalView(petal)
                    .offset(
                        x: plan.offsets[index].x,
                        // SwiftUI's y grows downwards; the layout's grows up.
                        y: -plan.offsets[index].y
                    )
            }
        }
        .frame(width: plan.side, height: plan.side)
    }

    @ViewBuilder
    private func petalView(_ petal: Petal) -> some View {
        switch petal {
        case .item(let snippet):
            PetalButton(
                fill: snippet.color?.fill ?? NeutralSwatch.fill,
                caption: snippet.initials,
                help: snippet.isEmpty ? snippet.displayLabel : "\(snippet.displayLabel) — \(snippet.contentPreview)",
                action: { onPick(snippet) }
            )
        case .more(let count):
            PetalButton(
                fill: NeutralSwatch.fill,
                caption: "+\(count)",
                help: "\(count) more items — open the full list",
                action: onMore
            )
        }
    }
}

private struct PetalButton: View {
    let fill: Color
    let caption: String
    let help: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(fill)
                .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
                .overlay(
                    Text(caption)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(3)
                )
                .frame(width: RadialLayout.petalDiameter, height: RadialLayout.petalDiameter)
                .shadow(color: .black.opacity(0.28), radius: 5, y: 2)
                .scaleEffect(isHovering ? 1.09 : 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .help(help)
    }
}

/// Reports the pointer entering and leaving, without taking part in hit
/// testing — `hitTest` returns nil, but tracking areas still fire.
struct HoverTracker: NSViewRepresentable {
    let onHover: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = TrackingView()
        view.onHover = onHover
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? TrackingView)?.onHover = onHover
    }

    private final class TrackingView: NSView {
        var onHover: ((Bool) -> Void)?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(
                NSTrackingArea(
                    rect: .zero,
                    options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                    owner: self
                )
            )
        }

        override func mouseEntered(with event: NSEvent) { onHover?(true) }
        override func mouseExited(with event: NSEvent) { onHover?(false) }
    }
}
