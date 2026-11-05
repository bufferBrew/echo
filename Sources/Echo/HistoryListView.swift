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
                         ? "Copy text or an image to get started.\nYour last 300 clips stay on this Mac."
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
                                HistoryRow(store: store, item: item, isSelected: index == viewModel.selectedIndex) {
                                    viewModel.selectedIndex = index
                                    onSelect(item)
                                }
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
        .alert("Clear clipboard history?", isPresented: $confirmingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear History", role: .destructive, action: onClear)
        } message: {
            Text("All saved text and images will be removed from Echo. This cannot be undone.")
        }
    }
}

private struct HistoryRow: View {
    @ObservedObject var store: HistoryStore
    let item: ClipboardItem
    let isSelected: Bool
    var onSelect: () -> Void
    @State private var hovered = false
    @FocusState private var focused: Bool

    var body: some View {
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
                    Text(item.kind == .image ? "Image" : item.preview)
                        .font(.body)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: EchoStyle.small) {
                        Text(item.kind == .image ? "Image" : "Text")
                        Text("·")
                        Text(item.date, style: .relative)
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
        .background(isSelected ? Color.accentColor.opacity(0.12) : hovered ? Color.primary.opacity(0.05) : .clear,
                    in: RoundedRectangle(cornerRadius: EchoStyle.radius))
        .overlay {
            RoundedRectangle(cornerRadius: EchoStyle.radius)
                .strokeBorder(focused ? Color.accentColor : .clear, lineWidth: 2)
        }
        .onHover { hovered = $0 }
        .help("Paste this \(item.kind.rawValue) clip")
        .accessibilityHint("Copies this clip and pastes it into the previous app")
    }
}
