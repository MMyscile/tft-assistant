import AppKit
import CoreGraphics

class RegionCropper {
    static let shared = RegionCropper()

    private init() {}

    /// Crop une région de l'image selon un rectangle normalisé
    func crop(image: NSImage, region: NormalizedRect) -> NSImage? {
        guard region.isValid else {
            print("[Cropper] Region not valid: \(region)")
            return nil
        }

        let imageSize = image.size
        let cropRect = region.toCGRect(for: imageSize)

        // Vérifier que le rect est dans les bounds (avec petite marge pour erreurs d'arrondi)
        let margin: CGFloat = 2.0
        guard cropRect.minX >= -margin,
              cropRect.minY >= -margin,
              cropRect.maxX <= imageSize.width + margin,
              cropRect.maxY <= imageSize.height + margin else {
            print("[Cropper] Crop rect out of bounds! cropRect: \(cropRect), imageSize: \(imageSize)")
            return nil
        }

        // Clamper aux bounds de l'image
        let clampedRect = CGRect(
            x: max(0, cropRect.minX),
            y: max(0, cropRect.minY),
            width: min(cropRect.width, imageSize.width - max(0, cropRect.minX)),
            height: min(cropRect.height, imageSize.height - max(0, cropRect.minY))
        )

        // Créer une nouvelle image croppée
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("[Cropper] Failed to get CGImage")
            return nil
        }

        // Le CGImage peut avoir une taille différente (pixels vs points sur Retina)
        let cgImageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scaleX = cgImageSize.width / imageSize.width
        let scaleY = cgImageSize.height / imageSize.height

        // Convertir les coordonnées et appliquer le scale
        // CGImage a l'origine en haut-gauche
        let scaledRect = CGRect(
            x: clampedRect.origin.x * scaleX,
            y: clampedRect.origin.y * scaleY,
            width: clampedRect.width * scaleX,
            height: clampedRect.height * scaleY
        )

        // Debug désactivé pour éviter le spam
        // print("[Cropper] CGImage size: \(cgImageSize), scale: \(scaleX)x\(scaleY), scaledRect: \(scaledRect)")

        guard let croppedCGImage = cgImage.cropping(to: scaledRect) else {
            print("[Cropper] Failed to crop CGImage")
            return nil
        }

        let croppedImage = NSImage(cgImage: croppedCGImage, size: clampedRect.size)
        return croppedImage
    }

    /// Crop toutes les zones calibrées
    func cropAllZones(from image: NSImage, calibration: CalibrationData) -> CroppedZones {
        CroppedZones(
            stage: crop(image: image, region: calibration.stageZone),
            augments: crop(image: image, region: calibration.augmentsZone),
            items: crop(image: image, region: calibration.itemsZone)
        )
    }
}

/// Contient les images croppées de chaque zone
struct CroppedZones {
    let stage: NSImage?
    let augments: NSImage?
    let items: NSImage?

    var hasAny: Bool {
        stage != nil || augments != nil || items != nil
    }
}
