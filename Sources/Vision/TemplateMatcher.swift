import AppKit
import CoreImage
import Accelerate

/// Résultat d'un match de template
struct TemplateMatch {
    let itemId: String
    let itemName: String
    let confidence: Float
    let location: CGRect  // Position dans l'image source
}

/// Gestionnaire de template matching pour les items TFT
class TemplateMatcher {
    static let shared = TemplateMatcher()

    private var templates: [ItemTemplate] = []
    private let context = CIContext()

    private init() {
        loadTemplates()
    }

    // MARK: - Load Templates

    private func loadTemplates() {
        let bundle = Bundle.main
        let itemsPath = bundle.resourcePath ?? ""

        // Chercher les templates dans le bundle
        let fileManager = FileManager.default
        let templatesDir = (itemsPath as NSString).appendingPathComponent("Templates/Items")

        // Fallback: chercher dans le dossier Assets du projet
        let projectTemplatesDir = "/Users/micha/web/tft-assistant/Assets/Templates/Items"

        let searchDir = fileManager.fileExists(atPath: templatesDir) ? templatesDir : projectTemplatesDir

        guard fileManager.fileExists(atPath: searchDir) else {
            print("[TemplateMatcher] Templates directory not found: \(searchDir)")
            return
        }

        do {
            let files = try fileManager.contentsOfDirectory(atPath: searchDir)
            let pngFiles = files.filter { $0.hasSuffix(".png") }

            for file in pngFiles {
                let path = (searchDir as NSString).appendingPathComponent(file)
                if let image = NSImage(contentsOfFile: path) {
                    let itemId = (file as NSString).deletingPathExtension
                    let itemName = formatItemName(itemId)

                    templates.append(ItemTemplate(
                        id: itemId,
                        name: itemName,
                        image: image,
                        path: path
                    ))
                    print("[TemplateMatcher] Loaded template: \(itemName)")
                }
            }

            print("[TemplateMatcher] Loaded \(templates.count) templates")
        } catch {
            print("[TemplateMatcher] Error loading templates: \(error)")
        }
    }

    private func formatItemName(_ id: String) -> String {
        // TFT_Item_BFSword -> BF Sword
        let name = id
            .replacingOccurrences(of: "TFT_Item_", with: "")
            .replacingOccurrences(of: "_", with: " ")

        // Ajouter des espaces avant les majuscules (CamelCase -> Camel Case)
        var result = ""
        for (i, char) in name.enumerated() {
            if i > 0 && char.isUppercase {
                result += " "
            }
            result += String(char)
        }

        return result
    }

    // MARK: - Match Templates

    /// Trouve les items dans l'image de la zone items
    func findItems(in image: NSImage, maxResults: Int = 10) -> [TemplateMatch] {
        guard !templates.isEmpty else {
            print("[TemplateMatcher] No templates loaded")
            return []
        }

        var matches: [TemplateMatch] = []

        // Convertir l'image source en données pour comparaison
        guard let sourceData = getImageData(from: image) else {
            print("[TemplateMatcher] Failed to get source image data")
            return []
        }

        for template in templates {
            // Essayer plusieurs échelles pour gérer les variations de taille
            // Les items en jeu font ~15-25px, les templates font 128px
            // Sur Retina, l'échelle effective est doublée (128 * scale * 2)
            // Pour des items de 20px: scale = 20 / 256 ≈ 0.08
            let scales: [CGFloat] = [0.06, 0.08, 0.10, 0.12, 0.15]

            var bestMatch: Float = 0
            var bestLocation: CGRect = .zero

            for scale in scales {
                if let result = matchTemplate(sourceData: sourceData, template: template, scale: scale) {
                    if result.confidence > bestMatch {
                        bestMatch = result.confidence
                        bestLocation = result.location
                    }
                }
            }

            // Seuil de confiance minimum - plus élevé pour éviter les faux positifs
            if bestMatch > 0.85 {
                matches.append(TemplateMatch(
                    itemId: template.id,
                    itemName: template.name,
                    confidence: bestMatch,
                    location: bestLocation
                ))
            }
        }

        // Trier par confiance décroissante
        matches.sort { $0.confidence > $1.confidence }

        // Limiter le nombre de résultats
        return Array(matches.prefix(maxResults))
    }

    // MARK: - Template Matching Algorithm

    private func matchTemplate(sourceData: ImageData, template: ItemTemplate, scale: CGFloat) -> (confidence: Float, location: CGRect)? {
        // Redimensionner le template selon l'échelle
        let scaledSize = CGSize(
            width: template.image.size.width * scale,
            height: template.image.size.height * scale
        )

        guard let scaledTemplate = resizeImage(template.image, to: scaledSize),
              let templateData = getImageData(from: scaledTemplate) else {
            return nil
        }

        // Le template doit être plus petit que la source
        guard templateData.width < sourceData.width && templateData.height < sourceData.height else {
            return nil
        }

        // Recherche par sliding window (simplifié)
        var bestScore: Float = 0
        var bestX = 0
        var bestY = 0

        let stepSize = max(1, Int(scale * 4))  // Pas de recherche

        for y in stride(from: 0, to: sourceData.height - templateData.height, by: stepSize) {
            for x in stride(from: 0, to: sourceData.width - templateData.width, by: stepSize) {
                let score = compareRegion(
                    source: sourceData,
                    template: templateData,
                    offsetX: x,
                    offsetY: y
                )

                if score > bestScore {
                    bestScore = score
                    bestX = x
                    bestY = y
                }
            }
        }

        let location = CGRect(
            x: CGFloat(bestX),
            y: CGFloat(bestY),
            width: scaledSize.width,
            height: scaledSize.height
        )

        return (bestScore, location)
    }

    /// Compare une région de l'image source avec le template
    private func compareRegion(source: ImageData, template: ImageData, offsetX: Int, offsetY: Int) -> Float {
        var totalDiff: Float = 0
        var pixelCount: Float = 0

        // Échantillonner pour la performance (pas tous les pixels)
        let sampleStep = 2

        for ty in stride(from: 0, to: template.height, by: sampleStep) {
            for tx in stride(from: 0, to: template.width, by: sampleStep) {
                let sx = offsetX + tx
                let sy = offsetY + ty

                let sourcePixel = source.getPixel(x: sx, y: sy)
                let templatePixel = template.getPixel(x: tx, y: ty)

                // Ignorer les pixels transparents du template
                if templatePixel.a < 128 { continue }

                // Différence de couleur normalisée
                let diff = colorDifference(sourcePixel, templatePixel)
                totalDiff += diff
                pixelCount += 1
            }
        }

        guard pixelCount > 0 else { return 0 }

        // Convertir la différence en score de similarité (0-1)
        let avgDiff = totalDiff / pixelCount
        let similarity = max(0, 1 - avgDiff)

        return similarity
    }

    private func colorDifference(_ a: PixelData, _ b: PixelData) -> Float {
        let dr = Float(a.r) - Float(b.r)
        let dg = Float(a.g) - Float(b.g)
        let db = Float(a.b) - Float(b.b)

        // Distance euclidienne normalisée
        let dist = sqrt(dr*dr + dg*dg + db*db)
        return dist / 441.67  // max distance = sqrt(255^2 * 3)
    }

    // MARK: - Image Helpers

    private func getImageData(from image: NSImage) -> ImageData? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return ImageData(pixels: pixelData, width: width, height: height)
    }

    private func resizeImage(_ image: NSImage, to size: CGSize) -> NSImage? {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: size),
                   from: CGRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    // MARK: - Accessors

    var loadedTemplatesCount: Int { templates.count }
    var templateNames: [String] { templates.map { $0.name } }
}

// MARK: - Supporting Types

struct ItemTemplate {
    let id: String
    let name: String
    let image: NSImage
    let path: String
}

struct ImageData {
    let pixels: [UInt8]
    let width: Int
    let height: Int

    func getPixel(x: Int, y: Int) -> PixelData {
        let index = (y * width + x) * 4
        guard index >= 0 && index + 3 < pixels.count else {
            return PixelData(r: 0, g: 0, b: 0, a: 0)
        }
        return PixelData(
            r: pixels[index],
            g: pixels[index + 1],
            b: pixels[index + 2],
            a: pixels[index + 3]
        )
    }
}

struct PixelData {
    let r: UInt8
    let g: UInt8
    let b: UInt8
    let a: UInt8
}
