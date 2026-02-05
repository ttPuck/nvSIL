import Foundation
import Cocoa

class Note: NSObject, Identifiable {
    let id: UUID
    var title: String
    var content: String
    var fileURL: URL
    var dateCreated: Date
    var dateModified: Date
    var tags: Set<String>
    var isPinned: Bool

    var fileName: String {
        fileURL.lastPathComponent
    }

    var preview: String {
        let text = content.plainText().trimmingCharacters(in: .whitespacesAndNewlines)
        return String(text.prefix(100))
    }

    init(id: UUID = UUID(),
         title: String,
         content: String,
         fileURL: URL,
         dateCreated: Date = Date(),
         dateModified: Date = Date(),
         tags: Set<String> = [],
         isPinned: Bool = false) {
        self.id = id
        self.title = title
        self.content = content
        self.fileURL = fileURL
        self.dateCreated = dateCreated
        self.dateModified = dateModified
        self.tags = tags
        self.isPinned = isPinned
        super.init()
    }
}


extension Note {
    override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? Note else { return false }
        return self.id == other.id
    }

    override var hash: Int {
        return id.hashValue
    }
}



extension String {
    func rtfAttributedString() -> NSAttributedString? {
        guard hasPrefix("{\\rtf"), let data = data(using: .utf8) else { return nil }
        return try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        )
    }

    func plainText() -> String {
        rtfAttributedString()?.string ?? self
    }
}
