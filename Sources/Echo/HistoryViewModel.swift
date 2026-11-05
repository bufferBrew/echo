import Foundation
import Combine

/// Shared search/selection state for the history popup, used by both the
/// SwiftUI list (for rendering) and StatusBarController (for keyboard handling).
final class HistoryViewModel: ObservableObject {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", text = "Text", images = "Images"
        var id: String { rawValue }
    }

    @Published var filter: Filter = .all {
        didSet { selectedIndex = 0 }
    }
    @Published var focusSearch = UUID()
    @Published var searchText: String = "" {
        didSet { selectedIndex = 0 }
    }
    @Published var selectedIndex: Int = 0

    func filteredItems(from items: [ClipboardItem]) -> [ClipboardItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return items.filter { item in
            let matchesKind = filter == .all || (filter == .text ? item.kind == .text : item.kind == .image)
            let searchable = item.isSensitive ? (item.alias ?? "") : [item.alias, item.text, item.preview].compactMap { $0 }.joined(separator: " ")
            return matchesKind && (query.isEmpty || searchable.localizedCaseInsensitiveContains(query))
        }
    }

    func moveSelection(by delta: Int, count: Int) {
        guard count > 0 else {
            selectedIndex = 0
            return
        }
        selectedIndex = min(max(selectedIndex + delta, 0), count - 1)
    }

    func resetSelection() {
        selectedIndex = 0
    }

    func reset() {
        filter = .all
        searchText = ""
        focusSearch = UUID()
        selectedIndex = 0
    }
}
