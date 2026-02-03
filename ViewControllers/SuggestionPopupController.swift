import Cocoa

protocol SuggestionPopupDelegate: AnyObject {
    func suggestionPopup(_ popup: SuggestionPopupController, didSelectSuggestion suggestion: String)
    func suggestionPopupDidCancel(_ popup: SuggestionPopupController)
}

class SuggestionPopupController: NSObject {
    weak var delegate: SuggestionPopupDelegate?

    private var popupWindow: NSPanel?
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var suggestions: [String] = []
    private var selectedIndex: Int = 0

    private let maxVisibleRows = 8
    private let rowHeight: CGFloat = 22
    private let popupWidth: CGFloat = 250

    var isVisible: Bool {
        popupWindow?.isVisible ?? false
    }

    func show(at point: NSPoint, in parentWindow: NSWindow, suggestions: [String]) {
        self.suggestions = suggestions
        self.selectedIndex = 0

        if suggestions.isEmpty {
            hide()
            return
        }

        if popupWindow == nil {
            createPopupWindow()
        }

        // Calculate window frame
        let visibleRows = min(suggestions.count, maxVisibleRows)
        let height = CGFloat(visibleRows) * rowHeight + 4
        let frame = NSRect(x: point.x, y: point.y - height, width: popupWidth, height: height)

        popupWindow?.setFrame(frame, display: false)
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)

        parentWindow.addChildWindow(popupWindow!, ordered: .above)
        popupWindow?.orderFront(nil)
    }

    func hide() {
        if let window = popupWindow, let parent = window.parent {
            parent.removeChildWindow(window)
        }
        popupWindow?.orderOut(nil)
    }

    func updateSuggestions(_ newSuggestions: [String]) {
        suggestions = newSuggestions
        selectedIndex = 0

        if suggestions.isEmpty {
            hide()
            return
        }

        guard let window = popupWindow else { return }

        let visibleRows = min(suggestions.count, maxVisibleRows)
        let height = CGFloat(visibleRows) * rowHeight + 4
        var frame = window.frame
        frame.size.height = height
        frame.origin.y = window.frame.maxY - height
        window.setFrame(frame, display: true)

        tableView.reloadData()
        if suggestions.count > 0 {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    func moveSelectionUp() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = max(0, selectedIndex - 1)
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
    }

    func moveSelectionDown() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = min(suggestions.count - 1, selectedIndex + 1)
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
    }

    func confirmSelection() {
        guard selectedIndex >= 0, selectedIndex < suggestions.count else { return }
        let selected = suggestions[selectedIndex]
        hide()
        delegate?.suggestionPopup(self, didSelectSuggestion: selected)
    }

    func cancel() {
        hide()
        delegate?.suggestionPopupDidCancel(self)
    }

    private func createPopupWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: popupWidth, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hasShadow = true
        panel.backgroundColor = .white

        // Create scroll view
        scrollView = NSScrollView(frame: panel.contentView!.bounds)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .lineBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .white

        // Create table view
        tableView = NSTableView(frame: scrollView.bounds)
        tableView.headerView = nil
        tableView.rowHeight = rowHeight
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.backgroundColor = .white
        tableView.gridStyleMask = []
        tableView.selectionHighlightStyle = .regular
        tableView.allowsEmptySelection = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(rowDoubleClicked)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SuggestionColumn"))
        column.width = popupWidth - 20
        tableView.addTableColumn(column)

        scrollView.documentView = tableView
        panel.contentView?.addSubview(scrollView)

        popupWindow = panel
    }

    @objc private func rowDoubleClicked() {
        confirmSelection()
    }
}

extension SuggestionPopupController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return suggestions.count
    }
}

extension SuggestionPopupController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("SuggestionCell")
        var cellView = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView

        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = identifier

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingTail
            textField.cell?.truncatesLastVisibleLine = true
            cellView?.addSubview(textField)
            cellView?.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 6),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -6),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        }

        cellView?.textField?.stringValue = suggestions[row]
        cellView?.textField?.font = NSFont.systemFont(ofSize: 12)

        return cellView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedIndex = tableView.selectedRow
    }
}
