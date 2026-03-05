import SwiftUI
import AppKit

/// Fenêtre overlay transparente pour sélection de zone sur l'écran
class CalibrationOverlayWindow: NSWindow {
    var onSelectionComplete: ((CGRect) -> Void)?
    var zoneType: CalibrationZoneType = .stage

    init() {
        // Obtenir l'écran principal
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)

        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver  // Au-dessus de tout
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.hasShadow = false

        // Vue de sélection
        let selectionView = CalibrationSelectionView(window: self)
        self.contentView = selectionView
    }

    func startSelection(for zone: CalibrationZoneType, completion: @escaping (CGRect) -> Void) {
        self.zoneType = zone
        self.onSelectionComplete = completion

        // Mettre à jour la vue avec le type de zone
        if let selectionView = self.contentView as? CalibrationSelectionView {
            selectionView.zoneType = zone
            selectionView.needsDisplay = true
        }

        self.makeKeyAndOrderFront(nil)

        // Capturer la souris
        NSCursor.crosshair.set()
    }

    func completeSelection(rect: CGRect) {
        self.orderOut(nil)
        NSCursor.arrow.set()
        onSelectionComplete?(rect)
    }

    func cancelSelection() {
        self.orderOut(nil)
        NSCursor.arrow.set()
    }
}

/// Vue NSView pour gérer le dessin et les événements souris
class CalibrationSelectionView: NSView {
    weak var overlayWindow: CalibrationOverlayWindow?
    var zoneType: CalibrationZoneType = .stage

    private var isDragging = false
    private var startPoint: CGPoint = .zero
    private var currentPoint: CGPoint = .zero

    init(window: CalibrationOverlayWindow) {
        self.overlayWindow = window
        // Utiliser bounds (origine à 0,0) pas frame (origine en coordonnées écran)
        let viewFrame = CGRect(origin: .zero, size: window.frame.size)
        super.init(frame: viewFrame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // Fond semi-transparent
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()

        // Instructions en haut
        let instructions = "Dessinez un rectangle pour la zone \(zoneType.rawValue) • Échap pour annuler"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = instructions.size(withAttributes: attributes)
        let point = CGPoint(x: (bounds.width - size.width) / 2, y: bounds.height - 50)
        instructions.draw(at: point, withAttributes: attributes)

        // Rectangle de sélection
        if isDragging {
            let rect = selectionRect

            // Zone claire (non masquée)
            NSColor.clear.setFill()
            let path = NSBezierPath(rect: rect)
            path.fill()

            // Bordure colorée selon la zone
            let color: NSColor
            switch zoneType {
            case .stage: color = .systemBlue
            case .augments: color = .systemPurple
            case .items: color = .systemOrange
            }

            color.setStroke()
            path.lineWidth = 3
            path.stroke()

            // Fond semi-transparent de la couleur
            color.withAlphaComponent(0.2).setFill()
            path.fill()

            // Afficher les dimensions
            let sizeText = "\(Int(rect.width)) × \(Int(rect.height))"
            let sizeAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .medium),
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor.black.withAlphaComponent(0.7)
            ]
            let textPoint = CGPoint(x: rect.midX - 40, y: rect.minY - 25)
            sizeText.draw(at: textPoint, withAttributes: sizeAttrs)
        }
    }

    private var selectionRect: CGRect {
        let x = min(startPoint.x, currentPoint.x)
        let y = min(startPoint.y, currentPoint.y)
        let width = abs(currentPoint.x - startPoint.x)
        let height = abs(currentPoint.y - startPoint.y)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        isDragging = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        let rect = selectionRect

        // Ignorer les sélections trop petites
        guard rect.width > 20 && rect.height > 20 else {
            needsDisplay = true
            return
        }

        // Les coordonnées NSView ont Y=0 en bas, mais on veut Y=0 en haut (comme l'écran)
        // La sélection est déjà dans le bon système car on utilise directement les coordonnées de la vue
        // qui correspond à l'écran (la fenêtre couvre tout l'écran)
        let screenRect = rect

        overlayWindow?.completeSelection(rect: screenRect)
    }

    override func keyDown(with event: NSEvent) {
        // Échap pour annuler
        if event.keyCode == 53 {
            overlayWindow?.cancelSelection()
        }
    }
}

/// Manager pour la calibration par sélection écran
@MainActor
class ScreenCalibrationManager: ObservableObject {
    static let shared = ScreenCalibrationManager()

    @Published var isSelecting = false
    @Published var currentZone: CalibrationZoneType?
    @Published var shouldShowCalibrationView = false

    private var overlayWindow: CalibrationOverlayWindow?

    private init() {}

    func startSelection(for zone: CalibrationZoneType) {
        isSelecting = true
        currentZone = zone

        // Créer la fenêtre overlay
        overlayWindow = CalibrationOverlayWindow()

        // Stocker la taille AVANT la sélection (la fenêtre sera fermée après)
        let overlaySize = overlayWindow?.frame.size ?? NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)

        overlayWindow?.startSelection(for: zone) { [weak self] viewRect in
            guard let self = self else { return }

            // Utiliser la taille de l'overlay pour la normalisation
            let screenWidth = overlaySize.width
            let screenHeight = overlaySize.height

            // Inverser Y : NSView a Y=0 en bas, image a Y=0 en haut
            let flippedY = screenHeight - viewRect.origin.y - viewRect.height

            let normalized = NormalizedRect(
                x: viewRect.origin.x / screenWidth,
                y: flippedY / screenHeight,
                width: viewRect.width / screenWidth,
                height: viewRect.height / screenHeight
            )

            // Vérifier que les valeurs sont valides (entre 0 et 1)
            guard normalized.x >= 0, normalized.x <= 1,
                  normalized.y >= 0, normalized.y <= 1,
                  normalized.width > 0, normalized.width <= 1,
                  normalized.height > 0, normalized.height <= 1 else {
                print("[Calibration] ERROR: Invalid normalized values!")
                print("[Calibration] viewRect: \(viewRect), overlaySize: \(overlaySize)")
                return
            }

            // Sauvegarder
            CalibrationStore.shared.updateZone(zone, rect: normalized)

            print("[Calibration] Zone \(zone.rawValue) OK")
            print("[Calibration] viewRect: \(viewRect), overlaySize: \(screenWidth)x\(screenHeight)")
            print("[Calibration] Normalized: x=\(String(format: "%.3f", normalized.x)), y=\(String(format: "%.3f", normalized.y)), w=\(String(format: "%.3f", normalized.width)), h=\(String(format: "%.3f", normalized.height))")

            self.isSelecting = false
            self.currentZone = nil
            self.overlayWindow = nil

            // Réafficher le popover et la fenêtre de calibration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                AppDelegate.shared?.showPopover()
                self.shouldShowCalibrationView = true
            }
        }
    }

    func cancelSelection() {
        overlayWindow?.cancelSelection()
        isSelecting = false
        currentZone = nil
        overlayWindow = nil

        // Réafficher le popover et la fenêtre de calibration même si annulé
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AppDelegate.shared?.showPopover()
            self.shouldShowCalibrationView = true
        }
    }
}
