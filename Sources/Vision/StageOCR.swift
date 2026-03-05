import Vision
import AppKit
import Combine

@MainActor
class StageOCR: ObservableObject {
    static let shared = StageOCR()

    // MARK: - Published State

    @Published var currentStage: String?          // Ex: "3-2"
    @Published var stageNumber: Int?              // Ex: 3
    @Published var roundNumber: Int?              // Ex: 2
    @Published var confidence: Float = 0
    @Published var rawText: String = ""
    @Published var isProcessing: Bool = false

    // MARK: - Private

    private var lastStableStage: String?
    private var stageHistory: [String] = []
    private let historySize = 3  // Nombre de lectures pour stabiliser
    private var cancellables = Set<AnyCancellable>()

    private init() {
        print("[OCR] StageOCR initialized")
        setupObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observer les nouvelles images capturées
        ScreenCaptureManager.shared.$lastCapturedImage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] image in
                Task { @MainActor in
                    await self?.processImage(image)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Process Image

    func processImage(_ fullImage: NSImage) async {
        guard CalibrationStore.shared.isCalibrated else { return }
        guard !isProcessing else { return }

        // Cropper la zone Stage
        let calibration = CalibrationStore.shared.calibration
        guard let stageImage = RegionCropper.shared.crop(image: fullImage, region: calibration.stageZone) else {
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        // Convertir en CGImage
        guard let cgImage = stageImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("[OCR] Failed to get CGImage")
            return
        }

        // Créer la request OCR
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }

            if let error = error {
                print("[OCR] Error: \(error.localizedDescription)")
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            // Récupérer le texte avec la meilleure confiance
            var allText = ""
            var bestConfidence: Float = 0

            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    allText += candidate.string + " "
                    bestConfidence = max(bestConfidence, candidate.confidence)
                }
            }

            Task { @MainActor in
                self.rawText = allText.trimmingCharacters(in: .whitespaces)
                self.confidence = bestConfidence
                self.extractStage(from: self.rawText)
            }
        }

        // Configuration OCR
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false

        // Exécuter
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("[OCR] Handler error: \(error.localizedDescription)")
        }
    }

    // MARK: - Extract Stage

    private func extractStage(from text: String) {
        // Pattern: X-X (ex: "3-2", "4-7", "1-1")
        let pattern = #"(\d)-(\d)"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            // Pas de match - garder l'ancien stage si confiance était haute
            return
        }

        // Extraire les groupes
        guard let stageRange = Range(match.range(at: 1), in: text),
              let roundRange = Range(match.range(at: 2), in: text) else {
            return
        }

        let stageStr = String(text[stageRange])
        let roundStr = String(text[roundRange])
        let fullStage = "\(stageStr)-\(roundStr)"

        // Ajouter à l'historique pour stabilisation (debounce)
        stageHistory.append(fullStage)
        if stageHistory.count > historySize {
            stageHistory.removeFirst()
        }

        // Vérifier si le stage est stable (même valeur plusieurs fois)
        let stableStage = findStableValue(in: stageHistory)

        if let stable = stableStage {
            if stable != lastStableStage {
                // Nouveau stage détecté !
                lastStableStage = stable
                currentStage = stable
                stageNumber = Int(stageStr)
                roundNumber = Int(roundStr)
                print("[OCR] Stage detected: \(stable) (confidence: \(String(format: "%.1f%%", confidence * 100)))")
            }
        }
    }

    // MARK: - Stabilisation

    private func findStableValue(in history: [String]) -> String? {
        guard history.count >= 2 else { return history.first }

        // Compter les occurrences
        var counts: [String: Int] = [:]
        for value in history {
            counts[value, default: 0] += 1
        }

        // Retourner la valeur qui apparaît le plus (au moins 2 fois)
        if let (value, count) = counts.max(by: { $0.value < $1.value }), count >= 2 {
            return value
        }

        return nil
    }

    // MARK: - Reset

    func reset() {
        currentStage = nil
        stageNumber = nil
        roundNumber = nil
        confidence = 0
        rawText = ""
        stageHistory.removeAll()
        lastStableStage = nil
    }
}
