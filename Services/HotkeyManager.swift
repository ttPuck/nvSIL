import Cocoa
import Carbon

// Global function for Carbon callback - must be outside the class
private func hotkeyCallback(
    nextHandler: EventHandlerCallRef?,
    theEvent: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    HotkeyManager.shared.handleHotkey()
    return noErr
}

class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {
        setupEventHandler()
        registerHotkey()

        // Listen for preference changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesDidChange),
            name: .preferencesDidChange,
            object: nil
        )
    }

    @objc private func preferencesDidChange() {
        registerHotkey()
    }

    private func setupEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        // Use GetEventDispatcherTarget for system-wide hotkey handling
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            hotkeyCallback,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        if status != noErr {
            print("Failed to install event handler: \(status)")
        }
    }

    func registerHotkey() {
        // Unregister existing hotkey
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }

        let hotkeyString = Preferences.shared.bringToFrontHotkey
        guard !hotkeyString.isEmpty, hotkeyString != "None" else { return }

        // Parse the hotkey string
        guard let (modifiers, keyCode) = parseHotkeyString(hotkeyString) else {
            print("Failed to parse hotkey string: \(hotkeyString)")
            return
        }

        // Register the hotkey with GetEventDispatcherTarget for global scope
        let hotkeyID = EventHotKeyID(signature: OSType(0x4E5653), id: 1) // "NVS\0"
        var newHotkeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetEventDispatcherTarget(),
            0,
            &newHotkeyRef
        )

        if status == noErr {
            hotkeyRef = newHotkeyRef
            print("Hotkey registered successfully: \(hotkeyString)")
        } else {
            print("Failed to register hotkey: \(status)")
        }
    }

    private func parseHotkeyString(_ string: String) -> (UInt32, UInt32)? {
        var modifiers: UInt32 = 0
        var keyChar: Character?

        for char in string {
            switch char {
            case "⌃": modifiers |= UInt32(controlKey)
            case "⌥": modifiers |= UInt32(optionKey)
            case "⇧": modifiers |= UInt32(shiftKey)
            case "⌘": modifiers |= UInt32(cmdKey)
            default: keyChar = char
            }
        }

        guard let key = keyChar else { return nil }
        guard let keyCode = keyCodeForCharacter(key) else { return nil }

        return (modifiers, keyCode)
    }

    private func keyCodeForCharacter(_ char: Character) -> UInt32? {
        let keyCodeMap: [Character: UInt32] = [
            "A": 0x00, "S": 0x01, "D": 0x02, "F": 0x03, "H": 0x04, "G": 0x05, "Z": 0x06, "X": 0x07,
            "C": 0x08, "V": 0x09, "B": 0x0B, "Q": 0x0C, "W": 0x0D, "E": 0x0E, "R": 0x0F, "T": 0x11,
            "Y": 0x10, "U": 0x20, "I": 0x22, "O": 0x1F, "P": 0x23, "L": 0x25, "J": 0x26, "K": 0x28,
            "N": 0x2D, "M": 0x2E,
            "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C,
            "9": 0x19, "0": 0x1D,
            "=": 0x18, "-": 0x1B, "[": 0x21, "]": 0x1E, "'": 0x27, ";": 0x29, "\\": 0x2A, ",": 0x2B,
            "/": 0x2C, ".": 0x2F, "`": 0x32,
            " ": 0x31 // Space
        ]

        let upperChar = Character(char.uppercased())
        return keyCodeMap[upperChar]
    }

    func handleHotkey() {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let window = NSApp.windows.first(where: { $0.isVisible }) ?? NSApp.windows.first {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    deinit {
        if let hotkeyRef = hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
        }
        if let eventHandlerRef = eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}
