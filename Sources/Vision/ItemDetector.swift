import AppKit
import Combine

/// Détecte les items dans la zone calibrée
@MainActor
class ItemDetector: ObservableObject {
    static let shared = ItemDetector()

    // MARK: - Published State

    @Published var detectedItems: [TemplateMatch] = []
    @Published var isProcessing: Bool = false
    @Published var lastProcessTime: TimeInterval = 0

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private var lastProcessDate: Date?
    private let minProcessInterval: TimeInterval = 0.5  // Max 2 fois par seconde

    private init() {
        print("[ItemDetector] Initialized with \(TemplateMatcher.shared.loadedTemplatesCount) templates")
        setupObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observer les nouvelles images capturées
        ScreenCaptureManager.shared.$lastCapturedImage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                self?.processImageIfNeeded(image)
            }
            .store(in: &cancellables)
    }

    // MARK: - Process

    private var hasItemsCalibration: Bool {
        CalibrationStore.shared.hasItemSlots || CalibrationStore.shared.calibration.itemsZone.isValid
    }

    private func processImageIfNeeded(_ fullImage: NSImage) {
        // Vérifier si calibré (nouveau système slots OU ancien système zone)
        guard hasItemsCalibration else { return }

        // Throttle
        if let lastDate = lastProcessDate,
           Date().timeIntervalSince(lastDate) < minProcessInterval {
            return
        }

        // Éviter les traitements simultanés
        guard !isProcessing else { return }

        Task {
            await processImage(fullImage)
        }
    }

    func processImage(_ fullImage: NSImage) async {
        isProcessing = true
        lastProcessDate = Date()
        let startTime = Date()

        defer {
            isProcessing = false
            lastProcessTime = Date().timeIntervalSince(startTime)
        }

        // Utiliser le nouveau système de slots si disponible
        if CalibrationStore.shared.hasItemSlots {
            await processWithSlots(fullImage)
        } else {
            await processWithZone(fullImage)
        }
    }

    // MARK: - Nouveau système: slots individuels

    private func processWithSlots(_ fullImage: NSImage) async {
        guard let cgImage = fullImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("[ItemDetector] Failed to get CGImage")
            return
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let slotRects = CalibrationStore.shared.getItemSlotRects(for: imageSize)

        print("[ItemDetector] Processing \(slotRects.count) slots (image: \(Int(imageSize.width))x\(Int(imageSize.height)))")

        var allMatches: [TemplateMatch] = []

        for (index, rect) in slotRects.enumerated() {
            // Vérifier les limites
            guard rect.width > 0 && rect.height > 0 &&
                  rect.origin.x >= 0 && rect.origin.y >= 0 &&
                  rect.maxX <= CGFloat(cgImage.width) &&
                  rect.maxY <= CGFloat(cgImage.height) else {
                print("[ItemDetector] Slot \(index) hors limites: \(rect)")
                continue
            }

            // Cropper le slot
            guard let croppedCG = cgImage.cropping(to: rect) else {
                continue
            }

            let slotImage = NSImage(cgImage: croppedCG, size: NSSize(width: croppedCG.width, height: croppedCG.height))

            // Détecter l'item dans ce slot (pHash + Histogram)
            let slotIndex = index
            let match = await Task.detached(priority: .userInitiated) {
                TemplateMatcher.shared.findBestMatch(for: slotImage, slotIndex: slotIndex, debugMode: true)
            }.value

            if let bestMatch = match {
                print("[ItemDetector] Slot \(index): \(bestMatch.itemName) (\(Int(bestMatch.confidence * 100))%)")
                allMatches.append(bestMatch)
            }
        }

        self.detectedItems = allMatches

        if allMatches.isEmpty {
            print("[ItemDetector] No items found in any slot")
        } else {
            print("[ItemDetector] Found \(allMatches.count) items total")
        }
    }

    // MARK: - Ancien système: zone rectangulaire

    private func processWithZone(_ fullImage: NSImage) async {
        let calibration = CalibrationStore.shared.calibration
        guard let itemsImage = RegionCropper.shared.crop(
            image: fullImage,
            region: calibration.itemsZone
        ) else {
            print("[ItemDetector] Failed to crop items zone")
            return
        }

        print("[ItemDetector] Processing items zone: \(itemsImage.size.width)x\(itemsImage.size.height)")

        // Exécuter le template matching sur un thread background
        let matches = await Task.detached(priority: .userInitiated) {
            TemplateMatcher.shared.findItems(in: itemsImage)
        }.value

        // Mettre à jour sur le main thread
        self.detectedItems = matches

        if matches.isEmpty {
            print("[ItemDetector] No items found (zone might be too small or no items visible)")
        } else {
            let itemNames = matches.map { "\($0.itemName) (\(Int($0.confidence * 100))%)" }
            print("[ItemDetector] Found \(matches.count) items: \(itemNames.joined(separator: ", "))")
        }
    }

    // MARK: - Manual Trigger

    func detectNow() async {
        guard let image = ScreenCaptureManager.shared.lastCapturedImage else { return }
        await processImage(image)
    }
}
