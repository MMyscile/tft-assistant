import Foundation
import SwiftUI

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard

    // MARK: - Keys
    private enum Keys {
        static let captureEnabled = "captureEnabled"
        static let captureFPS = "captureFPS"
        static let debugMode = "debugMode"
    }

    // MARK: - Published Properties (réactifs pour SwiftUI)

    @Published var captureEnabled: Bool {
        didSet {
            defaults.set(captureEnabled, forKey: Keys.captureEnabled)
            print("[Settings] captureEnabled = \(captureEnabled)")
        }
    }

    @Published var captureFPS: Int {
        didSet {
            defaults.set(captureFPS, forKey: Keys.captureFPS)
            print("[Settings] captureFPS = \(captureFPS)")
        }
    }

    @Published var debugMode: Bool {
        didSet {
            defaults.set(debugMode, forKey: Keys.debugMode)
            print("[Settings] debugMode = \(debugMode)")
        }
    }

    // MARK: - Init

    private init() {
        // Charger les valeurs sauvegardées ou utiliser les défauts
        self.captureEnabled = defaults.object(forKey: Keys.captureEnabled) as? Bool ?? false
        self.captureFPS = defaults.object(forKey: Keys.captureFPS) as? Int ?? 5
        self.debugMode = defaults.object(forKey: Keys.debugMode) as? Bool ?? false

        print("[Settings] Loaded: captureEnabled=\(captureEnabled), fps=\(captureFPS), debug=\(debugMode)")
    }

    // MARK: - Reset

    func resetToDefaults() {
        captureEnabled = false
        captureFPS = 5
        debugMode = false
        print("[Settings] Reset to defaults")
    }
}
