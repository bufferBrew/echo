import AppKit

/// Polls the general pasteboard for changes and records new content into the history store.
final class ClipboardMonitor {
    private let store: HistoryStore
    private var timer: Timer?
    private var lastChangeCount: Int

    /// Set right before we programmatically write to the pasteboard (e.g. quick-paste)
    /// so the next detected change is treated as a re-use rather than a brand new item.
    var pendingProgrammaticItem: ClipboardItem?

    init(store: HistoryStore) {
        self.store = store
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let pending = pendingProgrammaticItem {
            pendingProgrammaticItem = nil
            store.touch(pending)
            return
        }

        if let image = readImage(from: pasteboard) {
            store.addImage(image)
        } else if let text = pasteboard.string(forType: .string), !text.isEmpty {
            store.addText(text)
        }
    }

    private func readImage(from pasteboard: NSPasteboard) -> NSImage? {
        let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
        guard pasteboard.types?.contains(where: imageTypes.contains) == true else { return nil }
        // Avoid treating plain file-path copies (e.g. Finder image files) as pasted images
        // unless actual image data is present.
        return NSImage(pasteboard: pasteboard)
    }
}

private extension NSImage {
    convenience init?(pasteboard: NSPasteboard) {
        guard let data = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) else { return nil }
        self.init(data: data)
    }
}
