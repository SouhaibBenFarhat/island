import SwiftUI
import IslandCore

/// The window where you add, rename, reorder and delete items.
struct EditorView: View {
    @ObservedObject var state: AppState
    @State private var selection: Snippet.ID?

    var body: some View {
        HStack(spacing: 0) {
            list
                .frame(width: 220)
                .background(Color(nsColor: .underPageBackgroundColor))

            Divider()

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 640, minHeight: 380)
        .onAppear { if selection == nil { selection = state.library.snippets.first?.id } }
    }

    // MARK: - List

    private var list: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(state.library.snippets) { snippet in
                    HStack(spacing: 8) {
                        Text(snippet.displayLabel)
                            .font(.system(size: 12.5))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        if snippet.isEmpty {
                            Image(systemName: "circle.dashed")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                                .help("No text yet")
                        }
                    }
                    .padding(.vertical, 2)
                    .tag(snippet.id)
                }
                .onMove(perform: move)
            }
            .listStyle(.sidebar)
            .environment(\.defaultMinListRowHeight, 26)

            Divider()

            HStack(spacing: 2) {
                toolbarButton(symbol: "plus", help: "Add item") {
                    selection = state.addSnippet().id
                }
                toolbarButton(symbol: "minus", help: "Delete item", isEnabled: selection != nil) {
                    guard let selection else { return }
                    let next = neighbourID(of: selection)
                    state.remove(id: selection)
                    self.selection = next
                }
                Spacer()
                Text("Drag to reorder")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
        }
    }

    private func toolbarButton(
        symbol: String,
        help: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!isEnabled)
        .help(help)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let id = selection, let snippet = state.library[id] {
            SnippetForm(snippet: snippet) { state.update($0) }
                .id(id)
        } else {
            VStack(spacing: 10) {
                IslandMark(width: 34, opacity: 0.25)
                Text(state.library.isEmpty ? "No items yet" : "Select an item")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                if state.library.isEmpty {
                    Button("Add your first item") { selection = state.addSnippet().id }
                        .buttonStyle(.link)
                        .font(.system(size: 12))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Helpers

    private func move(from source: IndexSet, to destination: Int) {
        guard let from = source.first else { return }
        // SwiftUI's destination is an insertion point in the *old* array;
        // SnippetLibrary works in final indexes.
        state.move(from: from, to: from < destination ? destination - 1 : destination)
    }

    private func neighbourID(of id: Snippet.ID) -> Snippet.ID? {
        guard let index = state.library.index(of: id) else { return nil }
        let snippets = state.library.snippets
        if index + 1 < snippets.count { return snippets[index + 1].id }
        if index > 0 { return snippets[index - 1].id }
        return nil
    }
}

/// The editing form for one snippet. Keeps a local copy so typing stays smooth,
/// and pushes every change up so nothing needs saving by hand.
private struct SnippetForm: View {
    @State private var draft: Snippet
    private let commit: (Snippet) -> Void

    init(snippet: Snippet, commit: @escaping (Snippet) -> Void) {
        _draft = State(initialValue: snippet)
        self.commit = commit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            field(title: "Label") {
                TextField("Shown on the chip", text: $draft.label)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
            }

            field(title: "Content") {
                TextEditor(text: $draft.content)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
                    .frame(minHeight: 160)
            }

            placeholderLegend
        }
        .padding(20)
        .onChange(of: draft) { _, new in commit(new) }
    }

    private func field<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var placeholderLegend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Placeholders")
                .font(.system(size: 10, weight: .medium))
                .tracking(1.4)
                .foregroundStyle(.secondary)
            Text(verbatim: "{{date}} · {{time}} · {{datetime}} · {{clipboard}} · {{uuid}}")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(verbatim: "Custom formats too: {{date:MMM d, yyyy}}")
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)
        }
    }
}
