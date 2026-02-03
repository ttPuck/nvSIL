
import Cocoa

class EditorViewController: NSViewController {
    private var scrollView: NSScrollView!
    var textView: NSTextView!
    private var statusLabel: NSTextField!

    private var currentNote: Note?
    private var updateTimer: Timer?

    var onContentChanged: ((Note, String) -> Void)?
    var onWikiLinkClicked: ((String) -> Void)?

    private static let wikiLinkAttribute = NSAttributedString.Key("nvSIL.wikiLink")

    // Wiki link auto-suggest
    private var suggestionPopup: SuggestionPopupController?
    private var wikiLinkRange: NSRange?  // Range of the [[ pattern being typed

    override func loadView() {
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 550, height: 600))

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let contentSize = scrollView.contentSize
        textView = SimpleRichTextView(frame: NSRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height))
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        textView.textContainer?.containerSize = NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 5

        textView.wantsLayer = true
        textView.layerContentsRedrawPolicy = .onSetNeedsDisplay

        scrollView.documentView = textView

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 10)
        statusLabel.textColor = .tertiaryLabelColor
        statusLabel.alignment = .right

        containerView.addSubview(scrollView)
        containerView.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor),

            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            statusLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4),
            statusLabel.heightAnchor.constraint(equalToConstant: 20)
        ])

        self.view = containerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureTextView()
        applyPreferences()
        NotificationCenter.default.addObserver(self, selector: #selector(preferencesDidChange), name: .preferencesDidChange, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func preferencesDidChange(_ notification: Notification) {
        applyPreferences()
        if currentNote != nil { highlightWikiLinks() }
    }

    private func applyPreferences() {
        let prefs = Preferences.shared
        textView.isContinuousSpellCheckingEnabled = prefs.checkSpellingAsYouType
        textView.backgroundColor = prefs.backgroundColor
        textView.baseWritingDirection = prefs.rightToLeftDirection ? .rightToLeft : .leftToRight

        // Update font and color while preserving formatting (bold, italic, etc.)
        if let textStorage = textView.textStorage, textStorage.length > 0 {
            updateFontAndColorPreservingFormatting(textStorage: textStorage, baseFont: prefs.bodyFont, textColor: prefs.foregroundTextColor)
        }

        // Update typing attributes for new text
        textView.typingAttributes = [
            .font: prefs.bodyFont,
            .foregroundColor: prefs.foregroundTextColor
        ]
    }

    private func updateFontAndColorPreservingFormatting(textStorage: NSTextStorage, baseFont: NSFont, textColor: NSColor) {
        textStorage.beginEditing()
        textStorage.enumerateAttribute(.font, in: NSRange(location: 0, length: textStorage.length)) { value, range, _ in
            if let currentFont = value as? NSFont {
                // Preserve traits like bold, italic while changing to new font family
                let traits = NSFontManager.shared.traits(of: currentFont)
                let newFont: NSFont
                if traits.contains(.boldFontMask) && traits.contains(.italicFontMask) {
                    newFont = NSFontManager.shared.convert(baseFont, toHaveTrait: [.boldFontMask, .italicFontMask])
                } else if traits.contains(.boldFontMask) {
                    newFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .boldFontMask)
                } else if traits.contains(.italicFontMask) {
                    newFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                } else {
                    newFont = baseFont
                }
                textStorage.addAttribute(.font, value: newFont, range: range)
            } else {
                textStorage.addAttribute(.font, value: baseFont, range: range)
            }

            // Update text color to preference color unless it has special formatting
            if textStorage.attribute(.link, at: range.location, effectiveRange: nil) == nil {
                textStorage.addAttribute(.foregroundColor, value: textColor, range: range)
            }
        }
        textStorage.endEditing()
    }

    private func configureTextView() {
        textView.isRichText = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.delegate = self
        (textView as? SimpleRichTextView)?.editorController = self
        textView.isAutomaticLinkDetectionEnabled = false
        textView.linkTextAttributes = [
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .cursor: NSCursor.pointingHand
        ]
    }

    func displayNote(_ note: Note?) {
        updateTimer?.invalidate()

        // If switching to a different note, clear undo stack
        if currentNote?.id != note?.id {
            textView.undoManager?.removeAllActions()
        }

        currentNote = note
        // Tell NoteManager which note is being edited to prevent reload conflicts
        NoteManager.shared.setCurrentlyEditingNote(note)

        if let note = note {
            textView.textStorage?.beginEditing()

            if note.content.isEmpty {
                textView.string = ""
            } else if let attributedString = note.content.rtfAttributedString() {
                let normalized = normalizeFormatting(attributedString)
                textView.textStorage?.setAttributedString(normalized)
            } else {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: Preferences.shared.bodyFont,
                    .foregroundColor: Preferences.shared.foregroundTextColor
                ]
                let attributedString = NSAttributedString(string: note.content, attributes: attributes)
                textView.textStorage?.setAttributedString(attributedString)
            }

            textView.textStorage?.endEditing()
            textView.isEditable = true
            updateWordCount()
            textView.scrollToBeginningOfDocument(nil)

            DispatchQueue.main.async { [weak self] in
                self?.highlightWikiLinks()
            }
        } else {
            textView.string = ""
            textView.isEditable = false
            statusLabel.stringValue = ""
        }
    }

    private func highlightWikiLinks() {
        guard let textStorage = textView.textStorage, textStorage.length > 0 else { return }

        // Save both scroll position and selection BEFORE any changes
        let scrollPosition = scrollView.contentView.bounds.origin
        let savedSelection = textView.selectedRange()

        // Disable screen updates during attribute changes to prevent flicker
        textView.enclosingScrollView?.contentView.postsBoundsChangedNotifications = false

        textStorage.beginEditing()

        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(Self.wikiLinkAttribute, range: fullRange)
        textStorage.removeAttribute(.link, range: fullRange)
        textStorage.removeAttribute(.underlineStyle, range: fullRange)
        textStorage.addAttribute(.foregroundColor, value: Preferences.shared.foregroundTextColor, range: fullRange)

        if Preferences.shared.enableNoteLinking {
            let text = textStorage.string
            let pattern = "\\[\\[([^\\]]+)\\]\\]"

            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, options: [], range: range)

                for match in matches {
                    let matchRange = match.range
                    let linkTextRange = match.range(at: 1)

                    if let swiftRange = Range(linkTextRange, in: text) {
                        let linkText = String(text[swiftRange])
                        textStorage.addAttribute(Self.wikiLinkAttribute, value: linkText, range: matchRange)

                        if let encodedLinkText = linkText.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) {
                            let wikiURL = URL(string: "nvsil://wiki/\(encodedLinkText)")
                            textStorage.addAttribute(.link, value: wikiURL as Any, range: matchRange)
                        }

                        textStorage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: matchRange)
                        textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: matchRange)
                        textStorage.addAttribute(.cursor, value: NSCursor.pointingHand, range: matchRange)
                    }
                }
            }
        }

        // Detect and highlight URLs if preference is enabled
        if Preferences.shared.makeURLsClickableLinks {
            let text = textStorage.string
            if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
                let matches = detector.matches(in: text, options: [], range: fullRange)

                for match in matches {
                    if let url = match.url {
                        textStorage.addAttribute(.link, value: url, range: match.range)
                        textStorage.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: match.range)
                        textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
                        textStorage.addAttribute(.cursor, value: NSCursor.pointingHand, range: match.range)
                    }
                }
            }
        }

        textStorage.endEditing()

        // Restore scroll position and selection synchronously
        scrollView.contentView.scroll(to: scrollPosition)
        if savedSelection.location + savedSelection.length <= textStorage.length {
            textView.setSelectedRange(savedSelection)
        }

        // Re-enable bounds notifications
        textView.enclosingScrollView?.contentView.postsBoundsChangedNotifications = true
    }

    private func updateWordCount() {
        let text = textView.string
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        statusLabel.stringValue = "\(words) words, \(text.count) characters"
    }

    @objc func toggleBold(_ sender: Any?) {
        let selectedRange = textView.selectedRange()
        let fontManager = NSFontManager.shared

        if selectedRange.length > 0 {
            guard let textStorage = textView.textStorage else { return }
            let currentAttributes = textStorage.attributes(at: selectedRange.location, effectiveRange: nil)
            let currentFont = currentAttributes[.font] as? NSFont ?? Preferences.shared.bodyFont
            let newFont = currentFont.fontDescriptor.symbolicTraits.contains(.bold)
                ? fontManager.convert(currentFont, toNotHaveTrait: .boldFontMask)
                : fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
            textStorage.addAttribute(.font, value: newFont, range: selectedRange)
            scheduleFormattingSave()
        } else {
            var typingAttrs = textView.typingAttributes
            let currentFont = typingAttrs[.font] as? NSFont ?? Preferences.shared.bodyFont
            let newFont = currentFont.fontDescriptor.symbolicTraits.contains(.bold)
                ? fontManager.convert(currentFont, toNotHaveTrait: .boldFontMask)
                : fontManager.convert(currentFont, toHaveTrait: .boldFontMask)
            typingAttrs[.font] = newFont
            textView.typingAttributes = typingAttrs
        }
    }

    @objc func toggleItalic(_ sender: Any?) {
        let selectedRange = textView.selectedRange()
        let fontManager = NSFontManager.shared

        if selectedRange.length > 0 {
            guard let textStorage = textView.textStorage else { return }
            let currentAttributes = textStorage.attributes(at: selectedRange.location, effectiveRange: nil)
            let currentFont = currentAttributes[.font] as? NSFont ?? Preferences.shared.bodyFont
            let newFont = currentFont.fontDescriptor.symbolicTraits.contains(.italic)
                ? fontManager.convert(currentFont, toNotHaveTrait: .italicFontMask)
                : fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
            textStorage.addAttribute(.font, value: newFont, range: selectedRange)
            scheduleFormattingSave()
        } else {
            var typingAttrs = textView.typingAttributes
            let currentFont = typingAttrs[.font] as? NSFont ?? Preferences.shared.bodyFont
            let newFont = currentFont.fontDescriptor.symbolicTraits.contains(.italic)
                ? fontManager.convert(currentFont, toNotHaveTrait: .italicFontMask)
                : fontManager.convert(currentFont, toHaveTrait: .italicFontMask)
            typingAttrs[.font] = newFont
            textView.typingAttributes = typingAttrs
        }
    }

    @objc func toggleStrikethrough(_ sender: Any?) {
        let selectedRange = textView.selectedRange()

        if selectedRange.length > 0 {
            guard let textStorage = textView.textStorage else { return }
            let currentAttributes = textStorage.attributes(at: selectedRange.location, effectiveRange: nil)
            let hasStrikethrough = (currentAttributes[.strikethroughStyle] as? Int ?? 0) > 0
            if hasStrikethrough {
                textStorage.removeAttribute(.strikethroughStyle, range: selectedRange)
            } else {
                textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: selectedRange)
            }
            scheduleFormattingSave()
        } else {
            var typingAttrs = textView.typingAttributes
            let hasStrikethrough = (typingAttrs[.strikethroughStyle] as? Int ?? 0) > 0
            if hasStrikethrough {
                typingAttrs.removeValue(forKey: .strikethroughStyle)
            } else {
                typingAttrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            }
            textView.typingAttributes = typingAttrs
        }
    }

    @objc func removeFormatting(_ sender: Any?) {
        guard let textStorage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()

        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: Preferences.shared.bodyFont,
            .foregroundColor: Preferences.shared.foregroundTextColor
        ]

        if selectedRange.length > 0 {
            // Remove formatting from selected text
            let plainText = textStorage.attributedSubstring(from: selectedRange).string
            let newAttributedString = NSAttributedString(string: plainText, attributes: defaultAttributes)
            textStorage.replaceCharacters(in: selectedRange, with: newAttributedString)
            scheduleFormattingSave()
        } else {
            // No selection - reset typing attributes for future typing
            textView.typingAttributes = defaultAttributes
        }
    }

    @objc func indentText(_ sender: Any?) {
        guard let textStorage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()
        let string = textStorage.string as NSString

        // Find line range for selection
        let lineRange = string.lineRange(for: selectedRange)
        let lines = string.substring(with: lineRange)

        // Add tab to beginning of each line
        let indentedLines = lines.components(separatedBy: "\n").map { line in
            line.isEmpty ? line : "\t" + line
        }.joined(separator: "\n")

        textStorage.replaceCharacters(in: lineRange, with: indentedLines)
        scheduleFormattingSave()
    }

    @objc func outdentText(_ sender: Any?) {
        guard let textStorage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()
        let string = textStorage.string as NSString

        // Find line range for selection
        let lineRange = string.lineRange(for: selectedRange)
        let lines = string.substring(with: lineRange)

        // Remove tab or up to 4 spaces from beginning of each line
        let outdentedLines = lines.components(separatedBy: "\n").map { line -> String in
            if line.hasPrefix("\t") {
                return String(line.dropFirst())
            } else if line.hasPrefix("    ") {
                return String(line.dropFirst(4))
            } else {
                // Remove leading spaces up to 4
                var result = line
                var spacesRemoved = 0
                while result.hasPrefix(" ") && spacesRemoved < 4 {
                    result = String(result.dropFirst())
                    spacesRemoved += 1
                }
                return result
            }
        }.joined(separator: "\n")

        textStorage.replaceCharacters(in: lineRange, with: outdentedLines)
        scheduleFormattingSave()
    }

    private func scheduleFormattingSave() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.saveCurrentContent()
        }
    }

    private func saveCurrentContent() {
        guard let note = currentNote else { return }
        let editorContent = textView.textStorage ?? NSAttributedString(string: textView.string)
        let fileExtension = note.fileURL.pathExtension.lowercased()

        if fileExtension == "rtf" {
            if let rtfData = try? editorContent.data(
                from: NSRange(location: 0, length: editorContent.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            ), let rtfString = String(data: rtfData, encoding: .utf8) {
                onContentChanged?(note, rtfString)
            } else {
                onContentChanged?(note, textView.string)
            }
        } else {
            onContentChanged?(note, textView.string)
        }
        // Don't call setSelectedRange here - it causes scroll jumpiness
        // The selection is already maintained by the text view
    }

    func clearEditor() {
        currentNote = nil
        NoteManager.shared.setCurrentlyEditingNote(nil)
        textView.string = ""
        textView.isEditable = false
        statusLabel.stringValue = ""
    }
}

// MARK: - NSTextViewDelegate

extension EditorViewController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        updateWordCount()

        // Check for wiki link auto-suggest
        if Preferences.shared.suggestTitlesForNoteLinks {
            checkForWikiLinkPattern()
        }

        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.saveCurrentContent()
            // Highlight wiki links or URLs if enabled
            if self?.textView.string.contains("[[") == true || Preferences.shared.makeURLsClickableLinks {
                self?.highlightWikiLinks()
            }
        }
    }

    private func checkForWikiLinkPattern() {
        let text = textView.string
        let cursorLocation = textView.selectedRange().location

        guard cursorLocation > 0, cursorLocation <= text.count else {
            hideSuggestionPopup()
            return
        }

        // Find the start of the wiki link pattern before cursor
        let textBeforeCursor = String(text.prefix(cursorLocation))

        // Look for [[ that doesn't have a closing ]]
        if let openBracketRange = textBeforeCursor.range(of: "[[", options: .backwards) {
            let afterOpenBracket = textBeforeCursor[openBracketRange.upperBound...]

            // Check if there's already a closing ]] between [[ and cursor
            if afterOpenBracket.contains("]]") {
                hideSuggestionPopup()
                return
            }

            // Get the partial text after [[
            let partialTitle = String(afterOpenBracket)

            // Get suggestions - prefer prefix matches, then contains matches
            var suggestions: [String]
            if partialTitle.isEmpty {
                // Show all note titles when just [[ is typed
                suggestions = NoteManager.shared.allNoteTitles
            } else {
                // First get prefix matches, then contains matches
                let prefixMatches = NoteManager.shared.notesMatchingTitlePrefix(partialTitle).map { $0.title }
                let containsMatches = NoteManager.shared.notesContainingTitle(partialTitle)
                    .map { $0.title }
                    .filter { !prefixMatches.contains($0) }
                suggestions = prefixMatches + containsMatches
            }

            // Limit suggestions
            suggestions = Array(suggestions.prefix(15))

            if !suggestions.isEmpty {
                // Calculate the NSRange for the [[ pattern
                let startIndex = textBeforeCursor.distance(from: textBeforeCursor.startIndex, to: openBracketRange.lowerBound)
                wikiLinkRange = NSRange(location: startIndex, length: cursorLocation - startIndex)
                showSuggestionPopup(suggestions: suggestions)
            } else {
                hideSuggestionPopup()
            }
        } else {
            hideSuggestionPopup()
        }
    }

    private func showSuggestionPopup(suggestions: [String]) {
        guard let window = view.window else { return }

        if suggestionPopup == nil {
            suggestionPopup = SuggestionPopupController()
            suggestionPopup?.delegate = self
        }

        // Get cursor position - firstRect returns screen coordinates
        let cursorRect = textView.firstRect(forCharacterRange: textView.selectedRange(), actualRange: nil)

        // Use screen coordinates directly since SuggestionPopupController expects them
        var screenPoint: NSPoint

        if cursorRect.origin.x != 0 || cursorRect.origin.y != 0 {
            // firstRect returned valid screen coordinates
            screenPoint = cursorRect.origin
        } else {
            // Fallback: calculate position from layout manager
            let layoutManager = textView.layoutManager!
            let cursorLocation = max(0, textView.selectedRange().location)
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: cursorLocation)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)

            // Convert to window coordinates, then to screen
            let textViewRect = textView.convert(lineRect, to: nil)
            let windowRect = window.convertToScreen(textViewRect)
            screenPoint = NSPoint(x: windowRect.origin.x + 20, y: windowRect.origin.y)
        }

        suggestionPopup?.show(at: screenPoint, in: window, suggestions: suggestions)
    }

    private func hideSuggestionPopup() {
        suggestionPopup?.hide()
        wikiLinkRange = nil
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard suggestionPopup?.isVisible == true else { return false }

        switch event.keyCode {
        case 125: // Down arrow
            suggestionPopup?.moveSelectionDown()
            return true
        case 126: // Up arrow
            suggestionPopup?.moveSelectionUp()
            return true
        case 36: // Return
            suggestionPopup?.confirmSelection()
            return true
        case 53: // Escape
            suggestionPopup?.cancel()
            return true
        case 48: // Tab
            suggestionPopup?.confirmSelection()
            return true
        default:
            return false
        }
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        if let replacement = replacementString,
           replacement == " " || replacement == "\n" || replacement == "\t" {
            DispatchQueue.main.async { [weak self] in
                self?.resetTypingAttributesToDefault()
            }
        }

        // Auto-pair brackets and quotes
        if Preferences.shared.autoPairCharacters,
           let replacement = replacementString,
           replacement.count == 1,
           affectedCharRange.length == 0 { // Only when inserting (not replacing)
            let pairMap: [String: String] = [
                "(": ")",
                "[": "]",
                "{": "}",
                "\"": "\"",
                "'": "'"
            ]

            if let closingChar = pairMap[replacement] {
                // Insert the pair and position cursor in between
                let paired = replacement + closingChar
                let attributes = textView.typingAttributes
                let attributedString = NSAttributedString(string: paired, attributes: attributes)

                if textView.shouldChangeText(in: affectedCharRange, replacementString: paired) {
                    textView.textStorage?.replaceCharacters(in: affectedCharRange, with: attributedString)
                    textView.didChangeText()
                    // Position cursor after the opening character
                    textView.setSelectedRange(NSRange(location: affectedCharRange.location + 1, length: 0))
                }
                return false // We handled the insertion ourselves
            }
        }

        return true
    }

    private func resetTypingAttributesToDefault() {
        var defaultAttrs: [NSAttributedString.Key: Any] = [
            .font: Preferences.shared.bodyFont,
            .foregroundColor: Preferences.shared.foregroundTextColor
        ]
        if let paragraphStyle = textView.typingAttributes[.paragraphStyle] {
            defaultAttrs[.paragraphStyle] = paragraphStyle
        }
        textView.typingAttributes = defaultAttrs
    }

    func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
        if let url = link as? URL, url.scheme == "nvsil", url.host == "wiki" {
            let encodedTitle = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if let title = encodedTitle.removingPercentEncoding {
                onWikiLinkClicked?(title)
                return true
            }
        }
        return false
    }

    func normalizeFormatting(_ attributedString: NSAttributedString) -> NSAttributedString {
        let baseFont = Preferences.shared.bodyFont
        let result = NSMutableAttributedString(string: attributedString.string)
        let fullRange = NSRange(location: 0, length: result.length)

        result.addAttribute(.font, value: baseFont, range: fullRange)
        result.addAttribute(.foregroundColor, value: Preferences.shared.foregroundTextColor, range: fullRange)

        attributedString.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let originalFont = value as? NSFont else { return }
            let traits = originalFont.fontDescriptor.symbolicTraits
            var newFont = baseFont
            let fontManager = NSFontManager.shared
            if traits.contains(.bold) { newFont = fontManager.convert(newFont, toHaveTrait: .boldFontMask) }
            if traits.contains(.italic) { newFont = fontManager.convert(newFont, toHaveTrait: .italicFontMask) }
            result.addAttribute(.font, value: newFont, range: range)
        }

        attributedString.enumerateAttribute(.strikethroughStyle, in: fullRange, options: []) { value, range, _ in
            if let strikeValue = value as? Int, strikeValue > 0 {
                result.addAttribute(.strikethroughStyle, value: strikeValue, range: range)
            }
        }

        return result
    }
}

// MARK: - SimpleRichTextView

class SimpleRichTextView: NSTextView {
    weak var editorController: EditorViewController?

    override func keyDown(with event: NSEvent) {
        // Forward key events to editor controller for suggestion popup handling
        if let editor = editorController, editor.handleKeyDown(event) {
            return
        }

        // Handle Tab key based on preference
        if event.keyCode == 48 { // Tab
            if event.modifierFlags.contains(.shift) {
                // Shift+Tab always outdents
                editorController?.outdentText(nil)
                return
            } else if Preferences.shared.tabKeyIndentsLines {
                // Tab indents lines when preference is enabled
                editorController?.indentText(nil)
                return
            }
            // Otherwise, let Tab insert a tab character normally
        }

        super.keyDown(with: event)
    }

    override func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general

        if let rtfData = pasteboard.data(forType: .rtf),
           let attributedString = try? NSAttributedString(
            data: rtfData,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
           ) {
            insertNormalizedText(normalizeFormattingForPaste(attributedString))
            return
        }

        if let string = pasteboard.string(forType: .string) {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: Preferences.shared.bodyFont,
                .foregroundColor: Preferences.shared.foregroundTextColor
            ]
            insertNormalizedText(NSAttributedString(string: string, attributes: attributes))
            return
        }

        super.paste(sender)
    }

    private func normalizeFormattingForPaste(_ attributedString: NSAttributedString) -> NSAttributedString {
        let baseFont = Preferences.shared.bodyFont
        let result = NSMutableAttributedString(string: attributedString.string)
        let fullRange = NSRange(location: 0, length: result.length)

        result.addAttribute(.font, value: baseFont, range: fullRange)
        result.addAttribute(.foregroundColor, value: Preferences.shared.foregroundTextColor, range: fullRange)

        attributedString.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let originalFont = value as? NSFont else { return }
            let traits = originalFont.fontDescriptor.symbolicTraits
            var newFont = baseFont
            let fontManager = NSFontManager.shared
            if traits.contains(.bold) { newFont = fontManager.convert(newFont, toHaveTrait: .boldFontMask) }
            if traits.contains(.italic) { newFont = fontManager.convert(newFont, toHaveTrait: .italicFontMask) }
            result.addAttribute(.font, value: newFont, range: range)
        }

        attributedString.enumerateAttribute(.strikethroughStyle, in: fullRange, options: []) { value, range, _ in
            if let strikeValue = value as? Int, strikeValue > 0 {
                result.addAttribute(.strikethroughStyle, value: strikeValue, range: range)
            }
        }

        return result
    }

    private func insertNormalizedText(_ attributedString: NSAttributedString) {
        guard let textStorage = self.textStorage else { return }
        let selectedRange = self.selectedRange()

        if self.shouldChangeText(in: selectedRange, replacementString: attributedString.string) {
            textStorage.replaceCharacters(in: selectedRange, with: attributedString)
            self.didChangeText()
            self.setSelectedRange(NSRange(location: selectedRange.location + attributedString.length, length: 0))
        }
    }
}

// MARK: - SuggestionPopupDelegate

extension EditorViewController: SuggestionPopupDelegate {
    func suggestionPopup(_ popup: SuggestionPopupController, didSelectSuggestion suggestion: String) {
        guard let range = wikiLinkRange,
              let textStorage = textView.textStorage else {
            return
        }

        // Replace [[ + partial text with [[suggestion]]
        let replacement = "[[\(suggestion)]]"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: Preferences.shared.bodyFont,
            .foregroundColor: Preferences.shared.foregroundTextColor
        ]
        let attributedReplacement = NSAttributedString(string: replacement, attributes: attributes)

        if textView.shouldChangeText(in: range, replacementString: replacement) {
            textStorage.replaceCharacters(in: range, with: attributedReplacement)
            textView.didChangeText()

            // Position cursor after the ]]
            let newCursorPosition = range.location + replacement.count
            textView.setSelectedRange(NSRange(location: newCursorPosition, length: 0))

            // Trigger wiki link highlighting
            highlightWikiLinks()
        }

        wikiLinkRange = nil
    }

    func suggestionPopupDidCancel(_ popup: SuggestionPopupController) {
        wikiLinkRange = nil
    }
}
