import AppKit
import Combine

final class HistoryStore: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []

    private let maxItems = 300
    private let supportDir: URL
    private let imagesDir: URL
    private let indexFile: URL

    init(directory: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        supportDir = directory ?? base.appendingPathComponent("Echo", isDirectory: true)
        imagesDir = supportDir.appendingPathComponent("Images", isDirectory: true)
        indexFile = supportDir.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Mutations

    func addText(_ text: String) {
        if let existing = items.first(where: { $0.kind == .text && $0.text == text }) {
            touch(existing) // Recopying a pinned clip must preserve its identity and pin.
            return
        }
        items.insert(ClipboardItem(kind: .text, text: text), at: 0)
        trimAndSave()
    }

    func addImage(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }

        let fileName = "\(UUID().uuidString).png"
        let url = imagesDir.appendingPathComponent(fileName)
        try? png.write(to: url)

        items.insert(ClipboardItem(kind: .image, imageFileName: fileName), at: 0)
        trimAndSave()
    }

    /// Move an existing item back to the top (used when re-pasting from history).
    func touch(_ item: ClipboardItem) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        let existing = items.remove(at: idx)
        items.insert(existing, at: 0)
        trimAndSave()
    }

    /// Save an explicit edit without rewriting or deduplicating its source clip.
    @discardableResult
    func saveText(_ text: String, alias: String, isSensitive: Bool, replacing item: ClipboardItem? = nil) -> UUID? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let name = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSensitive || !name.isEmpty else { return nil }
        let savedID: UUID
        if let item {
            guard item.kind == .text,
                  let index = items.firstIndex(where: { $0.id == item.id }) else { return nil }
            items[index].text = text
            items[index].alias = name.isEmpty ? nil : name
            items[index].isSensitive = isSensitive
            savedID = item.id
        } else {
            var clip = ClipboardItem(kind: .text, text: text)
            clip.alias = name.isEmpty ? nil : name
            clip.isSensitive = isSensitive
            savedID = clip.id
            items.insert(clip, at: 0)
        }
        trimAndSave()
        return savedID
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        trimAndSave()
    }

    func remove(_ item: ClipboardItem) {
        if item.kind == .image, let name = item.imageFileName {
            try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(name))
        }
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearAll() {
        for item in items where item.kind == .image {
            if let name = item.imageFileName {
                try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(name))
            }
        }
        items.removeAll()
        save()
    }

    func image(for item: ClipboardItem) -> NSImage? {
        guard item.kind == .image, let name = item.imageFileName else { return nil }
        return NSImage(contentsOf: imagesDir.appendingPathComponent(name))
    }

    // MARK: - Persistence

    private func trimAndSave() {
        let pinned = items.filter(\.isPinned)
        let recent = items.filter { !$0.isPinned }
        for item in recent.dropFirst(maxItems) where item.kind == .image {
            if let name = item.imageFileName {
                try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(name))
            }
        }
        items = pinned + recent.prefix(maxItems)
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: indexFile, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexFile),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else { return }
        items = decoded.filter(\.isPinned) + decoded.filter { !$0.isPinned }
    }
}
