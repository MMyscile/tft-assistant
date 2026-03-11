import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        setupMenuBar()
        setupHotkey()
        restoreOverlayState()
        print("[TFTAssistant] App launched successfully")
    }

    private func restoreOverlayState() {
        // Restaurer l'overlay si il était activé
        if UserDefaults.standard.bool(forKey: "overlayEnabled") {
            OverlayWindow.shared.showOverlay()
            print("[TFTAssistant] Overlay restored from previous session")
        }
    }

    private func setupHotkey() {
        HotkeyManager.shared.register { [weak self] in
            self?.togglePopover()
        }
        print("[TFTAssistant] Hotkey ⌥T registered")
    }

    private func setupMenuBar() {
        // Créer l'icône dans la barre de menu
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Utiliser un symbole SF pour l'icône (disponible macOS 11+)
            button.image = NSImage(systemSymbolName: "gamecontroller.fill", accessibilityDescription: "TFT Assistant")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Créer le popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: PopoverView())

        print("[TFTAssistant] Menu bar setup complete")
    }

    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
            print("[TFTAssistant] Popover closed")
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            print("[TFTAssistant] Popover opened")
        }
    }

    // Méthode publique pour toggle via raccourci clavier
    func togglePopoverFromHotkey() {
        togglePopover()
    }

    // Méthode pour ouvrir le popover (sans toggle)
    func showPopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            print("[TFTAssistant] Popover opened programmatically")
        }
    }
}
