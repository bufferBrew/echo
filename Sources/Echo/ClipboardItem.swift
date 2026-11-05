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
    var isPinned: Bool = false
    var alias: String?
    var isSensitive: Bool = false

    init(id: UUID = UUID(), kind: Kind, text: String? = nil, imageFileName: String? = nil, date: Date = Date()) {
        self.id = id
        self.kind = kind
        self.text = text
        self.imageFileName = imageFileName
        self.date = date
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, text, imageFileName, date, isPinned, alias, isSensitive
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        kind = try values.decode(Kind.self, forKey: .kind)
        text = try values.decodeIfPresent(String.self, forKey: .text)
        imageFileName = try values.decodeIfPresent(String.self, forKey: .imageFileName)
        date = try values.decode(Date.self, forKey: .date)
        isPinned = try values.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        alias = try values.decodeIfPresent(String.self, forKey: .alias)
        isSensitive = try values.decodeIfPresent(Bool.self, forKey: .isSensitive) ?? false
    }

    var preview: String {
        if let alias, !alias.isEmpty { return alias }
        if isSensitive { return "Hidden text" }
        switch kind {
        case .text:
            let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "(empty)" : trimmed
        case .image:
            return "[Image]"
        }
    }
}
