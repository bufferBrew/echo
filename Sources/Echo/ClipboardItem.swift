import Foundation

struct ClipboardItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case text
        case image
    }

    let id: UUID
    let kind: Kind
    var text: String?
    var imageFileName: String?
    var date: Date

    init(id: UUID = UUID(), kind: Kind, text: String? = nil, imageFileName: String? = nil, date: Date = Date()) {
        self.id = id
        self.kind = kind
        self.text = text
        self.imageFileName = imageFileName
        self.date = date
    }

    var preview: String {
        switch kind {
        case .text:
            let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "(empty)" : trimmed
        case .image:
            return "[Image]"
        }
    }
}
