import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private let notesDirectoryBookmarkKey = "notesDirectoryBookmark"
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        NSApp.appearance = NSAppearance(named: .aqua)

        
        setupMenuBarIcon()

        
        _ = HotkeyManager.shared

        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange),
            name: .preferencesDidChange,
            object: nil
        )

        promptForNotesDirectory()
    }

    @objc private func preferencesDidChange() {
        setupMenuBarIcon()
    }

    private func setupMenuBarIcon() {
        if Preferences.shared.showMenuBarIcon {
            if statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                if let button = statusItem?.button {
                    
                    if let appIcon = NSApp.applicationIconImage {
                        let size = NSSize(width: 18, height: 18)
                        let scaledIcon = NSImage(size: size)
                        scaledIcon.lockFocus()
                        appIcon.draw(in: NSRect(origin: .zero, size: size),
                                    from: NSRect(origin: .zero, size: appIcon.size),
                                    operation: .copy,
                                    fraction: 1.0)
                        scaledIcon.unlockFocus()
                        scaledIcon.isTemplate = false
                        button.image = scaledIcon
                    } else {
                        button.image = NSImage(systemSymbolName: "doc.text", accessibilityDescription: "nvSIL")
                    }
                    button.action = #selector(statusItemClicked)
                    button.target = self
                }
            }
        } else {
            if let statusItem = statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
        }
    }

    @objc private func statusItemClicked() {
        
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    @objc func toggleBold(_ sender: Any?) {
        NSApp.sendAction(#selector(EditorViewController.toggleBold(_:)), to: nil, from: sender)
    }

    @objc func toggleItalic(_ sender: Any?) {
        NSApp.sendAction(#selector(EditorViewController.toggleItalic(_:)), to: nil, from: sender)
    }

    @objc func toggleStrikethrough(_ sender: Any?) {
        NSApp.sendAction(#selector(EditorViewController.toggleStrikethrough(_:)), to: nil, from: sender)
    }

    @objc func removeFormatting(_ sender: Any?) {
        NSApp.sendAction(#selector(EditorViewController.removeFormatting(_:)), to: nil, from: sender)
    }

    @IBAction func showPreferences(_ sender: Any?) {
        PreferencesWindowController.shared.showWindow()
    }

    func applicationWillTerminate(_ aNotification: Notification) {}

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    

    private func promptForNotesDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.message = "Choose a folder for your notes"
        openPanel.prompt = "Select Folder"
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.canCreateDirectories = true
        openPanel.allowsMultipleSelection = false

        openPanel.begin { [weak self] response in
            guard response == .OK, let url = openPanel.url else { return }

            guard url.startAccessingSecurityScopedResource() else {
                self?.showError("Permission Error", message: "Unable to access the selected folder.")
                return
            }

            self?.loadNotesDirectory(url)
        }
    }

    private func loadNotesDirectory(_ directory: URL) {
        do {
            try NoteManager.shared.setNotesDirectory(directory)
            NoteManager.shared.createWelcomeNoteIfNeeded()
            NoteManager.shared.createShortcutsNoteIfNeeded()
        } catch {
            showError("Failed to load notes", message: error.localizedDescription)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.promptForNotesDirectory()
            }
        }
    }

    private func saveDirectoryBookmark(_ directory: URL) {
        if let bookmarkData = try? directory.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(bookmarkData, forKey: notesDirectoryBookmarkKey)
        }
    }

    private func restoreDirectoryFromBookmark(_ bookmarkData: Data) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale {
            saveDirectoryBookmark(url)
        }

        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    private func showError(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
