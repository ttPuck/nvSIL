import Cocoa
import UniformTypeIdentifiers

class TagPillButton: NSButton {
    let tagName: String

    init(tag: String) {
        self.tagName = tag
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class TagContainerView: NSView, NSTextFieldDelegate, SuggestionPopupDelegate {
    private var stackView: NSStackView!
    private var editField: NSTextField!
    private var isEditing = false
    private var currentRow: Int = 0
    private var currentTags: [String] = []
    private var isRowSelected: Bool = false
    private weak var externalDelegate: NSTextFieldDelegate?

    var onTagClicked: ((String) -> Void)?
    private var suggestionPopup: SuggestionPopupController?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        stackView = NSStackView()
        stackView.orientation = .horizontal
        stackView.spacing = 4
        stackView.alignment = .centerY
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        editField = NSTextField()
        editField.isBordered = false
        editField.font = NSFont.systemFont(ofSize: 10)
        editField.focusRingType = .none
        editField.isHidden = true
        editField.translatesAutoresizingMaskIntoConstraints = false
        editField.delegate = self
        addSubview(editField)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),

            editField.leadingAnchor.constraint(equalTo: leadingAnchor),
            editField.trailingAnchor.constraint(equalTo: trailingAnchor),
            editField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(tags: [String], row: Int, isSelected: Bool, delegate: NSTextFieldDelegate?) {
        currentTags = tags
        currentRow = row
        isRowSelected = isSelected
        externalDelegate = delegate
        editField.tag = row

        updateTagPills()
    }
    
    private func updateTagPills() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        for tag in currentTags {
            let pillView = createPillLabel(for: tag)
            stackView.addArrangedSubview(pillView)
        }
        editField.stringValue = currentTags.joined(separator: ", ")
    }
    
    private func createPillLabel(for tag: String) -> NSView {
        let button = TagPillButton(tag: tag)
        button.wantsLayer = true
        button.isBordered = false
        button.bezelStyle = .inline

        let layer = button.layer ?? CALayer()
        button.layer = layer
        layer.cornerRadius = 3
        layer.backgroundColor = (isRowSelected ? NSColor(calibratedWhite: 0.45, alpha: 1.0) : NSColor(calibratedWhite: 0.78, alpha: 1.0)).cgColor

        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: isRowSelected ? NSColor.white : NSColor(calibratedWhite: 0.3, alpha: 1.0),
            .paragraphStyle: style
        ]
        button.attributedTitle = NSAttributedString(string: tag, attributes: attrs)

        button.target = self
        button.action = #selector(tagPillClicked(_:))

        return button
    }

    @objc private func tagPillClicked(_ sender: TagPillButton) {
        onTagClicked?(sender.tagName)
    }
    
    func startEditing() {
        isEditing = true
        stackView.isHidden = true
        editField.isHidden = false
        editField.stringValue = currentTags.joined(separator: ", ")
        editField.drawsBackground = true
        editField.backgroundColor = .white
        editField.textColor = .black
        editField.isBordered = true
        window?.makeFirstResponder(editField)
    }

    func endEditing() {
        isEditing = false
        stackView.isHidden = false
        editField.isHidden = true
        editField.drawsBackground = false
        editField.isBordered = false
        hideSuggestionPopup()

        let newTags = editField.stringValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        currentTags = newTags

        updateTagPills()
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            startEditing()
        } else {
            super.mouseDown(with: event)
        }
    }

    

    func controlTextDidChange(_ obj: Notification) {
        checkForTagSuggestions()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        hideSuggestionPopup()
        
        externalDelegate?.controlTextDidEndEditing?(obj)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if suggestionPopup?.isVisible == true {
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                suggestionPopup?.moveSelectionDown()
                return true
            } else if commandSelector == #selector(NSResponder.moveUp(_:)) {
                suggestionPopup?.moveSelectionUp()
                return true
            } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                suggestionPopup?.confirmSelection()
                return true
            } else if commandSelector == #selector(NSResponder.insertTab(_:)) {
                suggestionPopup?.confirmSelection()
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                suggestionPopup?.cancel()
                return true
            }
        }
        return false
    }

    

    private func checkForTagSuggestions() {
        let text = editField.stringValue

        
        let components = text.split(separator: ",", omittingEmptySubsequences: false)
        guard let lastComponent = components.last else {
            hideSuggestionPopup()
            return
        }

        let partialTag = lastComponent.trimmingCharacters(in: .whitespaces).lowercased()

        if partialTag.isEmpty {
            hideSuggestionPopup()
            return
        }

        
        let allTags = NoteManager.shared.allUniqueTags

        
        let enteredTags = Set(text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty })

        
        var suggestions = allTags
            .filter { $0.hasPrefix(partialTag) && !enteredTags.contains($0) }
            .sorted()

        let containsMatches = allTags
            .filter { $0.contains(partialTag) && !$0.hasPrefix(partialTag) && !enteredTags.contains($0) }
            .sorted()

        suggestions.append(contentsOf: containsMatches)
        suggestions = Array(suggestions.prefix(10))

        if suggestions.isEmpty {
            hideSuggestionPopup()
            return
        }

        showSuggestionPopup(suggestions: suggestions)
    }

    private func showSuggestionPopup(suggestions: [String]) {
        guard let window = window else { return }

        if suggestionPopup == nil {
            suggestionPopup = SuggestionPopupController()
            suggestionPopup?.delegate = self
        }

        
        let fieldRect = editField.convert(editField.bounds, to: nil)
        let windowRect = window.convertToScreen(fieldRect)
        let point = NSPoint(x: windowRect.origin.x, y: windowRect.origin.y)

        suggestionPopup?.show(at: point, in: window, suggestions: suggestions)
    }

    private func hideSuggestionPopup() {
        suggestionPopup?.hide()
    }

    

    func suggestionPopup(_ popup: SuggestionPopupController, didSelectSuggestion suggestion: String) {
        let text = editField.stringValue

        
        var components = text.split(separator: ",", omittingEmptySubsequences: false)
            .map { String($0) }

        if !components.isEmpty {
            
            components.removeLast()
            if components.isEmpty {
                editField.stringValue = suggestion + ", "
            } else {
                let prefix = components.joined(separator: ",")
                editField.stringValue = prefix + ", " + suggestion + ", "
            }
        } else {
            editField.stringValue = suggestion + ", "
        }

        
        if let fieldEditor = window?.fieldEditor(false, for: editField) as? NSTextView {
            fieldEditor.setSelectedRange(NSRange(location: editField.stringValue.count, length: 0))
        }
    }

    func suggestionPopupDidCancel(_ popup: SuggestionPopupController) {
        
    }
}

class ConstrainedTableHeaderView: NSTableHeaderView {
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        constrainColumnWidthsDuringDrag()
    }
    private func constrainColumnWidthsDuringDrag() {
        guard let tableView = self.tableView,
              let scrollView = tableView.enclosingScrollView else { return }
        
        let availableWidth = scrollView.contentView.bounds.width
        guard tableView.tableColumns.count == 3 else { return }
        
        let titleColumn = tableView.tableColumns[0]
        let tagsColumn = tableView.tableColumns[1]
        let dateColumn = tableView.tableColumns[2]
        
        
        let totalWidth = titleColumn.width + tagsColumn.width + dateColumn.width
        
        
        if totalWidth > availableWidth {
            let excess = totalWidth - availableWidth
            
            var remaining = excess
            
            let dateShrink = min(remaining, dateColumn.width - dateColumn.minWidth)
            if dateShrink > 0 {
                dateColumn.width -= dateShrink
                remaining -= dateShrink
            }
            
            if remaining > 0 {
                let tagsShrink = min(remaining, tagsColumn.width - tagsColumn.minWidth)
                if tagsShrink > 0 {
                    tagsColumn.width -= tagsShrink
                    remaining -= tagsShrink
                }
            }
            
            if remaining > 0 {
                let titleShrink = min(remaining, titleColumn.width - titleColumn.minWidth)
                if titleShrink > 0 {
                    titleColumn.width -= titleShrink
                }
            }
        }
    }
}

class ColoredHeaderCell: NSTableHeaderCell {
    var customTextColor: NSColor = .black
    var gradientStartColor: NSColor = NSColor(calibratedWhite: 0.95, alpha: 1.0)
    var gradientEndColor: NSColor = NSColor(calibratedWhite: 0.82, alpha: 1.0)
    var columnIdentifier: String = ""  

    enum SortIndicator {
        case none
        case ascending
        case descending
    }

    
    override func copy(with zone: NSZone? = nil) -> Any {
        let copy = super.copy(with: zone) as! ColoredHeaderCell
        copy.customTextColor = customTextColor
        copy.gradientStartColor = gradientStartColor
        copy.gradientEndColor = gradientEndColor
        copy.columnIdentifier = columnIdentifier
        return copy
    }

    
    private func currentSortIndicator(in controlView: NSView) -> SortIndicator {
        guard let headerView = controlView as? NSTableHeaderView,
              let tableView = headerView.tableView else {
            return .none
        }

        guard let sortDescriptor = tableView.sortDescriptors.first,
              let sortKey = sortDescriptor.key else {
            return .none
        }

        
        let expectedKey: String?
        let cellTitle = stringValue.lowercased()
        if cellTitle.contains("title") {
            expectedKey = "title"
        } else if cellTitle.contains("tag") {
            expectedKey = "tags"
        } else if cellTitle.contains("date") {
            expectedKey = "dateModified"
        } else {
            expectedKey = nil
        }

        if expectedKey == sortKey {
            return sortDescriptor.ascending ? .ascending : .descending
        }
        return .none
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        let gradient = NSGradient(starting: gradientStartColor, ending: gradientEndColor)
        gradient?.draw(in: cellFrame, angle: 90)

        NSColor(calibratedWhite: 0.6, alpha: 1.0).setStroke()
        let borderPath = NSBezierPath()
        borderPath.move(to: NSPoint(x: cellFrame.minX, y: cellFrame.minY))
        borderPath.line(to: NSPoint(x: cellFrame.maxX, y: cellFrame.minY))
        borderPath.lineWidth = 1.0
        borderPath.stroke()

        borderPath.removeAllPoints()
        borderPath.move(to: NSPoint(x: cellFrame.maxX - 0.5, y: cellFrame.minY))
        borderPath.line(to: NSPoint(x: cellFrame.maxX - 0.5, y: cellFrame.maxY))
        borderPath.stroke()

        
        let sortIndicator = currentSortIndicator(in: controlView)

        let indicatorWidth: CGFloat = sortIndicator != .none ? 16 : 0
        var titleRect = cellFrame.insetBy(dx: 5, dy: 2)
        titleRect.size.width -= indicatorWidth

        let attrs: [NSAttributedString.Key: Any] = [
            .font: self.font ?? NSFont.systemFont(ofSize: 11),
            .foregroundColor: customTextColor
        ]
        self.stringValue.draw(in: titleRect, withAttributes: attrs)

        if sortIndicator != .none {
            let indicatorString = sortIndicator == .ascending ? "▲" : "▼"
            let indicatorAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8),
                .foregroundColor: NSColor(calibratedWhite: 0.4, alpha: 1.0)
            ]
            let indicatorSize = indicatorString.size(withAttributes: indicatorAttrs)

            let indicatorX = cellFrame.maxX - indicatorSize.width - 6
            let indicatorY = cellFrame.midY - indicatorSize.height / 2
            indicatorString.draw(at: NSPoint(x: indicatorX, y: indicatorY), withAttributes: indicatorAttrs)
        }
    }
}


class NoteTableView: NSTableView {
    var onDeleteKeyPressed: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        
        if event.modifierFlags.contains(.command) && event.keyCode == 51 {
            onDeleteKeyPressed?()
            return
        }
        super.keyDown(with: event)
    }
}

class NoteListViewController: NSViewController, NSWindowDelegate {
    private var tableView: NoteTableView!
    private var scrollView: NSScrollView!
    private var statusLabel: NSTextField!
    private var containerView: NSView!
    private var scrollViewBottomConstraint: NSLayoutConstraint?
    private var statusBarVisible = true

    private var notes: [Note] = []
    var filteredNotes: [Note] = []
    var currentSearchQuery: String = ""

    private var titleColumnProportion: CGFloat = 0.52
    private var tagsColumnProportion: CGFloat = 0.21
    private var dateColumnProportion: CGFloat = 0.27
    private var isUserResizing = false
    private var lastKnownWidth: CGFloat = 0
    private var hasLoadedSavedProportions = false
    
    var selectedNote: Note? {
        guard tableView.selectedRow >= 0 && tableView.selectedRow < filteredNotes.count else {
            return nil
        }
        return filteredNotes[tableView.selectedRow]
    }
    
    var onNoteSelected: ((Note?) -> Void)?
    var onTagClicked: ((String) -> Void)?

    override func loadView() {
        
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 300))

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.borderType = .bezelBorder
        scrollView.backgroundColor = .white
        scrollView.verticalScroller?.knobStyle = .dark
        
        
        tableView = NoteTableView()
        tableView.onDeleteKeyPressed = { [weak self] in
            self?.deleteSelectedNote()
        }
        tableView.rowHeight = 17
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.gridStyleMask = [.solidHorizontalGridLineMask]
        tableView.backgroundColor = .white
        tableView.intercellSpacing = NSSize(width: 3, height: 2)
        tableView.columnAutoresizingStyle = .noColumnAutoresizing
        
        
        let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TitleColumn"))
        titleColumn.title = "Title"
        titleColumn.width = 300
        titleColumn.minWidth = 100
        titleColumn.resizingMask = .userResizingMask
        titleColumn.sortDescriptorPrototype = NSSortDescriptor(key: "title", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        let titleHeaderCell = ColoredHeaderCell()
        titleHeaderCell.stringValue = "Title"
        titleHeaderCell.font = NSFont.boldSystemFont(ofSize: 11)
        titleHeaderCell.customTextColor = NSColor(calibratedWhite: 0.0, alpha: 1.0)
        titleHeaderCell.gradientStartColor = NSColor(calibratedWhite: 0.85, alpha: 1.0)
        titleHeaderCell.gradientEndColor = NSColor(calibratedWhite: 0.70, alpha: 1.0)
        titleHeaderCell.columnIdentifier = "TitleColumn"
        titleColumn.headerCell = titleHeaderCell
        tableView.addTableColumn(titleColumn)
        
        let tagsColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TagsColumn"))
        tagsColumn.title = "Tags"
        tagsColumn.width = 120
        tagsColumn.minWidth = 50
        tagsColumn.resizingMask = .userResizingMask
        tagsColumn.sortDescriptorPrototype = NSSortDescriptor(key: "tags", ascending: true)
        let tagsHeaderCell = ColoredHeaderCell()
        tagsHeaderCell.stringValue = "Tags"
        tagsHeaderCell.font = NSFont.systemFont(ofSize: 11)
        tagsHeaderCell.customTextColor = NSColor(calibratedWhite: 0.4, alpha: 1.0)
        tagsHeaderCell.gradientStartColor = NSColor(calibratedWhite: 0.95, alpha: 1.0)
        tagsHeaderCell.gradientEndColor = NSColor(calibratedWhite: 0.88, alpha: 1.0)
        tagsHeaderCell.columnIdentifier = "TagsColumn"
        tagsColumn.headerCell = tagsHeaderCell
        tableView.addTableColumn(tagsColumn)
        
        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("DateColumn"))
        dateColumn.title = "Date Modified"
        dateColumn.width = 150
        dateColumn.minWidth = 80
        dateColumn.resizingMask = []
        dateColumn.sortDescriptorPrototype = NSSortDescriptor(key: "dateModified", ascending: false)
        
        let dateHeaderCell = ColoredHeaderCell()
        dateHeaderCell.stringValue = "Date Modified"
        dateHeaderCell.font = NSFont.systemFont(ofSize: 11)
        dateHeaderCell.customTextColor = NSColor(calibratedWhite: 0.4, alpha: 1.0)
        dateHeaderCell.gradientStartColor = NSColor(calibratedWhite: 0.95, alpha: 1.0)
        dateHeaderCell.gradientEndColor = NSColor(calibratedWhite: 0.88, alpha: 1.0)
        dateHeaderCell.columnIdentifier = "DateColumn"
        dateColumn.headerCell = dateHeaderCell
        tableView.addTableColumn(dateColumn)
        
        
        tableView.headerView = ConstrainedTableHeaderView()
        
        scrollView.documentView = tableView
        
        
        statusLabel = NSTextField(labelWithString: "0 notes")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.systemFont(ofSize: 10)
        statusLabel.textColor = .tertiaryLabelColor
        statusLabel.alignment = .left
        
        
        containerView.addSubview(scrollView)
        containerView.addSubview(statusLabel)

        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            statusLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -4),
            statusLabel.heightAnchor.constraint(equalToConstant: 20)
        ])

        
        scrollViewBottomConstraint = scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor)
        scrollViewBottomConstraint?.isActive = true

        self.view = containerView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        loadSavedColumnProportions()
        
        configureTableView()
        applyPreferences()
        
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange),
            name: .preferencesDidChange,
            object: nil
        )
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.delegate = self
    }

    func windowWillClose(_ notification: Notification) {
        if Preferences.shared.quitWhenClosingWindow {
            NSApp.terminate(nil)
        }
    }

    private func loadSavedColumnProportions() {
        let prefs = Preferences.shared
        titleColumnProportion = prefs.titleColumnProportion
        tagsColumnProportion = prefs.tagsColumnProportion
        dateColumnProportion = prefs.dateColumnProportion
        hasLoadedSavedProportions = true
    }
    
    @objc private func preferencesDidChange(_ notification: Notification) {
        applyPreferences()
        tableView.reloadData()
    }
    
    private func applyPreferences() {
        let prefs = Preferences.shared

        let rowHeight: CGFloat
        switch prefs.listTextSize {
        case .small: rowHeight = 17
        case .medium: rowHeight = 20
        case .large: rowHeight = 24
        }
        tableView.rowHeight = rowHeight

        if prefs.alwaysShowGridLines {
            tableView.gridStyleMask = [.solidHorizontalGridLineMask]
        } else {
            tableView.gridStyleMask = []
        }

        tableView.usesAlternatingRowBackgroundColors = prefs.alternatingRowColors

        
        let shouldShowStatusBar = prefs.showNoteListStatusBar
        if shouldShowStatusBar != statusBarVisible {
            statusBarVisible = shouldShowStatusBar
            updateStatusBarLayout()
        }
    }

    private func updateStatusBarLayout() {
        statusLabel.isHidden = !statusBarVisible

        
        scrollViewBottomConstraint?.isActive = false

        
        if statusBarVisible {
            scrollViewBottomConstraint = scrollView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor)
        } else {
            scrollViewBottomConstraint = scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        }
        scrollViewBottomConstraint?.isActive = true

        containerView.layoutSubtreeIfNeeded()
    }

    private func configureTableView() {
        tableView.delegate = self
        tableView.dataSource = self

        setupContextMenu()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(columnDidResize(_:)),
            name: NSTableView.columnDidResizeNotification,
            object: tableView
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(viewFrameDidChange(_:)),
            name: NSView.frameDidChangeNotification,
            object: tableView.enclosingScrollView
        )

        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(selectionIsChanging(_:)),
            name: NSTableView.selectionIsChangingNotification,
            object: tableView
        )
    }

    @objc private func selectionIsChanging(_ notification: Notification) {
        
        let visibleRows = tableView.rows(in: tableView.visibleRect)
        for row in visibleRows.lowerBound..<visibleRows.upperBound {
            updateTextColorsForRow(row)
        }
    }

    private func updateTextColorsForRow(_ row: Int) {
        guard row >= 0 && row < filteredNotes.count else { return }

        
        let rowView = tableView.rowView(atRow: row, makeIfNecessary: false)
        let isEmphasized = rowView?.isEmphasized ?? false
        let isRowSelected = rowView?.isSelected ?? tableView.selectedRowIndexes.contains(row)
        let shouldUseWhiteText = isRowSelected && isEmphasized

        
        if let titleColumnIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == "TitleColumn" }),
           let textField = tableView.view(atColumn: titleColumnIndex, row: row, makeIfNecessary: false) as? NSTextField {
            textField.textColor = shouldUseWhiteText ? .white : .black
        }

        
        if let dateColumnIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == "DateColumn" }),
           let textField = tableView.view(atColumn: dateColumnIndex, row: row, makeIfNecessary: false) as? NSTextField {
            textField.textColor = shouldUseWhiteText ? .white : .darkGray
        }
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        
        guard let scrollView = tableView.enclosingScrollView else { return }
        let availableWidth = scrollView.contentView.bounds.width
        
        
        if lastKnownWidth == 0 {
            lastKnownWidth = availableWidth
            applyProportionalWidths()
        }
        
        
        updateColumnMaxWidths()
    }
    
    @objc private func columnDidResize(_ notification: Notification) {
        guard !isUserResizing else { return }
        isUserResizing = true
        
        
        updateColumnProportions()
        
        
        constrainColumnWidths()
        updateColumnMaxWidths()
        
        isUserResizing = false
    }
    
    @objc private func viewFrameDidChange(_ notification: Notification) {
        guard let scrollView = tableView.enclosingScrollView else { return }
        let availableWidth = scrollView.contentView.bounds.width
        
        
        if abs(availableWidth - lastKnownWidth) > 1 {
            lastKnownWidth = availableWidth
            applyProportionalWidths()
        }
        
        updateColumnMaxWidths()
    }
    
    
    private func applyProportionalWidths() {
        guard let scrollView = tableView.enclosingScrollView else { return }
        let availableWidth = scrollView.contentView.bounds.width
        guard tableView.tableColumns.count == 3 else { return }
        
        let titleColumn = tableView.tableColumns[0]
        let tagsColumn = tableView.tableColumns[1]
        let dateColumn = tableView.tableColumns[2]
        
        
        var titleWidth = availableWidth * titleColumnProportion
        var tagsWidth = availableWidth * tagsColumnProportion
        var dateWidth = availableWidth * dateColumnProportion
        
        titleWidth = max(titleColumn.minWidth, titleWidth)
        tagsWidth = max(tagsColumn.minWidth, tagsWidth)
        dateWidth = max(dateColumn.minWidth, dateWidth)
        
        let total = titleWidth + tagsWidth + dateWidth
        if total > availableWidth {
            let scale = availableWidth / total
            titleWidth = max(titleColumn.minWidth, titleWidth * scale)
            tagsWidth = max(tagsColumn.minWidth, tagsWidth * scale)
            dateWidth = max(dateColumn.minWidth, availableWidth - titleWidth - tagsWidth)
        }
        
        
        titleColumn.width = titleWidth
        tagsColumn.width = tagsWidth
        dateColumn.width = dateWidth
    }
    
    
    private func updateColumnProportions() {
        guard let scrollView = tableView.enclosingScrollView else { return }
        let availableWidth = scrollView.contentView.bounds.width
        guard availableWidth > 0, tableView.tableColumns.count == 3 else { return }
        
        let titleColumn = tableView.tableColumns[0]
        let tagsColumn = tableView.tableColumns[1]
        let dateColumn = tableView.tableColumns[2]
        
        let totalWidth = titleColumn.width + tagsColumn.width + dateColumn.width
        guard totalWidth > 0 else { return }
        
        titleColumnProportion = titleColumn.width / totalWidth
        tagsColumnProportion = tagsColumn.width / totalWidth
        dateColumnProportion = dateColumn.width / totalWidth
        
        
        saveColumnProportions()
    }
    
    private func saveColumnProportions() {
        let prefs = Preferences.shared
        prefs.titleColumnProportion = titleColumnProportion
        prefs.tagsColumnProportion = tagsColumnProportion
        prefs.dateColumnProportion = dateColumnProportion
    }
    
    private func setupContextMenu() {
        let menu = NSMenu()
        
        
        let renameItem = NSMenuItem(title: "Rename", action: #selector(renameNote(_:)), keyEquivalent: "r")
        renameItem.keyEquivalentModifierMask = [.command]
        menu.addItem(renameItem)
        
        
        let tagItem = NSMenuItem(title: "Tag", action: #selector(editTags(_:)), keyEquivalent: "t")
        tagItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(tagItem)
        
        
        let deleteItem = NSMenuItem(title: "Delete...", action: #selector(deleteNote(_:)), keyEquivalent: "\u{8}") 
        deleteItem.keyEquivalentModifierMask = [.command]
        menu.addItem(deleteItem)

        menu.addItem(NSMenuItem.separator())

        
        let pinItem = NSMenuItem(title: "Pin/Unpin Note", action: #selector(togglePinNote(_:)), keyEquivalent: "p")
        pinItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(pinItem)

        menu.addItem(NSMenuItem.separator())
        
        
        let copyURLItem = NSMenuItem(title: "Copy URL", action: #selector(copyNoteURL(_:)), keyEquivalent: "c")
        copyURLItem.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(copyURLItem)
        
        
        let exportItem = NSMenuItem(title: "Export...", action: #selector(exportNote(_:)), keyEquivalent: "e")
        exportItem.keyEquivalentModifierMask = [.command]
        menu.addItem(exportItem)
        
        
        let showInFinderItem = NSMenuItem(title: "Show in Finder", action: #selector(showInFinder(_:)), keyEquivalent: "r")
        showInFinderItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(showInFinderItem)
        
        
        let editWithItem = NSMenuItem(title: "Edit With", action: nil, keyEquivalent: "")
        let editWithSubmenu = NSMenu()
        editWithSubmenu.addItem(NSMenuItem(title: "Default Editor", action: #selector(openWithDefaultEditor(_:)), keyEquivalent: ""))
        editWithSubmenu.addItem(NSMenuItem(title: "TextEdit", action: #selector(openWithTextEdit(_:)), keyEquivalent: ""))
        editWithSubmenu.addItem(NSMenuItem.separator())
        editWithSubmenu.addItem(NSMenuItem(title: "Other...", action: #selector(openWithOther(_:)), keyEquivalent: ""))
        editWithItem.submenu = editWithSubmenu
        menu.addItem(editWithItem)
        
        menu.addItem(NSMenuItem.separator())
        
        
        let printItem = NSMenuItem(title: "Print...", action: #selector(printNote(_:)), keyEquivalent: "p")
        printItem.keyEquivalentModifierMask = [.command]
        menu.addItem(printItem)
        
        tableView.menu = menu
    }
    
    
    
    private func clickedNote() -> Note? {
        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0 && clickedRow < filteredNotes.count else { return nil }
        return filteredNotes[clickedRow]
    }
    
    @objc private func renameNote(_ sender: Any?) {
        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0 && clickedRow < filteredNotes.count else { return }

        
        tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)

        
        editingTitleRow = clickedRow

        if let titleColumnIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == "TitleColumn" }),
           let textField = tableView.view(atColumn: titleColumnIndex, row: clickedRow, makeIfNecessary: false) as? NSTextField {
            textField.isEditable = true
            textField.isBordered = true
            textField.drawsBackground = true
            textField.backgroundColor = .white
            textField.textColor = .black
            textField.delegate = self
            tableView.window?.makeFirstResponder(textField)
        }
    }
    
    @objc private func editTags(_ sender: Any?) {
        let clickedRow = tableView.clickedRow
        guard clickedRow >= 0 && clickedRow < filteredNotes.count else { return }
        
        
        tableView.selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
        
        
        if let tagsColumnIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == "TagsColumn" }) {
            
            if let containerView = tableView.view(atColumn: tagsColumnIndex, row: clickedRow, makeIfNecessary: false) as? TagContainerView {
                containerView.startEditing()
            }
        }
    }
    
    @objc private func deleteNote(_ sender: Any?) {
        guard let note = clickedNote() else { return }
        
        
        let alert = NSAlert()
        alert.messageText = "Delete Note"
        alert.informativeText = "Are you sure you want to delete \"\(note.title)\"? This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            NoteManager.shared.deleteNote(note)
        }
    }
    
    @objc private func copyNoteURL(_ sender: Any?) {
        guard let note = clickedNote() else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        let directoryURL = note.fileURL.deletingLastPathComponent()
        pasteboard.setString(directoryURL.path, forType: .string)
    }

    @objc private func togglePinNote(_ sender: Any?) {
        guard let note = clickedNote() else { return }
        NoteManager.shared.togglePinNote(note)
    }

    @objc private func exportNote(_ sender: Any?) {
        guard let note = clickedNote() else { return }
        
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = note.fileName
        savePanel.allowedContentTypes = [.rtf]
        savePanel.canSelectHiddenExtension = true
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try FileManager.default.copyItem(at: note.fileURL, to: url)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }
    
    @objc private func showInFinder(_ sender: Any?) {
        guard let note = clickedNote() else { return }
        NSWorkspace.shared.activateFileViewerSelecting([note.fileURL])
    }
    
    @objc private func openWithDefaultEditor(_ sender: Any?) {
        guard let note = clickedNote() else { return }
        NSWorkspace.shared.open(note.fileURL)
    }
    
    @objc private func openWithTextEdit(_ sender: Any?) {
        guard let note = clickedNote() else { return }
        if let textEditURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") {
            NSWorkspace.shared.open([note.fileURL], withApplicationAt: textEditURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }
    
    @objc private func openWithOther(_ sender: Any?) {
        guard let note = clickedNote() else { return }
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.directoryURL = URL(fileURLWithPath: "/Applications")
        openPanel.allowedContentTypes = [.application]
        openPanel.message = "Choose an application to open the note with"
        
        if openPanel.runModal() == .OK, let appURL = openPanel.url {
            NSWorkspace.shared.open([note.fileURL], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }
    
    @objc private func printNote(_ sender: Any?) {
        guard let note = clickedNote() else { return }
        
        let fullContent: NSAttributedString
        if let bodyAttrString = note.content.rtfAttributedString() {
            let titleAttr = NSMutableAttributedString(string: note.title + "\n\n", attributes: [
                .font: NSFont.boldSystemFont(ofSize: 14)
            ])
            titleAttr.append(bodyAttrString)
            fullContent = titleAttr
        } else {
            fullContent = NSAttributedString(string: note.title + "\n\n" + note.content, attributes: [
                .font: NSFont.systemFont(ofSize: 12)
            ])
        }
        
        
        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        printInfo.leftMargin = 72
        printInfo.rightMargin = 72
        printInfo.topMargin = 72
        printInfo.bottomMargin = 72
        
        let pageWidth = printInfo.paperSize.width - printInfo.leftMargin - printInfo.rightMargin
        let pageHeight = printInfo.paperSize.height - printInfo.topMargin - printInfo.bottomMargin
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        textView.textStorage?.setAttributedString(fullContent)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: pageWidth, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        
        let printOperation = NSPrintOperation(view: textView, printInfo: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        
        printOperation.run()
    }
    
    func updateNotes(_ notes: [Note]) {
        self.notes = notes
        self.filteredNotes = notes
        self.currentSearchQuery = ""
        applySortIfNeeded()
        tableView.reloadData()
        updateStatusLabel()
    }
    
    func filterNotes(_ filtered: [Note], searchQuery: String = "") {
        self.filteredNotes = filtered
        self.currentSearchQuery = searchQuery
        applySortIfNeeded()
        tableView.reloadData()
        updateStatusLabel()
    }
    
    func selectNote(_ note: Note?) {
        guard let note = note,
              let index = filteredNotes.firstIndex(where: { $0.id == note.id }) else {
            tableView.deselectAll(nil)
            return
        }

        tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        tableView.scrollRowToVisible(index)
    }

    func selectNextNote() {
        let currentRow = tableView.selectedRow
        let nextRow = currentRow + 1
        guard nextRow < filteredNotes.count else { return }
        tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(nextRow)
        onNoteSelected?(filteredNotes[nextRow])
    }

    func selectPreviousNote() {
        let currentRow = tableView.selectedRow
        let prevRow = currentRow - 1
        guard prevRow >= 0 else { return }
        tableView.selectRowIndexes(IndexSet(integer: prevRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(prevRow)
        onNoteSelected?(filteredNotes[prevRow])
    }

    

    func startEditingTagsForSelectedNote() {
        let row = tableView.selectedRow
        guard row >= 0 && row < filteredNotes.count else { return }

        if let tagsColumnIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == "TagsColumn" }),
           let containerView = tableView.view(atColumn: tagsColumnIndex, row: row, makeIfNecessary: false) as? TagContainerView {
            containerView.startEditing()
        }
    }

    private var editingTitleRow: Int = -1

    func startRenamingSelectedNote() {
        let row = tableView.selectedRow
        guard row >= 0 && row < filteredNotes.count else { return }

        editingTitleRow = row

        if let titleColumnIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == "TitleColumn" }),
           let textField = tableView.view(atColumn: titleColumnIndex, row: row, makeIfNecessary: false) as? NSTextField {
            textField.isEditable = true
            textField.isBordered = true
            textField.drawsBackground = true
            textField.backgroundColor = .white
            textField.textColor = .black
            textField.delegate = self
            tableView.window?.makeFirstResponder(textField)
        }
    }

    private func updateStatusLabel() {
        statusLabel.stringValue = "\(filteredNotes.count) notes"
    }
    
    private func constrainColumnWidths() {
        guard let scrollView = tableView.enclosingScrollView else { return }
        let availableWidth = scrollView.contentView.bounds.width
        
        guard tableView.tableColumns.count == 3 else { return }
        let titleColumn = tableView.tableColumns[0]
        let tagsColumn = tableView.tableColumns[1]
        let dateColumn = tableView.tableColumns[2]
        
        let titleAndTagsWidth = titleColumn.width + tagsColumn.width
        
        let dateTargetWidth = max(dateColumn.minWidth, availableWidth - titleAndTagsWidth)
        
        let totalWidth = titleAndTagsWidth + dateTargetWidth
        if totalWidth > availableWidth {
            let excess = totalWidth - availableWidth
            
            var remaining = excess
            let tagsShrink = min(remaining, tagsColumn.width - tagsColumn.minWidth)
            if tagsShrink > 0 {
                tagsColumn.width -= tagsShrink
                remaining -= tagsShrink
            }
            
            if remaining > 0 {
                let titleShrink = min(remaining, titleColumn.width - titleColumn.minWidth)
                if titleShrink > 0 {
                    titleColumn.width -= titleShrink
                }
            }
        }
        
        let finalTitleAndTags = titleColumn.width + tagsColumn.width
        dateColumn.width = max(dateColumn.minWidth, availableWidth - finalTitleAndTags)
    }
    
    private func updateColumnMaxWidths() {
        guard let scrollView = tableView.enclosingScrollView else { return }
        let availableWidth = scrollView.contentView.bounds.width
        
        guard tableView.tableColumns.count == 3 else { return }
        let titleColumn = tableView.tableColumns[0]
        let tagsColumn = tableView.tableColumns[1]
        let dateColumn = tableView.tableColumns[2]
        
        titleColumn.maxWidth = max(titleColumn.minWidth, availableWidth - tagsColumn.minWidth - dateColumn.minWidth)
        
        tagsColumn.maxWidth = max(tagsColumn.minWidth, availableWidth - titleColumn.minWidth - dateColumn.minWidth)
        
    }
    
    private func updateSortIndicators() {
        
        
        if let headerView = tableView.headerView {
            headerView.needsDisplay = true
            headerView.display()
        }
    }
}

extension NoteListViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredNotes.count
    }
}

extension NoteListViewController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn else { return nil }

        let note = filteredNotes[row]
        let identifier = column.identifier

        
        let rowView = tableView.rowView(atRow: row, makeIfNecessary: false)
        let isEmphasized = rowView?.isEmphasized ?? true
        let isRowSelected = rowView?.isSelected ?? tableView.selectedRowIndexes.contains(row)
        let isSelected = isRowSelected && isEmphasized

        let fontSize = Preferences.shared.listTextSize.fontSize

        switch identifier.rawValue {
        case "TitleColumn":
            var textField = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField

            if textField == nil {
                textField = NSTextField()
                textField?.identifier = identifier
                textField?.isBordered = false
                textField?.drawsBackground = false
                textField?.backgroundColor = .clear
                textField?.cell?.lineBreakMode = .byTruncatingTail
                textField?.cell?.truncatesLastVisibleLine = true
            }

            let displayTitle = note.title.map { $0.isNewline || $0.isASCII && $0.asciiValue! < 32 ? "?" : String($0) }.joined()
            let pinPrefix = note.isPinned ? "📌 " : ""
            let fullTitle = pinPrefix + displayTitle

            
            if Preferences.shared.enableSearchHighlight && !currentSearchQuery.isEmpty && !isSelected {
                let attributedTitle = NSMutableAttributedString(string: fullTitle)
                let baseAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: fontSize),
                    .foregroundColor: NSColor.black
                ]
                attributedTitle.addAttributes(baseAttrs, range: NSRange(location: 0, length: attributedTitle.length))

                
                let searchLower = currentSearchQuery.lowercased()
                let titleLower = fullTitle.lowercased()
                var searchStart = titleLower.startIndex

                while let range = titleLower.range(of: searchLower, range: searchStart..<titleLower.endIndex) {
                    let nsRange = NSRange(range, in: fullTitle)
                    attributedTitle.addAttribute(.backgroundColor, value: Preferences.shared.searchHighlightColor, range: nsRange)
                    searchStart = range.upperBound
                }

                textField?.attributedStringValue = attributedTitle
            } else {
                textField?.font = NSFont.systemFont(ofSize: fontSize)
                textField?.stringValue = fullTitle
                textField?.textColor = isSelected ? .white : .black
            }
            textField?.isEditable = false

            return textField
            
        case "TagsColumn":
            let tagContainerIdentifier = NSUserInterfaceItemIdentifier("TagsContainer")
            var containerView = tableView.makeView(withIdentifier: tagContainerIdentifier, owner: self) as? TagContainerView
            
            if containerView == nil {
                containerView = TagContainerView()
                containerView?.identifier = tagContainerIdentifier
            }
            
            let sortedTags = note.tags.sorted()
            containerView?.configure(tags: sortedTags, row: row, isSelected: isSelected, delegate: self)
            containerView?.onTagClicked = { [weak self] tag in
                self?.onTagClicked?(tag)
            }

            return containerView
            
        case "DateColumn":
            var textField = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField
            
            if textField == nil {
                textField = NSTextField()
                textField?.identifier = identifier
                textField?.isBordered = false
                textField?.drawsBackground = false
                textField?.backgroundColor = .clear
                textField?.cell?.lineBreakMode = .byTruncatingTail
                textField?.cell?.truncatesLastVisibleLine = true
            }
            
            textField?.font = NSFont.systemFont(ofSize: fontSize)
            
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
            textField?.stringValue = formatter.string(from: note.dateModified)
            textField?.isEditable = false
            textField?.textColor = isSelected ? .white : .darkGray
            textField?.alignment = .left
            
            return textField
            
        default:
            return nil
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let visibleRows = tableView.rows(in: tableView.visibleRect)
        tableView.reloadData(forRowIndexes: IndexSet(integersIn: visibleRows.lowerBound..<visibleRows.upperBound),
                             columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns))

        onNoteSelected?(selectedNote)
    }

    
    private func customCompare(_ string1: String, _ string2: String, ascending: Bool) -> Bool {
        let char1 = string1.first
        let char2 = string2.first

        let isAlphanumeric1 = char1?.isLetter == true || char1?.isNumber == true
        let isAlphanumeric2 = char2?.isLetter == true || char2?.isNumber == true

        
        if isAlphanumeric1 != isAlphanumeric2 {
            if ascending {
                
                return isAlphanumeric2
            } else {
                
                return isAlphanumeric1
            }
        }

        
        let result = string1.localizedCaseInsensitiveCompare(string2)
        return ascending ? result == .orderedAscending : result == .orderedDescending
    }

    
    private func applySortIfNeeded() {
        guard tableView != nil,
              let sortDescriptor = tableView.sortDescriptors.first,
              let key = sortDescriptor.key else {
            
            filteredNotes.sort { note1, note2 in
                if note1.isPinned != note2.isPinned {
                    return note1.isPinned
                }
                return note1.dateModified > note2.dateModified
            }
            return
        }

        let ascending = sortDescriptor.ascending

        
        filteredNotes.sort { note1, note2 in
            
            if note1.isPinned != note2.isPinned {
                return note1.isPinned
            }

            
            switch key {
            case "title":
                return customCompare(note1.title, note2.title, ascending: ascending)
            case "tags":
                let tags1 = note1.tags.sorted().joined(separator: ",")
                let tags2 = note2.tags.sorted().joined(separator: ",")
                return customCompare(tags1, tags2, ascending: ascending)
            case "dateModified":
                return ascending ? note1.dateModified < note2.dateModified : note1.dateModified > note2.dateModified
            default:
                return note1.dateModified > note2.dateModified
            }
        }
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        applySortIfNeeded()
        tableView.reloadData()

        
        updateSortIndicators()
    }
    
    func tableView(_ tableView: NSTableView, shouldReorderColumn columnIndex: Int, toColumn newColumnIndex: Int) -> Bool {
        return true
    }
}

extension NoteListViewController: NSTextFieldDelegate {
    func controlTextDidBeginEditing(_ obj: Notification) {
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }

        
        if editingTitleRow >= 0 && editingTitleRow < filteredNotes.count {
            let note = filteredNotes[editingTitleRow]
            let newTitle = textField.stringValue.trimmingCharacters(in: .whitespaces)

            
            textField.isEditable = false
            textField.isBordered = false
            textField.drawsBackground = false
            textField.backgroundColor = .clear

            if !newTitle.isEmpty && newTitle != note.title {
                do {
                    try NoteManager.shared.renameNote(note, to: newTitle)
                } catch {
                    
                    textField.stringValue = note.title
                }
            }

            editingTitleRow = -1
            return
        }

        
        let row = textField.tag
        guard row >= 0 && row < filteredNotes.count else { return }

        if let tagsColumnIndex = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == "TagsColumn" }),
           let containerView = tableView.view(atColumn: tagsColumnIndex, row: row, makeIfNecessary: false) as? TagContainerView {
            containerView.endEditing()
        }

        let note = filteredNotes[row]
        let tagsString = textField.stringValue

        let newTags = Set(tagsString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty })

        note.tags = newTags

        NoteManager.shared.updateNoteTags(note)

        if let tagsColumn = tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == "TagsColumn" }) {
            tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: tagsColumn))
        }
    }

    

    private func deleteSelectedNote() {
        guard let note = selectedNote else { return }

        if Preferences.shared.confirmNoteDeletion {
            let alert = NSAlert()
            alert.messageText = "Delete Note"
            alert.informativeText = "Are you sure you want to delete \"\(note.title)\"? This cannot be undone."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")

            if alert.runModal() == .alertFirstButtonReturn {
                NoteManager.shared.deleteNote(note)
            }
        } else {
            NoteManager.shared.deleteNote(note)
        }
    }
}
