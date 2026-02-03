import Cocoa

class PreferencesWindowController: NSWindowController {

    static let shared = PreferencesWindowController()

    private var tabView: NSTabView!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "General"
        window.center()

        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let window = window else { return }

        
        tabView = NSTabView(frame: NSRect(x: 0, y: 0, width: 480, height: 520))
        tabView.tabViewType = .topTabsBezelBorder
        tabView.translatesAutoresizingMaskIntoConstraints = false

        let generalTab = createGeneralTab()
        let notesTab = createNotesTab()
        let editingTab = createEditingTab()
        let fontsColorsTab = createFontsColorsTab()

        tabView.addTabViewItem(generalTab)
        tabView.addTabViewItem(notesTab)
        tabView.addTabViewItem(editingTab)
        tabView.addTabViewItem(fontsColorsTab)

        window.contentView = tabView

        tabView.delegate = self
    }

   

    private func createGeneralTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "general")
        item.label = "General"
        item.image = NSImage(named: NSImage.preferencesGeneralName)

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 440))

        var yPos: CGFloat = 390

      
        let listSizeLabel = createLabel("List Text Size:", at: NSPoint(x: 100, y: yPos), alignment: .right, width: 140)
        view.addSubview(listSizeLabel)

        let listSizePopup = NSPopUpButton(frame: NSRect(x: 250, y: yPos - 2, width: 120, height: 26), pullsDown: false)
        listSizePopup.addItems(withTitles: Preferences.ListTextSize.allCases.map { $0.rawValue })
        listSizePopup.selectItem(withTitle: Preferences.shared.listTextSize.rawValue)
        listSizePopup.target = self
        listSizePopup.action = #selector(listTextSizeChanged(_:))
        view.addSubview(listSizePopup)

        yPos -= 50

        let hotkeyLabel = createLabel("Bring-to-Front Hotkey:", at: NSPoint(x: 60, y: yPos), alignment: .right, width: 180)
        view.addSubview(hotkeyLabel)

        let hotkeyRecorder = KeyRecorderView(frame: NSRect(x: 250, y: yPos - 2, width: 170, height: 24))
        hotkeyRecorder.keyCombo = Preferences.shared.bringToFrontHotkey
        hotkeyRecorder.onKeyComboChanged = { newCombo in
            Preferences.shared.bringToFrontHotkey = newCombo
        }
        view.addSubview(hotkeyRecorder)

        yPos -= 55


        let autoSelectCheck = NSButton(checkboxWithTitle: "Auto-select notes by title when searching", target: self, action: #selector(autoSelectChanged(_:)))
        autoSelectCheck.frame = NSRect(x: 50, y: yPos, width: 350, height: 20)
        autoSelectCheck.state = Preferences.shared.autoSelectNotesByTitle ? .on : .off
        view.addSubview(autoSelectCheck)

        yPos -= 22
        let autoSelectNote = createLabel("Automatically selecting very long notes may affect\nresponsiveness.", at: NSPoint(x: 70, y: yPos - 10), alignment: .left, width: 350)
        autoSelectNote.font = NSFont.systemFont(ofSize: 11)
        autoSelectNote.textColor = .secondaryLabelColor
        view.addSubview(autoSelectNote)

        yPos -= 55

        let noteLinkingCheck = NSButton(checkboxWithTitle: "Enable note linking ([[wiki links]])", target: self, action: #selector(noteLinkingChanged(_:)))
        noteLinkingCheck.frame = NSRect(x: 50, y: yPos, width: 350, height: 20)
        noteLinkingCheck.state = Preferences.shared.enableNoteLinking ? .on : .off
        view.addSubview(noteLinkingCheck)

        yPos -= 40

        let confirmDeleteCheck = NSButton(checkboxWithTitle: "Confirm note deletion", target: self, action: #selector(confirmDeleteChanged(_:)))
        confirmDeleteCheck.frame = NSRect(x: 50, y: yPos, width: 350, height: 20)
        confirmDeleteCheck.state = Preferences.shared.confirmNoteDeletion ? .on : .off
        view.addSubview(confirmDeleteCheck)

        yPos -= 35

        let quitOnCloseCheck = NSButton(checkboxWithTitle: "Quit when closing window", target: self, action: #selector(quitOnCloseChanged(_:)))
        quitOnCloseCheck.frame = NSRect(x: 50, y: yPos, width: 350, height: 20)
        quitOnCloseCheck.state = Preferences.shared.quitWhenClosingWindow ? .on : .off
        view.addSubview(quitOnCloseCheck)

        yPos -= 35

        let menuBarCheck = NSButton(checkboxWithTitle: "Show menu bar icon", target: self, action: #selector(menuBarIconChanged(_:)))
        menuBarCheck.frame = NSRect(x: 50, y: yPos, width: 350, height: 20)
        menuBarCheck.state = Preferences.shared.showMenuBarIcon ? .on : .off
        view.addSubview(menuBarCheck)

        yPos -= 45

        let hideDockButton = NSButton(frame: NSRect(x: 50, y: yPos, width: 140, height: 28))
        hideDockButton.title = "Hide Dock Icon"
        hideDockButton.bezelStyle = .rounded
        hideDockButton.target = self
        hideDockButton.action = #selector(hideDockIconClicked(_:))
        view.addSubview(hideDockButton)

        item.view = view
        return item
    }


    private func createNotesTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "notes")
        item.label = "Notes"
        item.image = NSImage(named: NSImage.folderName)

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 440))

        var yPos: CGFloat = 390

        let folderLabel = createLabel("Read notes from folder:", at: NSPoint(x: 30, y: yPos), alignment: .right, width: 170)
        view.addSubview(folderLabel)

        let folderButton = NSPopUpButton(frame: NSRect(x: 210, y: yPos - 2, width: 220, height: 26), pullsDown: false)
        folderButton.addItem(withTitle: NoteManager.shared.notesDirectory?.lastPathComponent ?? "Choose Folder...")
        folderButton.lastItem?.image = NSImage(named: NSImage.folderName)
        folderButton.addItem(withTitle: "Other...")
        folderButton.target = self
        folderButton.action = #selector(chooseNotesFolder(_:))
        view.addSubview(folderButton)

        yPos -= 60

        let storageBox = NSBox(frame: NSRect(x: 30, y: yPos - 120, width: 400, height: 140))
        storageBox.title = "Storage"
        storageBox.titlePosition = .atTop
        view.addSubview(storageBox)

        let storageContent = NSView(frame: NSRect(x: 10, y: 10, width: 380, height: 100))

        let storeLabel = createLabel("Store notes as:", at: NSPoint(x: 10, y: 70), alignment: .left, width: 120)
        storageContent.addSubview(storeLabel)

        let formatPopup = NSPopUpButton(frame: NSRect(x: 140, y: 68, width: 180, height: 26), pullsDown: false)
        formatPopup.addItems(withTitles: ["Rich Text (.rtf)", "Plain Text (.txt)"])
        formatPopup.selectItem(at: 0)
        storageContent.addSubview(formatPopup)

        let infoLabel = createLabel("Notes are stored as individual files in your selected\nfolder. You can access them with any text editor.", at: NSPoint(x: 10, y: 20), alignment: .left, width: 360)
        infoLabel.font = NSFont.systemFont(ofSize: 11)
        infoLabel.textColor = .secondaryLabelColor
        storageContent.addSubview(infoLabel)

        storageBox.contentView = storageContent

        yPos -= 180

        let watchBox = NSBox(frame: NSRect(x: 30, y: yPos - 80, width: 400, height: 100))
        watchBox.title = "File Watching"
        watchBox.titlePosition = .atTop
        view.addSubview(watchBox)

        let watchContent = NSView(frame: NSRect(x: 10, y: 10, width: 380, height: 60))

        let watchCheck = NSButton(checkboxWithTitle: "Watch for external changes", target: nil, action: nil)
        watchCheck.frame = NSRect(x: 10, y: 35, width: 250, height: 20)
        watchCheck.state = .on
        watchContent.addSubview(watchCheck)

        let watchNote = createLabel("Automatically reload notes when files are modified\nby other applications.", at: NSPoint(x: 10, y: 5), alignment: .left, width: 360)
        watchNote.font = NSFont.systemFont(ofSize: 11)
        watchNote.textColor = .secondaryLabelColor
        watchContent.addSubview(watchNote)

        watchBox.contentView = watchContent

        item.view = view
        return item
    }


    private func createEditingTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "editing")
        item.label = "Editing"
        item.image = NSImage(named: NSImage.advancedName)

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 440))

        var yPos: CGFloat = 395

        let styledLabel = createLabel("Styled Text:", at: NSPoint(x: 20, y: yPos), alignment: .right, width: 80)
        view.addSubview(styledLabel)

        let styledCheck = NSButton(checkboxWithTitle: "Copy basic styles from other apps", target: self, action: #selector(styledTextChanged(_:)))
        styledCheck.frame = NSRect(x: 110, y: yPos, width: 280, height: 20)
        styledCheck.state = Preferences.shared.copyBasicStylesFromOtherApps ? .on : .off
        view.addSubview(styledCheck)

        yPos -= 30

        let spellingLabel = createLabel("Spelling:", at: NSPoint(x: 20, y: yPos), alignment: .right, width: 80)
        view.addSubview(spellingLabel)

        let spellingCheck = NSButton(checkboxWithTitle: "Check as you type", target: self, action: #selector(spellingChanged(_:)))
        spellingCheck.frame = NSRect(x: 110, y: yPos, width: 200, height: 20)
        spellingCheck.state = Preferences.shared.checkSpellingAsYouType ? .on : .off
        view.addSubview(spellingCheck)

        yPos -= 30

        let tabLabel = createLabel("Tab Key:", at: NSPoint(x: 20, y: yPos), alignment: .right, width: 80)
        view.addSubview(tabLabel)

        let tabIndentRadio = NSButton(radioButtonWithTitle: "Indent lines", target: self, action: #selector(tabBehaviorChanged(_:)))
        tabIndentRadio.frame = NSRect(x: 110, y: yPos, width: 150, height: 20)
        tabIndentRadio.state = Preferences.shared.tabKeyIndentsLines ? .on : .off
        tabIndentRadio.tag = 1
        view.addSubview(tabIndentRadio)

        yPos -= 22
        let tabFocusRadio = NSButton(radioButtonWithTitle: "Move typing focus to next field", target: self, action: #selector(tabBehaviorChanged(_:)))
        tabFocusRadio.frame = NSRect(x: 110, y: yPos, width: 250, height: 20)
        tabFocusRadio.state = Preferences.shared.tabKeyIndentsLines ? .off : .on
        tabFocusRadio.tag = 2
        view.addSubview(tabFocusRadio)

        yPos -= 22
        let tabNote = createLabel("Option-Tab always indents and Shift-Tab\nalways moves the focus backward.", at: NSPoint(x: 110, y: yPos - 8), alignment: .left, width: 300)
        tabNote.font = NSFont.systemFont(ofSize: 11)
        tabNote.textColor = .secondaryLabelColor
        view.addSubview(tabNote)

        yPos -= 45

        let linksLabel = createLabel("Links:", at: NSPoint(x: 20, y: yPos), alignment: .right, width: 80)
        view.addSubview(linksLabel)

        let urlsClickableCheck = NSButton(checkboxWithTitle: "Make URLs clickable links", target: self, action: #selector(urlsClickableChanged(_:)))
        urlsClickableCheck.frame = NSRect(x: 110, y: yPos, width: 250, height: 20)
        urlsClickableCheck.state = Preferences.shared.makeURLsClickableLinks ? .on : .off
        view.addSubview(urlsClickableCheck)

        yPos -= 22
        let suggestTitlesCheck = NSButton(checkboxWithTitle: "Suggest titles for note-links", target: self, action: #selector(suggestTitlesChanged(_:)))
        suggestTitlesCheck.frame = NSRect(x: 110, y: yPos, width: 250, height: 20)
        suggestTitlesCheck.state = Preferences.shared.suggestTitlesForNoteLinks ? .on : .off
        view.addSubview(suggestTitlesCheck)

        yPos -= 35

        let directionLabel = createLabel("Direction:", at: NSPoint(x: 20, y: yPos), alignment: .right, width: 80)
        view.addSubview(directionLabel)

        let rtlCheck = NSButton(checkboxWithTitle: "Right-To-Left (RTL)", target: self, action: #selector(rtlChanged(_:)))
        rtlCheck.frame = NSRect(x: 110, y: yPos, width: 200, height: 20)
        rtlCheck.state = Preferences.shared.rightToLeftDirection ? .on : .off
        view.addSubview(rtlCheck)

        yPos -= 35

        let autoPairLabel = createLabel("Auto-pair:", at: NSPoint(x: 20, y: yPos), alignment: .right, width: 80)
        view.addSubview(autoPairLabel)

        let autoPairCheck = NSButton(checkboxWithTitle: "Match opening characters, like a left\nbracket, with closing characters.", target: self, action: #selector(autoPairChanged(_:)))
        autoPairCheck.frame = NSRect(x: 110, y: yPos - 10, width: 300, height: 35)
        autoPairCheck.state = Preferences.shared.autoPairCharacters ? .on : .off
        view.addSubview(autoPairCheck)

        yPos -= 50

        let editorLabel = createLabel("External Editor:", at: NSPoint(x: 20, y: yPos), alignment: .right, width: 100)
        view.addSubview(editorLabel)

        let editorIcon = NSImageView(frame: NSRect(x: 130, y: yPos - 2, width: 24, height: 24))
        editorIcon.image = NSImage(named: NSImage.advancedName)
        view.addSubview(editorIcon)

        let editorPopup = NSPopUpButton(frame: NSRect(x: 160, y: yPos - 2, width: 140, height: 26), pullsDown: false)
        editorPopup.addItems(withTitles: ["TextEdit", "BBEdit", "Sublime Text", "VS Code", "Other..."])
        editorPopup.selectItem(withTitle: "TextEdit")
        view.addSubview(editorPopup)

        item.view = view
        return item
    }

    // MARK: - Fonts & Colors Tab

    private func createFontsColorsTab() -> NSTabViewItem {
        let item = NSTabViewItem(identifier: "fontscolors")
        item.label = "Fonts & Colors"
        item.image = NSImage(named: NSImage.colorPanelName)

        let view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 440))

        var yPos: CGFloat = 390

        let fontLabel = createLabel("Body Font:", at: NSPoint(x: 50, y: yPos), alignment: .right, width: 100)
        view.addSubview(fontLabel)

        let font = Preferences.shared.bodyFont
        let fontDisplay = NSTextField(frame: NSRect(x: 160, y: yPos - 2, width: 200, height: 24))
        fontDisplay.stringValue = "\(font.fontName) \(Int(font.pointSize))"
        fontDisplay.isEditable = false
        fontDisplay.isBordered = true
        fontDisplay.backgroundColor = .textBackgroundColor
        view.addSubview(fontDisplay)

        let fontButton = NSButton(frame: NSRect(x: 370, y: yPos - 4, width: 50, height: 28))
        fontButton.title = "set"
        fontButton.bezelStyle = .rounded
        fontButton.target = self
        fontButton.action = #selector(chooseFont(_:))
        view.addSubview(fontButton)

        yPos -= 55

        let highlightCheck = NSButton(checkboxWithTitle: "Search Highlight:", target: self, action: #selector(searchHighlightChanged(_:)))
        highlightCheck.frame = NSRect(x: 160, y: yPos, width: 150, height: 20)
        highlightCheck.state = Preferences.shared.enableSearchHighlight ? .on : .off
        view.addSubview(highlightCheck)

        let highlightColorWell = NSColorWell(frame: NSRect(x: 320, y: yPos - 3, width: 60, height: 26))
        highlightColorWell.color = Preferences.shared.searchHighlightColor
        highlightColorWell.target = self
        highlightColorWell.action = #selector(searchHighlightColorChanged(_:))
        view.addSubview(highlightColorWell)

        yPos -= 45

        let foregroundLabel = createLabel("Foreground Text:", at: NSPoint(x: 100, y: yPos), alignment: .right, width: 150)
        view.addSubview(foregroundLabel)

        let foregroundColorWell = NSColorWell(frame: NSRect(x: 320, y: yPos - 3, width: 60, height: 26))
        foregroundColorWell.color = Preferences.shared.foregroundTextColor
        foregroundColorWell.target = self
        foregroundColorWell.action = #selector(foregroundColorChanged(_:))
        view.addSubview(foregroundColorWell)

        yPos -= 45

        let backgroundLabel = createLabel("Background:", at: NSPoint(x: 100, y: yPos), alignment: .right, width: 150)
        view.addSubview(backgroundLabel)

        let backgroundColorWell = NSColorWell(frame: NSRect(x: 320, y: yPos - 3, width: 60, height: 26))
        backgroundColorWell.color = Preferences.shared.backgroundColor
        backgroundColorWell.target = self
        backgroundColorWell.action = #selector(backgroundColorChanged(_:))
        view.addSubview(backgroundColorWell)

        yPos -= 30

        let colorNote = createLabel("Text and Background Colors affect User Color Scheme only.", at: NSPoint(x: 30, y: yPos), alignment: .left, width: 400)
        colorNote.font = NSFont.systemFont(ofSize: 11)
        colorNote.textColor = .secondaryLabelColor
        view.addSubview(colorNote)

        yPos -= 45

        let gridLabel = createLabel("Always Show Grid Lines in Notes List:", at: NSPoint(x: 30, y: yPos), alignment: .right, width: 280)
        view.addSubview(gridLabel)

        let gridCheck = NSButton(checkboxWithTitle: "", target: self, action: #selector(gridLinesChanged(_:)))
        gridCheck.frame = NSRect(x: 320, y: yPos, width: 20, height: 20)
        gridCheck.state = Preferences.shared.alwaysShowGridLines ? .on : .off
        view.addSubview(gridCheck)

        yPos -= 35

        // Alternating row colors
        let alternatingLabel = createLabel("Alternating Row Colors:", at: NSPoint(x: 30, y: yPos), alignment: .right, width: 280)
        view.addSubview(alternatingLabel)

        let alternatingCheck = NSButton(checkboxWithTitle: "", target: self, action: #selector(alternatingRowsChanged(_:)))
        alternatingCheck.frame = NSRect(x: 320, y: yPos, width: 20, height: 20)
        alternatingCheck.state = Preferences.shared.alternatingRowColors ? .on : .off
        view.addSubview(alternatingCheck)

        yPos -= 35

        // Keep note body width readable
        let readableLabel = createLabel("Keep Note Body Width Readable:", at: NSPoint(x: 30, y: yPos), alignment: .right, width: 280)
        view.addSubview(readableLabel)

        let readableCheck = NSButton(checkboxWithTitle: "", target: self, action: #selector(readableWidthChanged(_:)))
        readableCheck.frame = NSRect(x: 320, y: yPos, width: 20, height: 20)
        readableCheck.state = Preferences.shared.keepNoteBodyWidthReadable ? .on : .off
        view.addSubview(readableCheck)

        item.view = view
        return item
    }


    private func createLabel(_ text: String, at point: NSPoint, alignment: NSTextAlignment, width: CGFloat) -> NSTextField {
        let label = NSTextField(frame: NSRect(x: point.x, y: point.y, width: width, height: 40))
        label.stringValue = text
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.alignment = alignment
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 3
        label.sizeToFit()
        label.frame.origin = point
        label.frame.size.width = width
        return label
    }


    @objc private func listTextSizeChanged(_ sender: NSPopUpButton) {
        if let title = sender.titleOfSelectedItem,
           let size = Preferences.ListTextSize(rawValue: title) {
            Preferences.shared.listTextSize = size
        }
    }

    @objc private func autoSelectChanged(_ sender: NSButton) {
        Preferences.shared.autoSelectNotesByTitle = sender.state == .on
    }

    @objc private func noteLinkingChanged(_ sender: NSButton) {
        Preferences.shared.enableNoteLinking = sender.state == .on
    }

    @objc private func confirmDeleteChanged(_ sender: NSButton) {
        Preferences.shared.confirmNoteDeletion = sender.state == .on
    }

    @objc private func quitOnCloseChanged(_ sender: NSButton) {
        Preferences.shared.quitWhenClosingWindow = sender.state == .on
    }

    @objc private func menuBarIconChanged(_ sender: NSButton) {
        Preferences.shared.showMenuBarIcon = sender.state == .on
    }

    @objc private func hideDockIconClicked(_ sender: NSButton) {
        Preferences.shared.hideDockIcon = !Preferences.shared.hideDockIcon
        if Preferences.shared.hideDockIcon {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
    }


    @objc private func chooseNotesFolder(_ sender: NSPopUpButton) {
        if sender.indexOfSelectedItem == sender.numberOfItems - 1 {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.message = "Choose Notes Folder"

            if openPanel.runModal() == .OK, let url = openPanel.url {
                if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                    Preferences.shared.notesDirectoryBookmark = bookmark
                }
                try? NoteManager.shared.setNotesDirectory(url)
                sender.item(at: 0)?.title = url.lastPathComponent
                sender.selectItem(at: 0)
            } else {
                sender.selectItem(at: 0)
            }
        }
    }


    @objc private func styledTextChanged(_ sender: NSButton) {
        Preferences.shared.copyBasicStylesFromOtherApps = sender.state == .on
    }

    @objc private func spellingChanged(_ sender: NSButton) {
        Preferences.shared.checkSpellingAsYouType = sender.state == .on
    }

    @objc private func tabBehaviorChanged(_ sender: NSButton) {
        Preferences.shared.tabKeyIndentsLines = sender.tag == 1
    }

    @objc private func urlsClickableChanged(_ sender: NSButton) {
        Preferences.shared.makeURLsClickableLinks = sender.state == .on
    }

    @objc private func suggestTitlesChanged(_ sender: NSButton) {
        Preferences.shared.suggestTitlesForNoteLinks = sender.state == .on
    }

    @objc private func rtlChanged(_ sender: NSButton) {
        Preferences.shared.rightToLeftDirection = sender.state == .on
    }

    @objc private func autoPairChanged(_ sender: NSButton) {
        Preferences.shared.autoPairCharacters = sender.state == .on
    }


    @objc private func chooseFont(_ sender: NSButton) {
        let fontManager = NSFontManager.shared
        fontManager.target = self
        fontManager.action = #selector(fontChanged(_:))
        fontManager.setSelectedFont(Preferences.shared.bodyFont, isMultiple: false)
        fontManager.orderFrontFontPanel(self)
    }

    @objc private func fontChanged(_ sender: NSFontManager) {
        let newFont = sender.convert(Preferences.shared.bodyFont)
        Preferences.shared.bodyFont = newFont

        if let view = tabView.selectedTabViewItem?.view {
            for subview in view.subviews {
                if let textField = subview as? NSTextField,
                   textField.stringValue.contains(Preferences.shared.bodyFont.fontName) {
                    textField.stringValue = "\(newFont.fontName) \(Int(newFont.pointSize))"
                    break
                }
            }
        }
    }

    @objc private func searchHighlightChanged(_ sender: NSButton) {
        Preferences.shared.enableSearchHighlight = sender.state == .on
    }

    @objc private func searchHighlightColorChanged(_ sender: NSColorWell) {
        Preferences.shared.searchHighlightColor = sender.color
    }

    @objc private func foregroundColorChanged(_ sender: NSColorWell) {
        Preferences.shared.foregroundTextColor = sender.color
    }

    @objc private func backgroundColorChanged(_ sender: NSColorWell) {
        Preferences.shared.backgroundColor = sender.color
    }

    @objc private func gridLinesChanged(_ sender: NSButton) {
        Preferences.shared.alwaysShowGridLines = sender.state == .on
    }

    @objc private func alternatingRowsChanged(_ sender: NSButton) {
        Preferences.shared.alternatingRowColors = sender.state == .on
    }

    @objc private func readableWidthChanged(_ sender: NSButton) {
        Preferences.shared.keepNoteBodyWidthReadable = sender.state == .on
    }


    func showWindow() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}


extension PreferencesWindowController: NSTabViewDelegate {
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        window?.title = tabViewItem?.label ?? "Preferences"
    }
}

// MARK: - KeyRecorderView

class KeyRecorderView: NSView {
    private var displayField: NSTextField!
    private var setButton: NSButton!
    private var isRecording = false

    var keyCombo: String = "" {
        didSet {
            displayField.stringValue = keyCombo.isEmpty ? "None" : keyCombo
        }
    }

    var onKeyComboChanged: ((String) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        displayField = NSTextField(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
        displayField.stringValue = keyCombo.isEmpty ? "None" : keyCombo
        displayField.isEditable = false
        displayField.isBordered = true
        displayField.alignment = .center
        displayField.backgroundColor = .white
        addSubview(displayField)

        setButton = NSButton(frame: NSRect(x: 110, y: -2, width: 60, height: 28))
        setButton.title = "Set..."
        setButton.bezelStyle = .rounded
        setButton.target = self
        setButton.action = #selector(setButtonClicked)
        addSubview(setButton)
    }

    @objc private func setButtonClicked() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        displayField.stringValue = "Press keys..."
        displayField.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.1)
        setButton.title = "Cancel"
        window?.makeFirstResponder(self)
    }

    private func stopRecording() {
        isRecording = false
        displayField.stringValue = keyCombo.isEmpty ? "None" : keyCombo
        displayField.backgroundColor = .white
        setButton.title = "Set..."
    }

    override var acceptsFirstResponder: Bool {
        return isRecording
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        // Build key combo string
        var modifiers: [String] = []
        if event.modifierFlags.contains(.control) { modifiers.append("⌃") }
        if event.modifierFlags.contains(.option) { modifiers.append("⌥") }
        if event.modifierFlags.contains(.shift) { modifiers.append("⇧") }
        if event.modifierFlags.contains(.command) { modifiers.append("⌘") }

        let key = event.charactersIgnoringModifiers?.uppercased() ?? ""
        let combo = modifiers.joined() + key

        if !combo.isEmpty && combo != key { // Must have at least one modifier
            keyCombo = combo
            onKeyComboChanged?(combo)
            stopRecording()
        }
    }

    override func flagsChanged(with event: NSEvent) {
        // Show current modifiers while recording
        if isRecording {
            var modifiers: [String] = []
            if event.modifierFlags.contains(.control) { modifiers.append("⌃") }
            if event.modifierFlags.contains(.option) { modifiers.append("⌥") }
            if event.modifierFlags.contains(.shift) { modifiers.append("⇧") }
            if event.modifierFlags.contains(.command) { modifiers.append("⌘") }

            if !modifiers.isEmpty {
                displayField.stringValue = modifiers.joined() + "?"
            } else {
                displayField.stringValue = "Press keys..."
            }
        }
    }
}
