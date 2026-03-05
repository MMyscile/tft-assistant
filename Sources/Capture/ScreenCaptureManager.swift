import ScreenCaptureKit
import AppKit
import Combine
import CoreMedia

@MainActor
class ScreenCaptureManager: NSObject, ObservableObject {
    static let shared = ScreenCaptureManager()

    // MARK: - Published State

    @Published var permissionGranted: Bool = false
    @Published var permissionChecked: Bool = false
    @Published var lastCapturedImage: NSImage?
    @Published var captureError: String?
    @Published var isCapturing: Bool = false
    @Published var frameCount: Int = 0
    @Published var actualFPS: Double = 0

    // Dimensions de l'écran capturé (pour calibration)
    @Published var captureWidth: Int = 0
    @Published var captureHeight: Int = 0

    // MARK: - Private

    private var stream: SCStream?
    private var streamOutput: ContinuousCaptureOutput?
    private var fpsTimer: Timer?
    private var frameCountForFPS: Int = 0
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        print("[Capture] ScreenCaptureManager initialized")
        // Vérifier la permission en arrière-plan sans bloquer
        Task {
            await checkPermission()
            setupSettingsObserver()
        }
    }

    // MARK: - Settings Observer

    private func setupSettingsObserver() {
        // Observer le toggle "Capture active" dans les settings
        SettingsManager.shared.$captureEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                Task { @MainActor in
                    if enabled {
                        await self?.startContinuousCapture()
                    } else {
                        await self?.stopContinuousCapture()
                    }
                }
            }
            .store(in: &cancellables)

        // Observer le changement de FPS
        SettingsManager.shared.$captureFPS
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.isCapturing else { return }
                // Redémarrer la capture avec le nouveau FPS
                Task { @MainActor in
                    await self.stopContinuousCapture()
                    await self.startContinuousCapture()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Permission Check

    private let permissionRequestedKey = "screenCapturePermissionRequested"

    func checkPermission() async {
        print("[Capture] Checking screen recording permission...")

        // Vérifier si déjà accordée (sans popup)
        let hasAccess = CGPreflightScreenCaptureAccess()

        if hasAccess {
            print("[Capture] Permission already granted")
            permissionGranted = true
            permissionChecked = true
            return
        }

        // Pas encore accordée - a-t-on déjà demandé ?
        let alreadyRequested = UserDefaults.standard.bool(forKey: permissionRequestedKey)

        if !alreadyRequested {
            // Première fois → demander
            print("[Capture] First time - requesting permission...")
            UserDefaults.standard.set(true, forKey: permissionRequestedKey)

            let granted = CGRequestScreenCaptureAccess()
            permissionGranted = granted
            print("[Capture] Permission \(granted ? "granted" : "denied")")
        } else {
            // Déjà demandé mais pas accordé → ne pas redemander
            print("[Capture] Permission was already requested but not granted")
            permissionGranted = false
        }

        permissionChecked = true
    }

    /// Redemande la permission (si l'utilisateur veut réessayer)
    func requestPermission() {
        print("[Capture] User requested permission again...")
        let granted = CGRequestScreenCaptureAccess()
        permissionGranted = granted

        if !granted {
            // Si toujours pas accordé, ouvrir les préférences
            openSystemPreferences()
        }
    }

    // MARK: - Continuous Capture

    func startContinuousCapture() async {
        guard permissionGranted else {
            print("[Capture] Cannot start - permission not granted")
            captureError = "Permission non accordée"
            SettingsManager.shared.captureEnabled = false
            return
        }

        guard !isCapturing else {
            print("[Capture] Already capturing")
            return
        }

        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first else {
                print("[Capture] No display available")
                captureError = "Aucun écran trouvé"
                return
            }

            let fps = SettingsManager.shared.captureFPS

            // Stocker les dimensions pour la calibration
            // On utilise la taille en points (comme NSScreen) pour cohérence
            let screenScale = NSScreen.main?.backingScaleFactor ?? 2.0
            let captureW = Int(Double(display.width) / screenScale)
            let captureH = Int(Double(display.height) / screenScale)
            self.captureWidth = captureW
            self.captureHeight = captureH

            print("[Capture] Starting continuous capture at \(fps) fps on display: \(display.width)x\(display.height) (scaled: \(captureW)x\(captureH))")

            // Configuration - capturer en résolution réduite (points, pas pixels)
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = captureW
            config.height = captureH
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = false
            config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
            config.queueDepth = 3

            // Output
            let output = ContinuousCaptureOutput { [weak self] image in
                Task { @MainActor in
                    self?.lastCapturedImage = image
                    self?.frameCount += 1
                    self?.frameCountForFPS += 1
                }
            }
            self.streamOutput = output

            // Stream
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            self.stream = stream

            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
            try await stream.startCapture()

            isCapturing = true
            captureError = nil
            startFPSCounter()

            print("[Capture] Continuous capture started")

        } catch {
            print("[Capture] Failed to start capture: \(error.localizedDescription)")
            captureError = "Erreur: \(error.localizedDescription)"
            SettingsManager.shared.captureEnabled = false
        }
    }

    func stopContinuousCapture() async {
        guard isCapturing, let stream = stream else { return }

        do {
            try await stream.stopCapture()
            print("[Capture] Continuous capture stopped")
        } catch {
            print("[Capture] Error stopping capture: \(error)")
        }

        self.stream = nil
        self.streamOutput = nil
        isCapturing = false
        stopFPSCounter()
    }

    // MARK: - FPS Counter

    private func startFPSCounter() {
        frameCountForFPS = 0
        fpsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.actualFPS = Double(self.frameCountForFPS)
                self.frameCountForFPS = 0
            }
        }
    }

    private func stopFPSCounter() {
        fpsTimer?.invalidate()
        fpsTimer = nil
        actualFPS = 0
    }

    // MARK: - Single Frame (pour tests)

    func captureFrame() async {
        guard permissionGranted else {
            captureError = "Permission non accordée"
            return
        }

        // Si capture continue active, on a déjà des frames
        if isCapturing {
            print("[Capture] Using frame from continuous capture")
            return
        }

        // Sinon, démarrer temporairement
        await startContinuousCapture()
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        await stopContinuousCapture()
    }

    // MARK: - Open System Preferences

    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Continuous Capture Output

class ContinuousCaptureOutput: NSObject, SCStreamOutput {
    private let onFrame: (NSImage) -> Void
    private let context = CIContext()

    init(onFrame: @escaping (NSImage) -> Void) {
        self.onFrame = onFrame
        super.init()
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        onFrame(nsImage)
    }
}
