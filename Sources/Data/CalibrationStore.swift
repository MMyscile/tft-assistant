import Foundation
import SwiftUI

class CalibrationStore: ObservableObject {
    static let shared = CalibrationStore()

    @Published var calibration: CalibrationData
    @Published var isCalibrated: Bool = false

    private let fileURL: URL

    private init() {
        // Stocker dans Application Support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("TFTAssistant", isDirectory: true)

        // Créer le dossier si nécessaire
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        self.fileURL = appFolder.appendingPathComponent("calibration.json")
        self.calibration = .empty

        load()
    }

    // MARK: - Load

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("[Calibration] No saved calibration found")
            isCalibrated = false
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode(CalibrationData.self, from: data)

            // Charger et migrer si nécessaire (le init(from:) gère la migration)
            self.calibration = decoded
            self.isCalibrated = decoded.isValid

            if decoded.version < CalibrationData.currentVersion {
                print("[Calibration] Migrated from v\(decoded.version) to v\(CalibrationData.currentVersion)")
                save()  // Sauvegarder la version migrée
            } else {
                print("[Calibration] Loaded calibration from \(decoded.calibrationDate)")
            }
        } catch {
            print("[Calibration] Failed to load: \(error.localizedDescription)")
            self.calibration = .empty
            self.isCalibrated = false
        }
    }

    // MARK: - Save

    func save() {
        calibration.calibrationDate = Date()
        calibration.version = CalibrationData.currentVersion

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(calibration)
            try data.write(to: fileURL)

            isCalibrated = calibration.isValid
            print("[Calibration] Saved calibration")
        } catch {
            print("[Calibration] Failed to save: \(error.localizedDescription)")
        }
    }

    // MARK: - Update Zones

    func updateZone(_ type: CalibrationZoneType, rect: NormalizedRect) {
        switch type {
        case .stage:
            calibration.stageZone = rect
        case .augments:
            calibration.augmentsZone = rect
        case .items:
            calibration.itemsZone = rect
        }

        // Mettre à jour isCalibrated immédiatement
        isCalibrated = calibration.isValid

        // Sauvegarder automatiquement
        save()

        print("[Calibration] Updated \(type.rawValue) zone (isCalibrated: \(isCalibrated))")
    }

    func getZone(_ type: CalibrationZoneType) -> NormalizedRect {
        switch type {
        case .stage:
            return calibration.stageZone
        case .augments:
            return calibration.augmentsZone
        case .items:
            return calibration.itemsZone
        }
    }

    // MARK: - Item Slots

    func updateItemSlots(_ config: ItemSlotsConfig) {
        calibration.itemSlots = config
        isCalibrated = calibration.isValid
        save()
        print("[Calibration] Updated item slots config (valid: \(config.isValid))")
    }

    func getItemSlotRects(for imageSize: CGSize) -> [CGRect] {
        return calibration.itemSlots.getSlotCGRects(for: imageSize)
    }

    var hasItemSlots: Bool {
        return calibration.itemSlots.isValid
    }

    // MARK: - Reset

    func reset() {
        calibration = .empty
        isCalibrated = false
        try? FileManager.default.removeItem(at: fileURL)
        print("[Calibration] Reset calibration")
    }
}
