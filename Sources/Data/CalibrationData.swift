import Foundation
import CoreGraphics

/// Rectangle normalisé (0-1) pour être indépendant de la résolution
struct NormalizedRect: Codable, Equatable {
    var x: CGFloat      // 0 = gauche, 1 = droite
    var y: CGFloat      // 0 = haut, 1 = bas
    var width: CGFloat  // 0-1
    var height: CGFloat // 0-1

    static let zero = NormalizedRect(x: 0, y: 0, width: 0, height: 0)

    /// Convertit en CGRect pour une taille d'image donnée
    func toCGRect(for size: CGSize) -> CGRect {
        CGRect(
            x: x * size.width,
            y: y * size.height,
            width: width * size.width,
            height: height * size.height
        )
    }

    /// Crée depuis un CGRect et une taille d'image
    static func from(_ rect: CGRect, imageSize: CGSize) -> NormalizedRect {
        NormalizedRect(
            x: rect.origin.x / imageSize.width,
            y: rect.origin.y / imageSize.height,
            width: rect.width / imageSize.width,
            height: rect.height / imageSize.height
        )
    }

    var isValid: Bool {
        width > 0.01 && height > 0.01 // Au moins 1% de l'image
    }
}

/// Données de calibration pour toutes les zones
struct CalibrationData: Codable, Equatable {
    var stageZone: NormalizedRect
    var augmentsZone: NormalizedRect
    var itemsZone: NormalizedRect
    var screenResolution: CGSize
    var calibrationDate: Date
    var version: Int

    static let currentVersion = 1

    static let empty = CalibrationData(
        stageZone: .zero,
        augmentsZone: .zero,
        itemsZone: .zero,
        screenResolution: .zero,
        calibrationDate: Date(),
        version: currentVersion
    )

    var isValid: Bool {
        stageZone.isValid || augmentsZone.isValid || itemsZone.isValid
    }

    var hasStageZone: Bool { stageZone.isValid }
    var hasAugmentsZone: Bool { augmentsZone.isValid }
    var hasItemsZone: Bool { itemsZone.isValid }
}

/// Types de zones
enum CalibrationZoneType: String, CaseIterable, Identifiable {
    case stage = "Stage/Round"
    case augments = "Augments"
    case items = "Items"

    var id: String { rawValue }

    var color: String {
        switch self {
        case .stage: return "blue"
        case .augments: return "purple"
        case .items: return "orange"
        }
    }

    var description: String {
        switch self {
        case .stage: return "Zone où s'affiche le numéro du stage (ex: 3-2)"
        case .augments: return "Zone où apparaissent les 3 choix d'augments"
        case .items: return "Zone de l'inventaire (composants/items)"
        }
    }
}
