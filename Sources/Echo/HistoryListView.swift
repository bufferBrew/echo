import SwiftUI

/// Shared native macOS surfaces and the existing 4/8-point spacing scale.
enum EchoStyle {
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let large: CGFloat = 12
    static let inset: CGFloat = 16
    static let radius: CGFloat = 8
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let background = Color(nsColor: .windowBackgroundColor)
}

struct HistoryListView: View {
    @ObservedObject var store: HistoryStore
    @ObservedObject var viewModel: HistoryViewModel
    var onSelect: (ClipboardItem) -> Void
    var onClear: () -> Void
    var onSettings: () -> Void
    @FocusState private var searchFocused: Bool
    @State private var confirmingClear = false
    @State private var editingItem: ClipboardItem?
    @State private var editingAsCopy = true

    private var filtered: [ClipboardItem] {
        viewModel.filteredItems(from: store.items)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: EchoStyle.medium) {
                HStack(spacing: EchoStyle.medium) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    Text("Echo").font(.title3.weight(.semibold))
                    Spacer()
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                            .frame(minWidth: 24, minHeight: 24)
                    }
                    .buttonStyle(.borderless)
                    .help("Settings (⌘,)")
                    .accessibilityLabel("Open Echo settings")
                    Menu {
                        Button("Settings…", action: onSettings)
                        Divider()
                        Button("Clear History…", role: .destructive) { confirmingClear = true }
                            .disabled(store.items.isEmpty)
                        Divider()
                        Button("Quit Echo") { NSApp.terminate(nil) }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .frame(minWidth: 24, minHeight: 24)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Echo menu")
                    .accessibilityLabel("Echo menu")
                }
                HStack(spacing: EchoStyle.medium) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField("Search clipboard history", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .accessibilityLabel("Search clipboard history")
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                            searchFocused = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .frame(minWidth: 24, minHeight: 24)
                        }
                        .buttonStyle(.borderless)
                        .help("Clear search")
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(EchoStyle.medium)
                .background(EchoStyle.surface, in: RoundedRectangle(cornerRadius: EchoStyle.radius))
                .overlay {
                    RoundedRectangle(cornerRadius: EchoStyle.radius)
                        .strokeBorder(searchFocused ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                }
                Picker("Show", selection: $viewModel.filter) {
                    ForEach(HistoryViewModel.Filter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Filter clipboard history")
            }
            .padding(EchoStyle.large)

            Divider()

            if filtered.isEmpty {
                VStack(spacing: EchoStyle.medium) {
                    Image(systemName: store.items.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(store.items.isEmpty ? "Your clipboard, remembered" : "No matching clips")
                        .font(.headline)
                    Text(store.items.isEmpty
                         ? "Copy text or an image to get started.\n300 recent clips plus your pins stay on this Mac."
                         : "Try another search or choose a different filter.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    if !store.items.isEmpty {
                        Button("Show all clips") { viewModel.reset() }
                    }
                }
                .padding(EchoStyle.inset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            HStack {
                                Text(viewModel.searchText.isEmpty ? "RECENT CLIPS" : "SEARCH RESULTS")
                                Spacer()
                                Text("\(filtered.count)")
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, EchoStyle.medium)
                            .padding(.vertical, EchoStyle.small)
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, item in
                                HistoryRow(
                                    store: store, item: item, isSelected: index == viewModel.selectedIndex,
                                    onSelect: {
                                        viewModel.selectedIndex = index
                                        onSelect(item)
                                    },
                                    onFocus: { viewModel.selectedIndex = index },
                                    onEdit: { asCopy in
                                        editingAsCopy = asCopy
                                        editingItem = item
                                    }
                                )
                                .id(item.id)
                            }
                        }
                        .padding(EchoStyle.medium)
                    }
                    .onChange(of: viewModel.selectedIndex) { newValue in
                        guard filtered.indices.contains(newValue) else { return }
                        proxy.scrollTo(filtered[newValue].id)
                    }
                    .onChange(of: filtered.map(\.id)) { _ in
                        viewModel.moveSelection(by: 0, count: filtered.count)
                        if let first = filtered.first { proxy.scrollTo(first.id, anchor: .top) }
                    }
                }
            }

            Divider()
            ViewThatFits(in: .horizontal) {
                HStack {
                    Label("Navigate", systemImage: "arrow.up.arrow.down")
                    Label("Paste", systemImage: "return")
                    Spacer()
                    Text("esc Close")
                }
                HStack {
                    Text("↑↓ Navigate · ↵ Paste")
                    Spacer()
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(EchoStyle.large)
        }
        .background(EchoStyle.background)
        .frame(minWidth: 300, minHeight: 320)
        .onAppear { searchFocused = true }
        .onReceive(viewModel.$focusSearch) { _ in searchFocused = true }
        .sheet(item: $editingItem) { item in
            TextClipEditor(item: item, asCopy: editingAsCopy) { text, alias, hidden in
                let savedID = store.saveText(text, alias: alias, isSensitive: hidden, replacing: editingAsCopy ? nil : item)
                viewModel.reset()
                if let index = store.items.firstIndex(where: { $0.id == savedID }) {
                    viewModel.selectedIndex = index
                }
            }
        }
        .alert("Clear clipboard history?", isPresented: $confirmingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear History", role: .destructive, action: onClear)
        } message: {
            Text("All saved text and images, including pinned clips, will be removed from Echo. This cannot be undone.")
        }
    }
}

private struct HistoryRow: View {
    @ObservedObject var store: HistoryStore
    let item: ClipboardItem
    let isSelected: Bool
    var onSelect: () -> Void
    var onFocus: () -> Void
    var onEdit: (Bool) -> Void
    @State private var hovered = false
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onSelect) {
                HStack(alignment: .center, spacing: EchoStyle.medium) {
                    Group {
                        if item.kind == .image, let image = store.image(for: item) {
                            Image(nsImage: image).resizable().scaledToFit()
                        } else {
                            Image(systemName: item.kind == .image ? "photo" : "text.alignleft")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 24, height: 24)
                    .background(EchoStyle.surface, in: RoundedRectangle(cornerRadius: EchoStyle.small))
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: EchoStyle.small) {
                        Text(item.preview)
                            .font(.body)
                            .lineLimit(1)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: EchoStyle.small) {
                            if item.isPinned {
                                Label("Pinned", systemImage: "pin.fill")
                            } else {
                                Text(item.kind == .image ? "Image" : "Text")
                            }
                            if item.isSensitive {
                                Label("Hidden", systemImage: "eye.slash")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    if isSelected {
                        Image(systemName: "return")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Selected clip")
                    }
                }
                .padding(.horizontal, EchoStyle.medium)
                .padding(.vertical, EchoStyle.small)
                .contentShape(RoundedRectangle(cornerRadius: EchoStyle.radius))
            }
            .buttonStyle(.borderless)
            .focused($focused)
            .onChange(of: focused) { if $0 { onFocus() } }
            .accessibilityHint("Copies this clip and pastes it into the previous app")
            Menu {
                actions
            } label: {
                Image(systemName: "ellipsis")
                    .frame(minWidth: 24, minHeight: 24)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .padding(.trailing, EchoStyle.small)
            .help("Clip actions")
            .accessibilityLabel("Actions for \(item.preview)")
        }
        .background(isSelected ? Color.accentColor.opacity(0.12) : hovered ? Color.primary.opacity(0.05) : .clear,
                    in: RoundedRectangle(cornerRadius: EchoStyle.radius))
        .overlay {
            RoundedRectangle(cornerRadius: EchoStyle.radius)
                .strokeBorder(focused ? Color.accentColor : .clear, lineWidth: 2)
        }
        .onHover { hovered = $0 }
        .help("Copied \(item.date.formatted(date: .abbreviated, time: .standard))")
        .contextMenu { actions }
    }

    @ViewBuilder private var actions: some View {
        Button { store.togglePin(item) } label: {
            Label(item.isPinned ? "Unpin" : "Pin to Top", systemImage: item.isPinned ? "pin.slash" : "pin")
        }
        if item.kind == .text {
            Button { onEdit(false) } label: {
                Label("Edit Clip…", systemImage: "pencil")
            }
            Button { onEdit(true) } label: {
                Label("Edit as New Clip…", systemImage: "square.and.pencil")
            }
        }
        Divider()
        Button(role: .destructive) { store.remove(item) } label: {
            Label("Remove from History", systemImage: "trash")
        }
    }
}

private struct TextClipEditor: View {
    let item: ClipboardItem
    let asCopy: Bool
    var onSave: (String, String, Bool) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var alias: String
    @State private var hidden: Bool
    @State private var revealingText = false
    @FocusState private var editorFocused: Bool

    init(item: ClipboardItem, asCopy: Bool, onSave: @escaping (String, String, Bool) -> Void) {
        self.item = item
        self.asCopy = asCopy
        self.onSave = onSave
        _text = State(initialValue: item.text ?? "")
        _alias = State(initialValue: item.alias ?? "")
        _hidden = State(initialValue: item.isSensitive)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EchoStyle.large) {
            Text(asCopy ? "Edit as New Clip" : "Edit Clip").font(.headline)
            Text(asCopy ? "Keep a fragment or rewrite the text. Your original clip stays in history." : "Update this clip's text, alias, or visibility.")
                .font(.callout).foregroundStyle(.secondary)
            TextField("Alias (optional)", text: $alias)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search alias")
            Toggle("Hide clip contents", isOn: $hidden)
                .onChange(of: hidden) { _ in revealingText = false }
            if hidden && !revealingText {
                SecureField("Hidden text", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Hidden clip text")
            } else {
                TextEditor(text: $text)
                    .font(.body)
                    .focused($editorFocused)
                    .frame(minHeight: 120, idealHeight: 180)
                    .padding(EchoStyle.small)
                    .overlay {
                        RoundedRectangle(cornerRadius: EchoStyle.small)
                            .strokeBorder(editorFocused ? Color.accentColor : Color.secondary.opacity(0.3))
                    }
                    .accessibilityLabel("Clip text")
            }
            if hidden {
                Toggle("Show text in editor", isOn: $revealingText)
                Text("Hidden clips show only their alias and are searchable by alias. History is stored unencrypted on this Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(asCopy ? "Save New Clip" : "Save Changes") {
                    onSave(text, alias, hidden)
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (hidden && alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }
        }
        .padding(EchoStyle.inset)
        .frame(minWidth: 380, idealWidth: 420)
        .onAppear { editorFocused = true }
    }
}
