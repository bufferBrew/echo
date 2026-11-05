import Foundation

struct HistoryViewModelTests {
    private let clips = [
        ClipboardItem(kind: .text, text: "Design notes"),
        ClipboardItem(kind: .image, imageFileName: "example.png"),
        ClipboardItem(kind: .text, text: "Release checklist")
    ]

    func testFiltersCombineWithSearchAndPreserveOrder() {
        let model = HistoryViewModel()
        expectEqual(model.filteredItems(from: clips), clips)
        model.filter = .text
        expectEqual(model.filteredItems(from: clips), [clips[0], clips[2]])
        model.searchText = "  DESIGN  "
        expectEqual(model.filteredItems(from: clips), [clips[0]])
        model.filter = .images
        assert(model.filteredItems(from: clips).isEmpty)
        model.searchText = "image"
        expectEqual(model.filteredItems(from: clips), [clips[1]])
    }

    func testChangingFilterAndSearchResetsSelection() {
        let model = HistoryViewModel()
        model.selectedIndex = 2
        model.filter = .images
        expectEqual(model.selectedIndex, 0)
        model.selectedIndex = 1
        model.searchText = "missing"
        expectEqual(model.selectedIndex, 0)
    }

    func testSelectionClampsWhenResultsShrinkOrDisappear() {
        let model = HistoryViewModel()
        model.moveSelection(by: 20, count: clips.count)
        expectEqual(model.selectedIndex, 2)
        model.moveSelection(by: 0, count: 1)
        expectEqual(model.selectedIndex, 0)
        model.moveSelection(by: -1, count: 0)
        expectEqual(model.selectedIndex, 0)
    }

    func testReopeningResetsSearchAndRequestsFocus() {
        let model = HistoryViewModel()
        let previousFocus = model.focusSearch
        model.filter = .images
        model.searchText = "missing"
        model.reset()
        expectEqual(model.filter, .all)
        expectEqual(model.searchText, "")
        expectEqual(model.selectedIndex, 0)
        assert(model.focusSearch != previousFocus)
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T) {
    precondition(actual == expected, "Expected \(expected), got \(actual)")
}

let tests = HistoryViewModelTests()
tests.testFiltersCombineWithSearchAndPreserveOrder()
tests.testChangingFilterAndSearchResetsSelection()
tests.testSelectionClampsWhenResultsShrinkOrDisappear()
tests.testReopeningResetsSearchAndRequestsFocus()
print("Passed 4 history navigation checks")
