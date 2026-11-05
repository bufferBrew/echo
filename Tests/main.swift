import Foundation
import AppKit

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

func withStore(_ check: (HistoryStore, URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("echo-tests-\(UUID())")
    defer { try? FileManager.default.removeItem(at: directory) }
    try check(HistoryStore(directory: directory), directory)
}

func testLegacyHistoryStillDecodes() throws {
    let clip = ClipboardItem(kind: .text, text: "Existing history")
    var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(clip)) as! [String: Any]
    object.removeValue(forKey: "isPinned")
    object.removeValue(forKey: "isSensitive")
    object.removeValue(forKey: "alias")
    let loaded = try JSONDecoder().decode(ClipboardItem.self, from: JSONSerialization.data(withJSONObject: object))
    expectEqual(loaded, clip)
}

func testPinSurvivesRecopyAndHistoryLimit() throws {
    try withStore { store, directory in
        store.addText("Keep me")
        let pinned = store.items[0]
        store.togglePin(pinned)
        for index in 0..<302 { store.addText("Recent \(index)") }
        expectEqual(store.items.count, 301)
        expectEqual(store.items.first?.id, pinned.id)
        store.addText("Keep me")
        expectEqual(store.items.first?.id, pinned.id)
        expectEqual(store.items.first?.isPinned, true)
        let reloaded = HistoryStore(directory: directory)
        expectEqual(reloaded.items, store.items)
        store.togglePin(store.items[0])
        expectEqual(store.items.count, 300)
        assert(store.items.allSatisfy { !$0.isPinned })
    }
}

func testEditCopyAndHiddenAliasSearch() throws {
    try withStore { store, directory in
        store.addText("Original full text")
        let original = store.items[0]
        expectEqual(store.saveText(" ", alias: "", isSensitive: false), nil)
        expectEqual(store.saveText("Secret", alias: " ", isSensitive: true), nil)
        expectEqual(store.items.count, 1)
        store.saveText("full text", alias: "Snippet", isSensitive: false)
        expectEqual(store.items.count, 2)
        assert(store.items.contains(original))
        let newClip = store.items[0]
        store.togglePin(newClip)
        store.saveText("sample-secret-value", alias: "Work login", isSensitive: true, replacing: newClip)
        let hidden = store.items[0]
        expectEqual(hidden.id, newClip.id)
        expectEqual(hidden.isPinned, true)
        expectEqual(hidden.preview, "Work login")
        expectEqual(store.items.count, 2)
        let model = HistoryViewModel()
        model.searchText = "work LOGIN"
        expectEqual(model.filteredItems(from: store.items), [hidden])
        model.searchText = "sample-secret-value"
        assert(model.filteredItems(from: store.items).isEmpty)
        let reloaded = HistoryStore(directory: directory)
        expectEqual(reloaded.items, store.items)
        store.remove(hidden)
        expectEqual(store.items, [original])
    }
}

func testRemovingImagesDeletesTheirFile() throws {
    try withStore { store, directory in
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()
        store.addImage(image)
        expectEqual(store.items.count, 1)
        let clip = store.items[0]
        let file = directory.appendingPathComponent("Images").appendingPathComponent(clip.imageFileName!)
        assert(FileManager.default.fileExists(atPath: file.path))
        store.remove(clip)
        assert(store.items.isEmpty)
        assert(!FileManager.default.fileExists(atPath: file.path))
        assert(HistoryStore(directory: directory).items.isEmpty)
    }
}

let tests = HistoryViewModelTests()
tests.testFiltersCombineWithSearchAndPreserveOrder()
tests.testChangingFilterAndSearchResetsSelection()
tests.testSelectionClampsWhenResultsShrinkOrDisappear()
tests.testReopeningResetsSearchAndRequestsFocus()
try testLegacyHistoryStillDecodes()
try testPinSurvivesRecopyAndHistoryLimit()
try testEditCopyAndHiddenAliasSearch()
try testRemovingImagesDeletesTheirFile()
print("Passed 8 navigation and history checks")
