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
    var itemsZone: NormalizedRect          // Ancien système (rectangle global)
    var itemSlots: ItemSlotsConfig         // Nouveau système (10 slots individuels)
    var screenResolution: CGSize
    var calibrationDate: Date
    var version: Int

    static let currentVersion = 2

    // Init membre-par-membre explicite (nécessaire car init(from:) est défini)
    init(
        stageZone: NormalizedRect,
        augmentsZone: NormalizedRect,
        itemsZone: NormalizedRect,
        itemSlots: ItemSlotsConfig,
        screenResolution: CGSize,
        calibrationDate: Date,
        version: Int
    ) {
        self.stageZone = stageZone
        self.augmentsZone = augmentsZone
        self.itemsZone = itemsZone
        self.itemSlots = itemSlots
        self.screenResolution = screenResolution
        self.calibrationDate = calibrationDate
        self.version = version
    }

    static let empty = CalibrationData(
        stageZone: .zero,
        augmentsZone: .zero,
        itemsZone: .zero,
        itemSlots: .empty,
        screenResolution: .zero,
        calibrationDate: Date(),
        version: currentVersion
    )

    // Migration depuis l'ancienne version
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        stageZone = try container.decode(NormalizedRect.self, forKey: .stageZone)
        augmentsZone = try container.decode(NormalizedRect.self, forKey: .augmentsZone)
        itemsZone = try container.decode(NormalizedRect.self, forKey: .itemsZone)
        screenResolution = try container.decode(CGSize.self, forKey: .screenResolution)
        calibrationDate = try container.decode(Date.self, forKey: .calibrationDate)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1

        // Migration: itemSlots n'existe pas dans v1
        itemSlots = try container.decodeIfPresent(ItemSlotsConfig.self, forKey: .itemSlots) ?? .empty
    }

    var isValid: Bool {
        stageZone.isValid || augmentsZone.isValid || itemsZone.isValid || itemSlots.isValid
    }

    var hasStageZone: Bool { stageZone.isValid }
    var hasAugmentsZone: Bool { augmentsZone.isValid }
    var hasItemsZone: Bool { itemsZone.isValid }
    var hasItemSlots: Bool { itemSlots.isValid }
}

/// Configuration des 10 slots d'items (calibration précise)
struct ItemSlotsConfig: Codable, Equatable {
    var firstSlotOrigin: CGPoint  // Position normalisée (0-1) du coin supérieur gauche du premier slot
    var slotSize: CGFloat         // Taille normalisée (carrée) de chaque slot
    var spacing: CGFloat          // Espacement normalisé entre les slots (vertical)
    var slotCount: Int            // Nombre de slots (10 par défaut)

    static let defaultSlotCount = 10

    static let empty = ItemSlotsConfig(
        firstSlotOrigin: .zero,
        slotSize: 0,
        spacing: 0,
        slotCount: defaultSlotCount
    )

    var isValid: Bool {
        slotSize > 0.005 && firstSlotOrigin.x > 0 && firstSlotOrigin.y > 0
    }

    /// Retourne les CGRect pour une taille d'image donnée
    /// Note: slotSize et spacing sont normalisés par la HAUTEUR de l'écran
    func getSlotCGRects(for imageSize: CGSize) -> [CGRect] {
        guard isValid else { return [] }

        // Convertir les valeurs normalisées en pixels
        let pixelX = firstSlotOrigin.x * imageSize.width
        let pixelY = firstSlotOrigin.y * imageSize.height
        // Size et spacing sont normalisés par la hauteur, donc on multiplie par la hauteur
        let pixelSize = slotSize * imageSize.height
        let pixelSpacing = spacing * imageSize.height

        var rects: [CGRect] = []
        for i in 0..<slotCount {
            let y = pixelY + CGFloat(i) * (pixelSize + pixelSpacing)
            let rect = CGRect(
                x: pixelX,
                y: y,
                width: pixelSize,   // Carré
                height: pixelSize
            )
            rects.append(rect)
        }
        return rects
    }

    /// Retourne les rectangles normalisés pour chaque slot (pour debug)
    func getSlotRects() -> [NormalizedRect] {
        guard isValid else { return [] }

        var rects: [NormalizedRect] = []
        for i in 0..<slotCount {
            let y = firstSlotOrigin.y + CGFloat(i) * (slotSize + spacing)
            let rect = NormalizedRect(
                x: firstSlotOrigin.x,
                y: y,
                width: slotSize,
                height: slotSize
            )
            rects.append(rect)
        }
        return rects
    }
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
