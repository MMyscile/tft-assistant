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

    private func processImageIfNeeded(_ fullImage: NSImage) {
        // Vérifier si calibré
        guard CalibrationStore.shared.calibration.itemsZone.isValid else { return }

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

        // Cropper la zone items
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
