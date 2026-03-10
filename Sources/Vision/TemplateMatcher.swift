import AppKit
import Accelerate

/// Résultat d'un match de template
struct TemplateMatch {
    let itemId: String
    let itemName: String
    let confidence: Float
    let location: CGRect
}

/// Gestionnaire de template matching avec pHash + Histogramme de couleurs
/// Approche scale-invariant : pas besoin de redimensionner les images à comparer
class TemplateMatcher {
    static let shared = TemplateMatcher()

    private var templates: [ItemTemplate] = []

    private init() {
        loadTemplates()
    }

    // MARK: - Load Templates

    private func loadTemplates() {
        let bundle = Bundle.main
        let itemsPath = bundle.resourcePath ?? ""

        let fileManager = FileManager.default
        let templatesDir = (itemsPath as NSString).appendingPathComponent("Templates/Items")
        let projectTemplatesDir = "/Users/micha/WEB/PROJECT/tft-assistant/Assets/Templates/Items"

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

                    // Pré-calculer le pHash et l'histogramme du template
                    let phash = computePHash(image: image)
                    let histogram = computeColorHistogram(image: image)

                    templates.append(ItemTemplate(
                        id: itemId,
                        name: itemName,
                        image: image,
                        path: path,
                        pHash: phash,
                        colorHistogram: histogram
                    ))
                    print("[TemplateMatcher] Loaded: \(itemName) (pHash: \(String(format: "%016llX", phash)))")
                }
            }

            print("[TemplateMatcher] Loaded \(templates.count) templates with pHash + Histogram")
        } catch {
            print("[TemplateMatcher] Error loading templates: \(error)")
        }
    }

    private func formatItemName(_ id: String) -> String {
        let name = id
            .replacingOccurrences(of: "TFT_Item_", with: "")
            .replacingOccurrences(of: "_", with: " ")

        var result = ""
        for (i, char) in name.enumerated() {
            if i > 0 && char.isUppercase {
                result += " "
            }
            result += String(char)
        }

        return result
    }

    // MARK: - pHash (Perceptual Hash)

    /// Calcule le pHash d'une image (64 bits)
    /// Algorithme: resize 32x32 → grayscale → reduce to 8x8 → compare to median → 64-bit hash
    private func computePHash(image: NSImage) -> UInt64 {
        // Utiliser CGImage directement pour éviter les problèmes de NSImage.size (points vs pixels)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("[pHash] Failed to get CGImage")
            return 0
        }

        // 1. Redimensionner à 32x32 pixels
        let size = 32
        let bytesPerPixel = 4
        let bytesPerRow = size * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: size * size * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            print("[pHash] Failed to create context")
            return 0
        }

        // Dessiner l'image redimensionnée
        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        // 2. Convertir en grayscale
        var grayscale = [Float](repeating: 0, count: size * size)
        for i in 0..<(size * size) {
            let idx = i * bytesPerPixel
            let r = Float(pixelData[idx]) / 255.0
            let g = Float(pixelData[idx + 1]) / 255.0
            let b = Float(pixelData[idx + 2]) / 255.0
            grayscale[i] = 0.299 * r + 0.587 * g + 0.114 * b
        }

        guard grayscale.count == 32 * 32 else { return 0 }

        // 2. Réduire à 8x8 en prenant la moyenne de chaque bloc 4x4
        var reduced = [Float](repeating: 0, count: 64)
        for by in 0..<8 {
            for bx in 0..<8 {
                var sum: Float = 0
                for y in 0..<4 {
                    for x in 0..<4 {
                        let px = bx * 4 + x
                        let py = by * 4 + y
                        sum += grayscale[py * 32 + px]
                    }
                }
                reduced[by * 8 + bx] = sum / 16.0
            }
        }

        // 3. Calculer la médiane
        let sorted = reduced.sorted()
        let median = sorted[32]

        // 4. Générer le hash (1 si > médiane, 0 sinon)
        var hash: UInt64 = 0
        for i in 0..<64 {
            if reduced[i] > median {
                hash |= (1 << i)
            }
        }

        return hash
    }

    /// Distance de Hamming entre deux hash (nombre de bits différents)
    private func hammingDistance(_ hash1: UInt64, _ hash2: UInt64) -> Int {
        let xor = hash1 ^ hash2
        return xor.nonzeroBitCount
    }

    /// Similarité basée sur pHash (0-1, 1 = identique)
    private func pHashSimilarity(_ hash1: UInt64, _ hash2: UInt64) -> Float {
        let distance = hammingDistance(hash1, hash2)
        return 1.0 - (Float(distance) / 64.0)
    }

    // MARK: - Color Histogram

    /// Calcule l'histogramme de couleurs (64 bins: 4x4x4 RGB)
    /// Indépendant de la taille de l'image (normalisé)
    private func computeColorHistogram(image: NSImage) -> [Float] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return [Float](repeating: 0, count: 64)
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
            return [Float](repeating: 0, count: 64)
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Construire l'histogramme 4x4x4 (64 bins)
        var histogram = [Int](repeating: 0, count: 64)
        var totalPixels = 0

        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            let r = pixelData[i]
            let g = pixelData[i + 1]
            let b = pixelData[i + 2]
            let a = pixelData[i + 3]

            // Ignorer les pixels transparents
            if a < 128 { continue }

            // Quantifier en 4 niveaux par canal (0-3)
            let rBin = Int(r) / 64
            let gBin = Int(g) / 64
            let bBin = Int(b) / 64
            let bin = rBin * 16 + gBin * 4 + bBin

            histogram[bin] += 1
            totalPixels += 1
        }

        // Normaliser (somme = 1.0)
        guard totalPixels > 0 else {
            return [Float](repeating: 0, count: 64)
        }

        return histogram.map { Float($0) / Float(totalPixels) }
    }

    /// Similarité par coefficient de Bhattacharyya (0-1, 1 = identique)
    private func histogramSimilarity(_ hist1: [Float], _ hist2: [Float]) -> Float {
        guard hist1.count == hist2.count && hist1.count == 64 else { return 0 }

        var coefficient: Float = 0
        for i in 0..<64 {
            coefficient += sqrt(hist1[i] * hist2[i])
        }

        return coefficient
    }

    // MARK: - Match Single Slot

    /// Compare un slot capturé contre tous les templates
    /// Retourne le meilleur match si au-dessus du seuil
    func findBestMatch(for slotImage: NSImage, slotIndex: Int, debugMode: Bool = false) -> TemplateMatch? {
        guard !templates.isEmpty else {
            print("[TemplateMatcher] No templates loaded")
            return nil
        }

        // Vérifier si le slot est vide (trop sombre)
        let brightness = computeAverageBrightness(image: slotImage)
        if brightness < 0.08 {
            if debugMode {
                print("[TemplateMatcher] Slot \(slotIndex): empty (brightness: \(String(format: "%.2f", brightness)))")
            }
            return nil
        }

        // Calculer pHash et histogramme du slot
        let slotPHash = computePHash(image: slotImage)
        let slotHistogram = computeColorHistogram(image: slotImage)

        // Comparer avec tous les templates
        var matches: [(template: ItemTemplate, pHashScore: Float, histScore: Float, combined: Float)] = []

        for template in templates {
            let pHashScore = pHashSimilarity(slotPHash, template.pHash)
            let histScore = histogramSimilarity(slotHistogram, template.colorHistogram)

            // Score combiné (pondération ajustable)
            let combined = pHashScore * 0.4 + histScore * 0.6

            matches.append((template, pHashScore, histScore, combined))
        }

        // Trier par score combiné décroissant
        matches.sort { $0.combined > $1.combined }

        // Debug: afficher top 3
        if debugMode {
            let top3 = matches.prefix(3)
            let debugStr = top3.map {
                "\($0.template.name): \(Int($0.combined * 100))% (pH:\(Int($0.pHashScore * 100)) h:\(Int($0.histScore * 100)))"
            }.joined(separator: ", ")
            print("[TemplateMatcher] Slot \(slotIndex) [bright:\(String(format: "%.2f", brightness))] → \(debugStr)")
        }

        // Retourner le meilleur si au-dessus du seuil
        guard let best = matches.first, best.combined > 0.50 else {
            return nil
        }

        return TemplateMatch(
            itemId: best.template.id,
            itemName: best.template.name,
            confidence: best.combined,
            location: CGRect(x: 0, y: CGFloat(slotIndex), width: slotImage.size.width, height: slotImage.size.height)
        )
    }

    // MARK: - Legacy API (pour compatibilité avec ItemDetector)

    func findItems(in image: NSImage, maxResults: Int = 10, debugSlotIndex: Int? = nil) -> [TemplateMatch] {
        let debugMode = debugSlotIndex != nil
        if let match = findBestMatch(for: image, slotIndex: debugSlotIndex ?? 0, debugMode: debugMode) {
            return [match]
        }
        return []
    }

    // MARK: - Image Helpers

    private func computeAverageBrightness(image: NSImage) -> Float {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return 0
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
            return 0
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalBrightness: Float = 0
        var pixelCount = 0

        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            let r = Float(pixelData[i]) / 255.0
            let g = Float(pixelData[i + 1]) / 255.0
            let b = Float(pixelData[i + 2]) / 255.0

            let brightness = 0.299 * r + 0.587 * g + 0.114 * b
            totalBrightness += brightness
            pixelCount += 1
        }

        return pixelCount > 0 ? totalBrightness / Float(pixelCount) : 0
    }

    private func resizeImage(_ image: NSImage, to size: CGSize) -> NSImage? {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: CGRect(origin: .zero, size: size),
                   from: CGRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }

    private func getGrayscalePixels(from image: NSImage) -> [Float]? {
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

        var grayscale = [Float](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            let idx = i * bytesPerPixel
            let r = Float(pixelData[idx]) / 255.0
            let g = Float(pixelData[idx + 1]) / 255.0
            let b = Float(pixelData[idx + 2]) / 255.0
            grayscale[i] = 0.299 * r + 0.587 * g + 0.114 * b
        }

        return grayscale
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
    let pHash: UInt64
    let colorHistogram: [Float]
}
