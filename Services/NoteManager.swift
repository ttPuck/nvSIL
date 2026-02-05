
import Foundation
import Cocoa

extension Notification.Name {
    static let notesDidChange = Notification.Name("notesDidChange")
    static let noteWasCreated = Notification.Name("noteWasCreated")
    static let noteWasUpdated = Notification.Name("noteWasUpdated")
    static let noteWasDeleted = Notification.Name("noteWasDeleted")
}

class NoteManager {
    static let shared = NoteManager()
    
    private(set) var notes: [Note] = []
    private(set) var notesDirectory: URL?
    
    private let fileManager = NoteFileManager()
    private var fileSystemWatcher: FileSystemWatcher?
    private var isReloading = false
    private var currentlyEditingNoteID: UUID?

    private init() {}
    
    
    
    func setNotesDirectory(_ directory: URL) throws {
        self.notesDirectory = directory
        fileSystemWatcher?.stopWatching()
        
        try loadNotes(from: directory)
        
        let watcher = FileSystemWatcher(monitoredDirectory: directory)
        watcher.onDirectoryChange = { [weak self] in
            self?.handleDirectoryChange()
        }
        watcher.startWatching()
        fileSystemWatcher = watcher
    }
    
    func reloadNotes() throws {
        guard let directory = notesDirectory else { return }
        try loadNotes(from: directory)
    }
    
    
    
    func loadNotes(from directory: URL) throws {
        let loadedNotes = try fileManager.loadNotes(from: directory)

        
        if let editingID = currentlyEditingNoteID,
           let currentNote = notes.first(where: { $0.id == editingID }) {
            
            notes = loadedNotes.map { loadedNote in
                if loadedNote.id == editingID {
                    return currentNote  
                }
                return loadedNote
            }
        } else {
            notes = loadedNotes
        }

        NotificationCenter.default.post(name: .notesDidChange, object: self)
    }
    
    @discardableResult
    func createNote(withTitle title: String, content: String = "") -> Note? {
        guard let directory = notesDirectory else { return nil }
        
        do {
            let note = try fileManager.createNoteFile(in: directory, title: title, content: content)
            notes.insert(note, at: 0)
            NotificationCenter.default.post(name: .noteWasCreated, object: self, userInfo: ["note": note])
            NotificationCenter.default.post(name: .notesDidChange, object: self)
            return note
        } catch {
            return nil
        }
    }
    
    func updateNote(_ note: Note, content: String) {
        note.content = content
        do {
            try fileManager.writeNote(note)
            NotificationCenter.default.post(name: .noteWasUpdated, object: self, userInfo: ["note": note])
            NotificationCenter.default.post(name: .notesDidChange, object: self)
        } catch {}
    }
    
    func updateNoteTags(_ note: Note) {
        do {
            try fileManager.writeTags(note.tags, to: note.fileURL)
            let now = Date()
            try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: note.fileURL.path)
            note.dateModified = now
            NotificationCenter.default.post(name: .noteWasUpdated, object: self, userInfo: ["note": note])
        } catch {}
    }
    
    func deleteNote(_ note: Note) {
        do {
            try fileManager.deleteNoteFile(at: note.fileURL)
            notes.removeAll { $0.id == note.id }
            NotificationCenter.default.post(name: .noteWasDeleted, object: self, userInfo: ["note": note])
            NotificationCenter.default.post(name: .notesDidChange, object: self)
        } catch {}
    }
    
    func renameNote(_ note: Note, to newTitle: String) throws {
        let newURL = try fileManager.renameNoteFile(note, to: newTitle)
        note.title = newTitle
        note.fileURL = newURL
        let now = Date()
        note.dateModified = now
        try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: newURL.path)

        if let updatedNote = try? fileManager.readNote(from: newURL) {
            note.content = updatedNote.content
        }
        
        NotificationCenter.default.post(name: .noteWasUpdated, object: self, userInfo: ["note": note])
        NotificationCenter.default.post(name: .notesDidChange, object: self)
    }
    
    
    
    private func handleDirectoryChange() {
        guard !isReloading else { return }
        isReloading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            try? self.reloadNotes()
            self.isReloading = false
        }
    }

    

    func setCurrentlyEditingNote(_ note: Note?) {
        currentlyEditingNoteID = note?.id
    }

    

    func togglePinNote(_ note: Note) {
        note.isPinned = !note.isPinned
        savePinState(for: note)
        sortNotes()
        NotificationCenter.default.post(name: .notesDidChange, object: self)
    }

    private func savePinState(for note: Note) {
        let pinData = note.isPinned ? "1" : "0"
        if let data = pinData.data(using: .utf8) {
            try? note.fileURL.setExtendedAttribute(data: data, forName: "nvSIL.pinned")
        }

        
        let now = Date()
        try? FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: note.fileURL.path)
        note.dateModified = now
    }

    private func sortNotes() {
        notes.sort { note1, note2 in
            
            if note1.isPinned != note2.isPinned {
                return note1.isPinned
            }
            
            return note1.dateModified > note2.dateModified
        }
    }

    

    func note(withID id: UUID) -> Note? {
        notes.first { $0.id == id }
    }

    func note(at url: URL) -> Note? {
        notes.first { $0.fileURL == url }
    }

    
    var allUniqueTags: Set<String> {
        notes.reduce(into: Set<String>()) { $0.formUnion($1.tags) }
    }

    
    var allNoteTitles: [String] {
        notes.map { $0.title }
    }

    
    func notesMatchingTitlePrefix(_ prefix: String) -> [Note] {
        let lowercasedPrefix = prefix.lowercased()
        return notes.filter { $0.title.lowercased().hasPrefix(lowercasedPrefix) }
    }

    
    func notesContainingTitle(_ substring: String) -> [Note] {
        let lowercasedSubstring = substring.lowercased()
        return notes.filter { $0.title.lowercased().contains(lowercasedSubstring) }
    }

    func createWelcomeNoteIfNeeded() {
        guard let directory = notesDirectory else { return }

        let title = "Welcome to nvSIL!"
        let fileURL = directory.appendingPathComponent("\(title).rtf")

        
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }

        let content = buildWelcomeNoteContent()

        guard let rtfData = try? content.data(
            from: NSRange(location: 0, length: content.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else { return }

        do {
            try rtfData.write(to: fileURL)

            let note = Note(
                title: title,
                content: String(data: rtfData, encoding: .utf8) ?? "",
                fileURL: fileURL,
                dateCreated: Date(),
                dateModified: Date()
            )
            notes.insert(note, at: 0)
            NotificationCenter.default.post(name: .notesDidChange, object: self)
        } catch {}
    }

    func createShortcutsNoteIfNeeded() {
        guard let directory = notesDirectory else { return }

        let title = "Useful Shortcuts!"
        let fileURL = directory.appendingPathComponent("\(title).rtf")

        
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }

        let content = buildShortcutsNoteContent()

        guard let rtfData = try? content.data(
            from: NSRange(location: 0, length: content.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else { return }

        do {
            try rtfData.write(to: fileURL)

            let note = Note(
                title: title,
                content: String(data: rtfData, encoding: .utf8) ?? "",
                fileURL: fileURL,
                dateCreated: Date(),
                dateModified: Date()
            )
            notes.insert(note, at: 0)
            NotificationCenter.default.post(name: .notesDidChange, object: self)
        } catch {}
    }

    private func buildShortcutsNoteContent() -> NSAttributedString {
        let result = NSMutableAttributedString()

        let bodyFont = NSFont(name: "Helvetica", size: 12) ?? NSFont.systemFont(ofSize: 12)
        let boldFont = NSFont(name: "Helvetica-Bold", size: 12) ?? NSFont.boldSystemFont(ofSize: 12)
        let headingFont = NSFont(name: "Helvetica-Bold", size: 16) ?? NSFont.boldSystemFont(ofSize: 16)

        let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont]
        let boldAttrs: [NSAttributedString.Key: Any] = [.font: boldFont]
        let headingAttrs: [NSAttributedString.Key: Any] = [.font: headingFont]

        result.append(NSAttributedString(string: "A quick reference for keyboard shortcuts in nvSIL.\n\n", attributes: bodyAttrs))

        
        result.append(NSAttributedString(string: "Navigation\n", attributes: headingAttrs))
        result.append(NSAttributedString(string: "Focus Search Field", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+L\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Select Next Note", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+J\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Select Previous Note", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+K\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Deselect Note", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+D\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Open Preferences", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+,\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Bring to Front", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Global hotkey (set in Preferences)\n\n", attributes: bodyAttrs))

        
        result.append(NSAttributedString(string: "Note Management\n", attributes: headingAttrs))
        result.append(NSAttributedString(string: "New Note", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Type in search field and press Enter\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Delete Note", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+Backspace\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Rename Note", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+R\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Edit Tags", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+Shift+T\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Pin/Unpin Note", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+Shift+P\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Export Note", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+E\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Show in Finder", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+Shift+R\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Copy Note URL", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+Option+C\n\n", attributes: bodyAttrs))

        
        result.append(NSAttributedString(string: "Text Formatting\n", attributes: headingAttrs))
        result.append(NSAttributedString(string: "Bold", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+B\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Italic", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+I\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Underline", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+U\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Strikethrough", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+Y\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Remove Formatting", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+T\n\n", attributes: bodyAttrs))

        
        result.append(NSAttributedString(string: "Indentation\n", attributes: headingAttrs))
        result.append(NSAttributedString(string: "Indent", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Tab (when enabled in Preferences)\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Outdent", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Shift+Tab\n\n", attributes: bodyAttrs))

        
        result.append(NSAttributedString(string: "Standard macOS Shortcuts\n", attributes: headingAttrs))
        result.append(NSAttributedString(string: "Cut", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+X\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Copy", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+C\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Paste", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+V\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Paste and Match Style", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+Shift+V\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Undo", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+Z\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Redo", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+Shift+Z\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Select All", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — Cmd+A\n", attributes: bodyAttrs))

        return result
    }

    private func buildWelcomeNoteContent() -> NSAttributedString {
        let result = NSMutableAttributedString()

        let bodyFont = NSFont(name: "Helvetica", size: 12) ?? NSFont.systemFont(ofSize: 12)
        let boldFont = NSFont(name: "Helvetica-Bold", size: 12) ?? NSFont.boldSystemFont(ofSize: 12)
        let headingFont = NSFont(name: "Helvetica-Bold", size: 16) ?? NSFont.boldSystemFont(ofSize: 16)
        let subheadingFont = NSFont(name: "Helvetica-Bold", size: 14) ?? NSFont.boldSystemFont(ofSize: 14)
        let italicFont = NSFont(name: "Helvetica-Oblique", size: 12) ?? NSFont.systemFont(ofSize: 12)

        let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont]
        let boldAttrs: [NSAttributedString.Key: Any] = [.font: boldFont]
        let headingAttrs: [NSAttributedString.Key: Any] = [.font: headingFont]
        let subheadingAttrs: [NSAttributedString.Key: Any] = [.font: subheadingFont]
        let italicAttrs: [NSAttributedString.Key: Any] = [.font: italicFont]

        result.append(NSAttributedString(string: "A lightweight, free and open source note-taking app for macOS, inspired by nvALT.\n\n", attributes: bodyAttrs))

        
        result.append(NSAttributedString(string: "Privacy & Philosophy\n", attributes: headingAttrs))
        result.append(NSAttributedString(string: "nvSIL is ", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "100% free and open source", attributes: boldAttrs))
        result.append(NSAttributedString(string: " (FOSS) and always will be.\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• ", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Your notes are stored locally", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — only in the folder you choose\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• No cloud sync ", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "(outside of your iCloud, of course!)", attributes: boldAttrs))
        result.append(NSAttributedString(string: ", no accounts, no tracking\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• ", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Zero telemetry", attributes: boldAttrs))
        result.append(NSAttributedString(string: " — I collect absolutely no data\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Your notes are just plain files (.rtf, .txt, .md) that you own forever\n\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Thank you for using nvSIL :) — ttPuck\n\n", attributes: italicAttrs))

        
        result.append(NSAttributedString(string: "Getting Started\n", attributes: headingAttrs))
        result.append(NSAttributedString(string: "1. Select a folder to store your notes\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "2. Start typing in the search field to create or find notes\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "3. Press Enter to create a new note or select an existing one\n\n", attributes: bodyAttrs))

        
        result.append(NSAttributedString(string: "Basic Usage\n", attributes: headingAttrs))

        result.append(NSAttributedString(string: "Creating Notes\n", attributes: subheadingAttrs))
        result.append(NSAttributedString(string: "• Type a title in the search field and press Enter\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• If no matching note exists, a new one is created\n\n", attributes: bodyAttrs))

        result.append(NSAttributedString(string: "Finding Notes\n", attributes: subheadingAttrs))
        result.append(NSAttributedString(string: "• Type in the search field to filter notes by title, content, or tags\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Use #tagname to search by tag\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Search matches are highlighted in note titles and content\n\n", attributes: bodyAttrs))

        result.append(NSAttributedString(string: "Wiki Links\n", attributes: subheadingAttrs))
        result.append(NSAttributedString(string: "• Type [[Note Title]] to link to another note\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Click the link to navigate (creates the note if it doesn't exist)\n\n", attributes: bodyAttrs))

        result.append(NSAttributedString(string: "Using Tags\n", attributes: subheadingAttrs))
        result.append(NSAttributedString(string: "• Press ", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Cmd+Shift+T", attributes: boldAttrs))
        result.append(NSAttributedString(string: " to edit tags for the selected note\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Enter tags separated by commas (e.g., \"work, urgent, project\")\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Tags appear in the Tags column of the note list\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Click on a tag to filter notes with that tag\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Type ", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "#tagname", attributes: boldAttrs))
        result.append(NSAttributedString(string: " in the search field to find notes by tag\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Type just ", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "#", attributes: boldAttrs))
        result.append(NSAttributedString(string: " to show all notes that have any tags\n\n", attributes: bodyAttrs))

        
        result.append(NSAttributedString(string: "Features\n", attributes: headingAttrs))
        result.append(NSAttributedString(string: "• Rich text editing with bold, italic, and strikethrough\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Pin important notes to the top of the list\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Tag notes and filter by tags\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Auto-pair brackets and quotes (optional)\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Tab key indentation\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• External changes are detected automatically\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Customizable fonts and colors\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Optional menu bar icon\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Global hotkey to bring app to front\n\n", attributes: bodyAttrs))

        
        result.append(NSAttributedString(string: "File Format\n", attributes: headingAttrs))
        result.append(NSAttributedString(string: "• Notes are stored as individual .rtf files (default)\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Also supports .txt and .md files\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• Tags are stored in file extended attributes\n\n", attributes: bodyAttrs))

        
        result.append(NSAttributedString(string: "Preferences\n", attributes: headingAttrs))
        result.append(NSAttributedString(string: "Access via ", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "nvSIL > Preferences", attributes: boldAttrs))
        result.append(NSAttributedString(string: " (Cmd+,)\n\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• ", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "General", attributes: boldAttrs))
        result.append(NSAttributedString(string: ": Text size, note linking, menu bar icon, quit behavior\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• ", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Notes", attributes: boldAttrs))
        result.append(NSAttributedString(string: ": Storage folder, file format, external change watching\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• ", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Editing", attributes: boldAttrs))
        result.append(NSAttributedString(string: ": Spelling, tab behavior, auto-pair, RTL support\n", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "• ", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Fonts & Colors", attributes: boldAttrs))
        result.append(NSAttributedString(string: ": Font, colors, search highlighting, grid lines\n\n", attributes: bodyAttrs))

        
        result.append(NSAttributedString(string: "History\n", attributes: headingAttrs))
        result.append(NSAttributedString(string: "nvSIL is a Swift reimplementation of ", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "nvALT", attributes: boldAttrs))
        result.append(NSAttributedString(string: ", which was itself a fork of the original ", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "Notational Velocity", attributes: boldAttrs))
        result.append(NSAttributedString(string: ".\n\n", attributes: bodyAttrs))

        result.append(NSAttributedString(string: "Notational Velocity", attributes: italicAttrs))
        result.append(NSAttributedString(string: " was created by Zachary Schneirov and became a beloved minimalist note-taking app for macOS. ", attributes: bodyAttrs))
        result.append(NSAttributedString(string: "nvALT", attributes: italicAttrs))
        result.append(NSAttributedString(string: " was developed by Brett Terpstra and David Halter, adding features like Markdown preview, horizontal layout, and theming while maintaining the core philosophy of fast, searchable notes.\n\n", attributes: bodyAttrs))

        result.append(NSAttributedString(string: "nvSIL continues this tradition with a modern Swift codebase, ensuring the app can run on current and future versions of macOS while preserving the simplicity and speed that made the originals so popular.\n", attributes: bodyAttrs))

        return result
    }
}
