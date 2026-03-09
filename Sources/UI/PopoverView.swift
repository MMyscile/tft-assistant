import SwiftUI

struct PopoverView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @StateObject private var captureManager = ScreenCaptureManager.shared

    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "gamecontroller.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("TFT Assistant")
                    .font(.headline)
                Spacer()
                Text("⌥T")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(4)
            }
            .padding()

            Divider()

            // Tabs
            Picker("", selection: $selectedTab) {
                Text("Status").tag(0)
                Text("Round").tag(1)
                Text("Items").tag(2)
                Text("Capture").tag(3)
                Text("Settings").tag(4)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            // Content
            Group {
                switch selectedTab {
                case 0:
                    StatusTabView()
                case 1:
                    RoundTabView()
                case 2:
                    ItemsTabView()
                case 3:
                    CaptureTabView()
                case 4:
                    SettingsTabView()
                default:
                    StatusTabView()
                }
            }
            .frame(maxHeight: .infinity)

            Divider()

            // Footer
            HStack {
                Text("v0.1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Quitter") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            .padding()
        }
        .frame(width: 320, height: 420)
    }
}

// MARK: - Status Tab

struct StatusTabView: View {
    @ObservedObject private var captureManager = ScreenCaptureManager.shared
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Permission status
            HStack {
                Image(systemName: captureManager.permissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(captureManager.permissionGranted ? .green : .red)
                Text("Screen Recording")
                Spacer()
                if !captureManager.permissionChecked {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text(captureManager.permissionGranted ? "OK" : "Refusé")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !captureManager.permissionGranted && captureManager.permissionChecked {
                HStack {
                    Button("Demander accès") {
                        captureManager.requestPermission()
                    }
                    .font(.caption)

                    Button("Préférences") {
                        captureManager.openSystemPreferences()
                    }
                    .font(.caption)
                }
            }

            Divider()

            // Capture status
            HStack {
                Circle()
                    .fill(captureManager.isCapturing ? Color.green : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                Text("Capture")
                Spacer()
                if captureManager.isCapturing {
                    Text("EN COURS")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                } else {
                    Text("Arrêtée")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // FPS réel
            HStack {
                Image(systemName: "speedometer")
                Text("FPS")
                Spacer()
                if captureManager.isCapturing {
                    Text("\(Int(captureManager.actualFPS)) / \(settings.captureFPS)")
                        .font(.caption)
                        .foregroundColor(captureManager.actualFPS >= Double(settings.captureFPS) * 0.8 ? .green : .orange)
                } else {
                    Text("\(settings.captureFPS) (cible)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Frame count
            if captureManager.isCapturing {
                HStack {
                    Image(systemName: "photo.stack")
                    Text("Frames")
                    Spacer()
                    Text("\(captureManager.frameCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Toggle capture
            Toggle(isOn: $settings.captureEnabled) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Activer la capture")
                }
            }
            .disabled(!captureManager.permissionGranted)

            Spacer()
        }
        .padding()
        .task {
            if !captureManager.permissionChecked {
                await captureManager.checkPermission()
            }
        }
    }
}

// MARK: - Capture Tab

struct CaptureTabView: View {
    @ObservedObject private var captureManager = ScreenCaptureManager.shared
    @ObservedObject private var calibrationStore = CalibrationStore.shared
    @State private var croppedZones: CroppedZones?
    @State private var showFullPreview = false

    var body: some View {
        VStack(spacing: 8) {
            if calibrationStore.isCalibrated {
                // Afficher les crops des zones calibrées
                Text("Zones détectées")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    // Stage
                    ZoneCropView(
                        title: "Stage",
                        image: croppedZones?.stage,
                        color: .blue
                    )

                    // Augments
                    ZoneCropView(
                        title: "Augments",
                        image: croppedZones?.augments,
                        color: .purple
                    )

                    // Items
                    ZoneCropView(
                        title: "Items",
                        image: croppedZones?.items,
                        color: .orange
                    )
                }
                .frame(height: 80)

            } else {
                // Pas calibré - montrer l'image complète
                if let image = captureManager.lastCapturedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 120)
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 120)
                        .overlay(
                            Text("Aucune capture")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        )
                }

                Text("Calibration requise")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            // Error
            if let error = captureManager.captureError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
            }

            Spacer()

            // Toggle preview complet
            if calibrationStore.isCalibrated {
                Button(action: { showFullPreview.toggle() }) {
                    HStack {
                        Image(systemName: showFullPreview ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                        Text(showFullPreview ? "Masquer aperçu" : "Aperçu complet")
                    }
                    .font(.caption)
                }

                if showFullPreview, let image = captureManager.lastCapturedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 100)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
            }
        }
        .padding()
        .onChange(of: captureManager.lastCapturedImage) { newImage in
            updateCrops(from: newImage)
        }
        .task {
            if !captureManager.permissionChecked {
                await captureManager.checkPermission()
            }
            // Mettre à jour les crops si on a déjà une image
            updateCrops(from: captureManager.lastCapturedImage)
        }
    }

    private func updateCrops(from image: NSImage?) {
        guard let image = image, calibrationStore.isCalibrated else {
            croppedZones = nil
            return
        }
        croppedZones = RegionCropper.shared.cropAllZones(
            from: image,
            calibration: calibrationStore.calibration
        )
    }
}

// MARK: - Zone Crop View

struct ZoneCropView: View {
    let title: String
    let image: NSImage?
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: 50)
                    .background(Color.black)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(color, lineWidth: 2)
                    )
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 50)
                    .overlay(
                        Image(systemName: "questionmark")
                            .foregroundColor(.secondary)
                    )
            }

            Text(title)
                .font(.caption2)
                .foregroundColor(color)
        }
    }
}

// MARK: - Settings Tab

struct SettingsTabView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @ObservedObject private var calibrationStore = CalibrationStore.shared
    @ObservedObject private var screenCalibration = ScreenCalibrationManager.shared
    @State private var showingCalibration = false

    var body: some View {
        VStack(spacing: 12) {
            // Calibration
            HStack {
                VStack(alignment: .leading) {
                    Text("Calibration")
                        .font(.subheadline)
                    Text(calibrationStore.isCalibrated ? "Configurée" : "Non configurée")
                        .font(.caption)
                        .foregroundColor(calibrationStore.isCalibrated ? .green : .orange)
                }
                Spacer()
                Button("Configurer") {
                    showingCalibration = true
                }
            }
            .onChange(of: screenCalibration.shouldShowCalibrationView) { shouldShow in
                if shouldShow {
                    showingCalibration = true
                    screenCalibration.shouldShowCalibrationView = false
                }
            }

            Divider()

            // Toggle Capture
            Toggle(isOn: $settings.captureEnabled) {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("Capture active")
                }
            }

            // Toggle Debug
            Toggle(isOn: $settings.debugMode) {
                HStack {
                    Image(systemName: "ladybug.fill")
                    Text("Mode debug")
                }
            }

            Divider()

            // FPS Picker
            HStack {
                Text("FPS")
                Spacer()
                Picker("", selection: $settings.captureFPS) {
                    Text("1").tag(1)
                    Text("5").tag(5)
                    Text("10").tag(10)
                    Text("15").tag(15)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            Spacer()

            // Debug info
            if settings.debugMode {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Debug Info")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Capture: \(settings.captureEnabled ? "ON" : "OFF")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("FPS: \(settings.captureFPS)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Calibré: \(calibrationStore.isCalibrated ? "Oui" : "Non")")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.black.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .sheet(isPresented: $showingCalibration) {
            CalibrationView()
        }
    }
}

// MARK: - Items Tab

struct ItemsTabView: View {
    @ObservedObject private var itemDetector = ItemDetector.shared
    @ObservedObject private var calibrationStore = CalibrationStore.shared
    @ObservedObject private var captureManager = ScreenCaptureManager.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var debugMessage: String?

    private var isItemsCalibrated: Bool {
        calibrationStore.hasItemSlots || calibrationStore.calibration.itemsZone.isValid
    }

    var body: some View {
        VStack(spacing: 12) {
            if !isItemsCalibrated {
                // Zone items pas calibrée
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Calibration requise")
                        .font(.headline)
                    Text("Configure les slots Items dans Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if !settings.captureEnabled {
                // Capture inactive
                VStack(spacing: 8) {
                    Image(systemName: "pause.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Capture inactive")
                        .font(.headline)
                    Button("Activer") {
                        settings.captureEnabled = true
                    }
                }
            } else {
                // Header
                HStack {
                    Text("Composants détectés")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if itemDetector.isProcessing {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }

                if itemDetector.detectedItems.isEmpty {
                    // Aucun item détecté
                    VStack(spacing: 8) {
                        Image(systemName: "square.dashed")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Aucun item détecté")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Templates: \(TemplateMatcher.shared.loadedTemplatesCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    // Liste des items détectés
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(itemDetector.detectedItems, id: \.itemId) { match in
                                ItemMatchRow(match: match)
                            }
                        }
                    }
                }

                Spacer()

                // Debug info
                if settings.debugMode {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Debug Items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Templates: \(TemplateMatcher.shared.loadedTemplatesCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Process time: \(String(format: "%.0fms", itemDetector.lastProcessTime * 1000))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("Slots calibrés: \(calibrationStore.hasItemSlots ? "Oui" : "Non")")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        // Bouton capture debug
                        Button(action: captureDebugSlots) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Capturer slots → Bureau")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)

                        if let message = debugMessage {
                            Text(message)
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .padding()
    }

    // MARK: - Debug Capture

    private func captureDebugSlots() {
        guard let image = captureManager.lastCapturedImage else {
            debugMessage = "Pas d'image capturée"
            return
        }

        guard calibrationStore.hasItemSlots else {
            debugMessage = "Slots non calibrés"
            return
        }

        // Créer le dossier de debug
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let debugFolder = desktopURL.appendingPathComponent("TFT_Debug", isDirectory: true)
        try? FileManager.default.createDirectory(at: debugFolder, withIntermediateDirectories: true)

        // Obtenir la taille réelle de l'image (en pixels, pas en points)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            debugMessage = "Erreur: impossible d'obtenir CGImage"
            return
        }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let slotRects = calibrationStore.getItemSlotRects(for: imageSize)

        // Debug détaillé
        let config = calibrationStore.calibration.itemSlots
        print("[Debug] ==================")
        print("[Debug] Image size: \(imageSize)")
        print("[Debug] Slot config: size=\(config.slotSize), spacing=\(config.spacing)")
        print("[Debug] Expected slot size: \(config.slotSize * imageSize.height)px")
        print("[Debug] Slot rects count: \(slotRects.count)")

        var savedCount = 0
        let timestamp = Int(Date().timeIntervalSince1970)

        for (index, rect) in slotRects.enumerated() {
            print("[Debug] Slot \(index): \(rect)")

            // Vérifier que le rect est valide
            guard rect.width > 0 && rect.height > 0 &&
                  rect.origin.x >= 0 && rect.origin.y >= 0 &&
                  rect.maxX <= CGFloat(cgImage.width) &&
                  rect.maxY <= CGFloat(cgImage.height) else {
                print("[Debug] Slot \(index) hors limites!")
                continue
            }

            // Cropper le slot
            if let croppedCG = cgImage.cropping(to: rect) {
                let slotImage = NSImage(cgImage: croppedCG, size: NSSize(width: croppedCG.width, height: croppedCG.height))

                // Sauvegarder en PNG
                let filename = "slot_\(index)_\(timestamp).png"
                let fileURL = debugFolder.appendingPathComponent(filename)

                if let tiffData = slotImage.tiffRepresentation,
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    try? pngData.write(to: fileURL)
                    savedCount += 1
                }
            }
        }

        debugMessage = "\(savedCount) slots → ~/Desktop/TFT_Debug/"
        print("[Debug] Saved \(savedCount) slot images to \(debugFolder.path)")
    }
}

// MARK: - Item Match Row

struct ItemMatchRow: View {
    let match: TemplateMatch

    var body: some View {
        HStack(spacing: 12) {
            // Icône de l'item (si disponible)
            Image(systemName: "square.fill")
                .font(.title2)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(match.itemName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(match.itemId)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Confiance
            Text("\(Int(match.confidence * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(confidenceColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(confidenceColor.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }

    private var confidenceColor: Color {
        if match.confidence > 0.85 {
            return .green
        } else if match.confidence > 0.7 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Round Tab

struct RoundTabView: View {
    @ObservedObject private var stageOCR = StageOCR.shared
    @ObservedObject private var calibrationStore = CalibrationStore.shared
    @ObservedObject private var captureManager = ScreenCaptureManager.shared
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        VStack(spacing: 16) {
            if !calibrationStore.isCalibrated {
                // Pas calibré
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Calibration requise")
                        .font(.headline)
                    Text("Configure la zone Stage dans Settings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if !settings.captureEnabled {
                // Capture inactive
                VStack(spacing: 8) {
                    Image(systemName: "pause.circle")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("Capture inactive")
                        .font(.headline)
                    Button("Activer") {
                        settings.captureEnabled = true
                    }
                }
            } else {
                // Afficher le stage
                VStack(spacing: 8) {
                    Text("Stage actuel")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let stage = stageOCR.currentStage {
                        Text(stage)
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    } else {
                        Text("--")
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    // Confiance
                    HStack {
                        Text("Confiance:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(Int(stageOCR.confidence * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(stageOCR.confidence > 0.8 ? .green : (stageOCR.confidence > 0.5 ? .orange : .red))
                    }

                    if stageOCR.isProcessing {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                Spacer()

                // Debug info
                if settings.debugMode {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Debug OCR")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Raw: \(stageOCR.rawText.isEmpty ? "-" : stageOCR.rawText)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        Text("Stage: \(stageOCR.stageNumber ?? 0), Round: \(stageOCR.roundNumber ?? 0)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .padding()
    }
}

#Preview {
    PopoverView()
}
