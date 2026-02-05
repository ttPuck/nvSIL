
import Cocoa

class Preferences {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let listTextSize = "listTextSize"
        static let bringToFrontHotkey = "bringToFrontHotkey"
        static let autoSelectNotesByTitle = "autoSelectNotesByTitle"
        static let confirmNoteDeletion = "confirmNoteDeletion"
        static let quitWhenClosingWindow = "quitWhenClosingWindow"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let hideDockIcon = "hideDockIcon"
        static let enableNoteLinking = "enableNoteLinking"
        static let notesDirectoryBookmark = "notesDirectoryBookmark"
        static let storeNotesAsRTF = "storeNotesAsRTF"
        static let watchForExternalChanges = "watchForExternalChanges"
        static let copyBasicStylesFromOtherApps = "copyBasicStylesFromOtherApps"
        static let checkSpellingAsYouType = "checkSpellingAsYouType"
        static let tabKeyIndentsLines = "tabKeyIndentsLines"
        static let useSoftTabs = "useSoftTabs"
        static let makeURLsClickableLinks = "makeURLsClickableLinks"
        static let suggestTitlesForNoteLinks = "suggestTitlesForNoteLinks"
        static let rightToLeftDirection = "rightToLeftDirection"
        static let autoPairCharacters = "autoPairCharacters"
        static let externalEditorBundleID = "externalEditorBundleID"
        static let bodyFontName = "bodyFontName"
        static let bodyFontSize = "bodyFontSize"
        static let enableSearchHighlight = "enableSearchHighlight"
        static let searchHighlightColor = "searchHighlightColor"
        static let foregroundTextColor = "foregroundTextColor"
        static let backgroundColor = "backgroundColor"
        static let alwaysShowGridLines = "alwaysShowGridLines"
        static let alternatingRowColors = "alternatingRowColors"
        static let keepNoteBodyWidthReadable = "keepNoteBodyWidthReadable"
        static let showEditorStatusBar = "showEditorStatusBar"
        static let showNoteListStatusBar = "showNoteListStatusBar"
        static let splitViewDividerPosition = "splitViewDividerPosition"
        static let titleColumnProportion = "titleColumnProportion"
        static let tagsColumnProportion = "tagsColumnProportion"
        static let dateColumnProportion = "dateColumnProportion"
    }

    // MARK: - General

    enum ListTextSize: String, CaseIterable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"

        var fontSize: CGFloat {
            switch self {
            case .small: return 11
            case .medium: return 13
            case .large: return 15
            }
        }
    }

    var listTextSize: ListTextSize {
        get {
            if let value = defaults.string(forKey: Keys.listTextSize),
               let size = ListTextSize(rawValue: value) {
                return size
            }
            return .small
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.listTextSize)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var bringToFrontHotkey: String {
        get { defaults.string(forKey: Keys.bringToFrontHotkey) ?? "⌘=" }
        set {
            defaults.set(newValue, forKey: Keys.bringToFrontHotkey)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var autoSelectNotesByTitle: Bool {
        get { defaults.bool(forKey: Keys.autoSelectNotesByTitle) }
        set {
            defaults.set(newValue, forKey: Keys.autoSelectNotesByTitle)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var confirmNoteDeletion: Bool {
        get {
            if defaults.object(forKey: Keys.confirmNoteDeletion) == nil {
                return true // Default to true
            }
            return defaults.bool(forKey: Keys.confirmNoteDeletion)
        }
        set {
            defaults.set(newValue, forKey: Keys.confirmNoteDeletion)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var quitWhenClosingWindow: Bool {
        get {
            if defaults.object(forKey: Keys.quitWhenClosingWindow) == nil {
                return true // Default to true
            }
            return defaults.bool(forKey: Keys.quitWhenClosingWindow)
        }
        set {
            defaults.set(newValue, forKey: Keys.quitWhenClosingWindow)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var showMenuBarIcon: Bool {
        get { defaults.bool(forKey: Keys.showMenuBarIcon) }
        set {
            defaults.set(newValue, forKey: Keys.showMenuBarIcon)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var hideDockIcon: Bool {
        get { defaults.bool(forKey: Keys.hideDockIcon) }
        set {
            defaults.set(newValue, forKey: Keys.hideDockIcon)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var enableNoteLinking: Bool {
        get {
            if defaults.object(forKey: Keys.enableNoteLinking) == nil {
                return true // Default to true
            }
            return defaults.bool(forKey: Keys.enableNoteLinking)
        }
        set {
            defaults.set(newValue, forKey: Keys.enableNoteLinking)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    // MARK: - Notes

    var notesDirectoryBookmark: Data? {
        get { defaults.data(forKey: Keys.notesDirectoryBookmark) }
        set {
            defaults.set(newValue, forKey: Keys.notesDirectoryBookmark)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var storeNotesAsRTF: Bool {
        get {
            if defaults.object(forKey: Keys.storeNotesAsRTF) == nil {
                return true // Default to RTF
            }
            return defaults.bool(forKey: Keys.storeNotesAsRTF)
        }
        set {
            defaults.set(newValue, forKey: Keys.storeNotesAsRTF)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var watchForExternalChanges: Bool {
        get {
            if defaults.object(forKey: Keys.watchForExternalChanges) == nil {
                return true // Default to true
            }
            return defaults.bool(forKey: Keys.watchForExternalChanges)
        }
        set {
            defaults.set(newValue, forKey: Keys.watchForExternalChanges)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    // MARK: - Editing

    var copyBasicStylesFromOtherApps: Bool {
        get {
            if defaults.object(forKey: Keys.copyBasicStylesFromOtherApps) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.copyBasicStylesFromOtherApps)
        }
        set {
            defaults.set(newValue, forKey: Keys.copyBasicStylesFromOtherApps)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var checkSpellingAsYouType: Bool {
        get {
            if defaults.object(forKey: Keys.checkSpellingAsYouType) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.checkSpellingAsYouType)
        }
        set {
            defaults.set(newValue, forKey: Keys.checkSpellingAsYouType)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var tabKeyIndentsLines: Bool {
        get {
            if defaults.object(forKey: Keys.tabKeyIndentsLines) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.tabKeyIndentsLines)
        }
        set {
            defaults.set(newValue, forKey: Keys.tabKeyIndentsLines)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var useSoftTabs: Bool {
        get { defaults.bool(forKey: Keys.useSoftTabs) }
        set {
            defaults.set(newValue, forKey: Keys.useSoftTabs)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var makeURLsClickableLinks: Bool {
        get {
            if defaults.object(forKey: Keys.makeURLsClickableLinks) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.makeURLsClickableLinks)
        }
        set {
            defaults.set(newValue, forKey: Keys.makeURLsClickableLinks)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var suggestTitlesForNoteLinks: Bool {
        get {
            if defaults.object(forKey: Keys.suggestTitlesForNoteLinks) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.suggestTitlesForNoteLinks)
        }
        set {
            defaults.set(newValue, forKey: Keys.suggestTitlesForNoteLinks)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var rightToLeftDirection: Bool {
        get { defaults.bool(forKey: Keys.rightToLeftDirection) }
        set {
            defaults.set(newValue, forKey: Keys.rightToLeftDirection)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var autoPairCharacters: Bool {
        get { defaults.bool(forKey: Keys.autoPairCharacters) }
        set {
            defaults.set(newValue, forKey: Keys.autoPairCharacters)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var externalEditorBundleID: String {
        get { defaults.string(forKey: Keys.externalEditorBundleID) ?? "com.apple.TextEdit" }
        set {
            defaults.set(newValue, forKey: Keys.externalEditorBundleID)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    // MARK: - Fonts & Colors

    var bodyFont: NSFont {
        get {
            let name = defaults.string(forKey: Keys.bodyFontName) ?? "Helvetica"
            let size = defaults.object(forKey: Keys.bodyFontSize) != nil
                ? CGFloat(defaults.float(forKey: Keys.bodyFontSize))
                : 12.0
            return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
        }
        set {
            defaults.set(newValue.fontName, forKey: Keys.bodyFontName)
            defaults.set(Float(newValue.pointSize), forKey: Keys.bodyFontSize)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var enableSearchHighlight: Bool {
        get {
            if defaults.object(forKey: Keys.enableSearchHighlight) == nil {
                return true
            }
            return defaults.bool(forKey: Keys.enableSearchHighlight)
        }
        set {
            defaults.set(newValue, forKey: Keys.enableSearchHighlight)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var searchHighlightColor: NSColor {
        get {
            if let data = defaults.data(forKey: Keys.searchHighlightColor),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return color
            }
            return NSColor.systemOrange
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false) {
                defaults.set(data, forKey: Keys.searchHighlightColor)
                NotificationCenter.default.post(name: .preferencesDidChange, object: self)
            }
        }
    }

    var foregroundTextColor: NSColor {
        get {
            if let data = defaults.data(forKey: Keys.foregroundTextColor),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return color
            }
            return NSColor.black
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false) {
                defaults.set(data, forKey: Keys.foregroundTextColor)
                NotificationCenter.default.post(name: .preferencesDidChange, object: self)
            }
        }
    }

    var backgroundColor: NSColor {
        get {
            if let data = defaults.data(forKey: Keys.backgroundColor),
               let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return color
            }
            return NSColor(calibratedRed: 1.0, green: 0.95, blue: 0.95, alpha: 1.0)
        }
        set {
            if let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false) {
                defaults.set(data, forKey: Keys.backgroundColor)
                NotificationCenter.default.post(name: .preferencesDidChange, object: self)
            }
        }
    }

    var alwaysShowGridLines: Bool {
        get {
            if defaults.object(forKey: Keys.alwaysShowGridLines) == nil { return true }
            return defaults.bool(forKey: Keys.alwaysShowGridLines)
        }
        set {
            defaults.set(newValue, forKey: Keys.alwaysShowGridLines)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var alternatingRowColors: Bool {
        get {
            if defaults.object(forKey: Keys.alternatingRowColors) == nil { return true }
            return defaults.bool(forKey: Keys.alternatingRowColors)
        }
        set {
            defaults.set(newValue, forKey: Keys.alternatingRowColors)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var keepNoteBodyWidthReadable: Bool {
        get { defaults.bool(forKey: Keys.keepNoteBodyWidthReadable) }
        set {
            defaults.set(newValue, forKey: Keys.keepNoteBodyWidthReadable)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var showEditorStatusBar: Bool {
        get {
            if defaults.object(forKey: Keys.showEditorStatusBar) == nil { return true }
            return defaults.bool(forKey: Keys.showEditorStatusBar)
        }
        set {
            defaults.set(newValue, forKey: Keys.showEditorStatusBar)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    var showNoteListStatusBar: Bool {
        get {
            if defaults.object(forKey: Keys.showNoteListStatusBar) == nil { return true }
            return defaults.bool(forKey: Keys.showNoteListStatusBar)
        }
        set {
            defaults.set(newValue, forKey: Keys.showNoteListStatusBar)
            NotificationCenter.default.post(name: .preferencesDidChange, object: self)
        }
    }

    // MARK: - UI State

    var splitViewDividerPosition: CGFloat {
        get {
            let value = defaults.double(forKey: Keys.splitViewDividerPosition)
            return value > 0 ? CGFloat(value) : 0.5  // Default to 50%
        }
        set {
            defaults.set(Double(newValue), forKey: Keys.splitViewDividerPosition)
        }
    }

    var titleColumnProportion: CGFloat {
        get {
            let value = defaults.double(forKey: Keys.titleColumnProportion)
            return value > 0 ? CGFloat(value) : 0.52
        }
        set {
            defaults.set(Double(newValue), forKey: Keys.titleColumnProportion)
        }
    }

    var tagsColumnProportion: CGFloat {
        get {
            let value = defaults.double(forKey: Keys.tagsColumnProportion)
            return value > 0 ? CGFloat(value) : 0.21
        }
        set {
            defaults.set(Double(newValue), forKey: Keys.tagsColumnProportion)
        }
    }

    var dateColumnProportion: CGFloat {
        get {
            let value = defaults.double(forKey: Keys.dateColumnProportion)
            return value > 0 ? CGFloat(value) : 0.27
        }
        set {
            defaults.set(Double(newValue), forKey: Keys.dateColumnProportion)
        }
    }


    // MARK: - Init

    private init() {
        registerDefaults()
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            Keys.listTextSize: ListTextSize.small.rawValue,
            Keys.autoSelectNotesByTitle: true,
            Keys.confirmNoteDeletion: true,
            Keys.quitWhenClosingWindow: true,
            Keys.enableNoteLinking: true,
            Keys.showMenuBarIcon: false,
            Keys.hideDockIcon: false,
            Keys.storeNotesAsRTF: true,
            Keys.watchForExternalChanges: true,
            Keys.copyBasicStylesFromOtherApps: true,
            Keys.checkSpellingAsYouType: true,
            Keys.tabKeyIndentsLines: true,
            Keys.useSoftTabs: false,
            Keys.makeURLsClickableLinks: true,
            Keys.suggestTitlesForNoteLinks: true,
            Keys.rightToLeftDirection: false,
            Keys.autoPairCharacters: false,
            Keys.bodyFontName: "Helvetica",
            Keys.bodyFontSize: 12.0,
            Keys.enableSearchHighlight: true,
            Keys.alwaysShowGridLines: true,
            Keys.alternatingRowColors: true,
            Keys.keepNoteBodyWidthReadable: false,
            Keys.showEditorStatusBar: true,
            Keys.showNoteListStatusBar: true
        ])
    }
}

extension Notification.Name {
    static let preferencesDidChange = Notification.Name("nvSIL.preferencesDidChange")
}
