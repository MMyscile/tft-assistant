import AppKit
import Carbon.HIToolbox

class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventHotKey: EventHotKeyRef?
    private var onToggle: (() -> Void)?

    // Identifiant unique pour notre hotkey
    private let hotkeyID = EventHotKeyID(signature: OSType(0x54465441), id: 1) // "TFTA"

    private init() {}

    /// Configure le raccourci clavier global
    /// - Parameter onToggle: Closure appelée quand le raccourci est pressé
    func register(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle

        // Option (⌥) + T (pour TFT)
        let keyCode: UInt32 = UInt32(kVK_ANSI_T)
        let modifiers: UInt32 = UInt32(optionKey)

        // Installer le handler global
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotkey()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )

        // Enregistrer le raccourci
        var hotkeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr {
            eventHotKey = hotkeyRef
            print("[Hotkey] Registered ⌥T successfully")
        } else {
            print("[Hotkey] Failed to register hotkey, status: \(status)")
        }
    }

    private func handleHotkey() {
        print("[Hotkey] ⌥T pressed")
        DispatchQueue.main.async {
            self.onToggle?()
        }
    }

    func unregister() {
        if let hotkeyRef = eventHotKey {
            UnregisterEventHotKey(hotkeyRef)
            eventHotKey = nil
            print("[Hotkey] Unregistered")
        }
    }

    deinit {
        unregister()
    }
}
