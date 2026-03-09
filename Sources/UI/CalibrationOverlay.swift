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

    // Nécessaire pour recevoir les événements clavier
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func startSelection(for zone: CalibrationZoneType, completion: @escaping (CGRect) -> Void) {
        self.zoneType = zone
        self.onSelectionComplete = completion

        // Mettre à jour la vue avec le type de zone
        if let selectionView = self.contentView as? CalibrationSelectionView {
            selectionView.zoneType = zone
            selectionView.needsDisplay = true
        }

        // Forcer l'activation de l'application
        NSApp.activate(ignoringOtherApps: true)

        self.makeKeyAndOrderFront(nil)
        self.orderFrontRegardless()

        // S'assurer que la vue a le focus clavier
        if let selectionView = self.contentView as? CalibrationSelectionView {
            self.makeFirstResponder(selectionView)
        }

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
    var zoneType: CalibrationZoneType = .stage {
        didSet {
            loadExistingZone()
        }
    }

    // Mode: édition d'une zone existante ou création d'une nouvelle
    private var hasExistingZone = false
    private var existingRect: CGRect = .zero

    // Interaction
    private var isDragging = false
    private var isDrawingNew = false
    private var startPoint: CGPoint = .zero
    private var currentPoint: CGPoint = .zero

    // Type de drag sur zone existante
    private var dragMode: DragMode = .none
    private var dragStartRect: CGRect = .zero

    enum DragMode {
        case none
        case move
        case resizeTopLeft, resizeTopRight, resizeBottomLeft, resizeBottomRight
        case resizeTop, resizeBottom, resizeLeft, resizeRight
    }

    private let handleSize: CGFloat = 12

    init(window: CalibrationOverlayWindow) {
        self.overlayWindow = window
        let viewFrame = CGRect(origin: .zero, size: window.frame.size)
        super.init(frame: viewFrame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Load Existing Zone

    private func loadExistingZone() {
        let calibration = CalibrationStore.shared.calibration
        let normalizedRect: NormalizedRect

        switch zoneType {
        case .stage:
            normalizedRect = calibration.stageZone
        case .augments:
            normalizedRect = calibration.augmentsZone
        case .items:
            normalizedRect = calibration.itemsZone
        }

        guard normalizedRect.isValid else {
            hasExistingZone = false
            return
        }

        // Convertir les coordonnées normalisées en pixels (NSView)
        let screenSize = bounds.size

        // Y est inversé: normalisé Y=0 en haut, NSView Y=0 en bas
        let pixelX = normalizedRect.x * screenSize.width
        let pixelY = screenSize.height - ((normalizedRect.y + normalizedRect.height) * screenSize.height)
        let pixelW = normalizedRect.width * screenSize.width
        let pixelH = normalizedRect.height * screenSize.height

        existingRect = CGRect(x: pixelX, y: pixelY, width: pixelW, height: pixelH)
        hasExistingZone = true

        print("[Calibration] Loaded existing \(zoneType.rawValue) zone: \(existingRect)")
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        // Fond semi-transparent
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()

        // Instructions
        let instructions: String
        if hasExistingZone && !isDrawingNew {
            instructions = "Glisser=déplacer • Coins/bords=redimensionner • Clic ailleurs=redessiner • Entrée=OK • Échap=annuler"
        } else {
            instructions = "Dessinez un rectangle pour la zone \(zoneType.rawValue) • Échap pour annuler"
        }
        drawInstructions(instructions)

        // Couleur selon la zone
        let color: NSColor
        switch zoneType {
        case .stage: color = .systemBlue
        case .augments: color = .systemPurple
        case .items: color = .systemOrange
        }

        // Dessiner le rectangle (existant ou en cours de dessin)
        let rectToDraw: CGRect
        if isDrawingNew {
            rectToDraw = selectionRect
        } else if hasExistingZone {
            rectToDraw = existingRect
        } else if isDragging {
            rectToDraw = selectionRect
        } else {
            return
        }

        drawRect(rectToDraw, color: color, showHandles: hasExistingZone && !isDrawingNew)
    }

    private func drawInstructions(_ text: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        let point = CGPoint(x: (bounds.width - size.width) / 2, y: bounds.height - 50)
        text.draw(at: point, withAttributes: attributes)
    }

    private func drawRect(_ rect: CGRect, color: NSColor, showHandles: Bool) {
        let path = NSBezierPath(rect: rect)

        // Fond semi-transparent
        color.withAlphaComponent(0.2).setFill()
        path.fill()

        // Bordure
        color.setStroke()
        path.lineWidth = 3
        path.stroke()

        // Dimensions
        let sizeText = "\(Int(rect.width)) × \(Int(rect.height))"
        let sizeAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]
        let textPoint = CGPoint(x: rect.midX - 40, y: rect.minY - 25)
        sizeText.draw(at: textPoint, withAttributes: sizeAttrs)

        // Poignées de redimensionnement (coins uniquement)
        if showHandles {
            let handleColor = NSColor.white
            handleColor.setFill()

            for handle in cornerHandles(for: rect) {
                let handlePath = NSBezierPath(ovalIn: handle)
                handlePath.fill()
                color.setStroke()
                handlePath.lineWidth = 2
                handlePath.stroke()
            }
        }
    }

    private func cornerHandles(for rect: CGRect) -> [CGRect] {
        let s = handleSize
        return [
            CGRect(x: rect.minX - s/2, y: rect.minY - s/2, width: s, height: s),  // Bottom-left
            CGRect(x: rect.maxX - s/2, y: rect.minY - s/2, width: s, height: s),  // Bottom-right
            CGRect(x: rect.minX - s/2, y: rect.maxY - s/2, width: s, height: s),  // Top-left
            CGRect(x: rect.maxX - s/2, y: rect.maxY - s/2, width: s, height: s),  // Top-right
        ]
    }

    private func edgeHandles(for rect: CGRect) -> [CGRect] {
        let s = handleSize
        return [
            CGRect(x: rect.midX - s/2, y: rect.minY - s/2, width: s, height: s),  // Bottom
            CGRect(x: rect.midX - s/2, y: rect.maxY - s/2, width: s, height: s),  // Top
            CGRect(x: rect.minX - s/2, y: rect.midY - s/2, width: s, height: s),  // Left
            CGRect(x: rect.maxX - s/2, y: rect.midY - s/2, width: s, height: s),  // Right
        ]
    }

    private var selectionRect: CGRect {
        let x = min(startPoint.x, currentPoint.x)
        let y = min(startPoint.y, currentPoint.y)
        let width = abs(currentPoint.x - startPoint.x)
        let height = abs(currentPoint.y - startPoint.y)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    // MARK: - Hit Testing

    private func hitTest(point: CGPoint) -> DragMode {
        guard hasExistingZone else { return .none }

        let rect = existingRect
        let s = handleSize

        // Test coins uniquement
        if CGRect(x: rect.minX - s/2, y: rect.minY - s/2, width: s, height: s).contains(point) { return .resizeBottomLeft }
        if CGRect(x: rect.maxX - s/2, y: rect.minY - s/2, width: s, height: s).contains(point) { return .resizeBottomRight }
        if CGRect(x: rect.minX - s/2, y: rect.maxY - s/2, width: s, height: s).contains(point) { return .resizeTopLeft }
        if CGRect(x: rect.maxX - s/2, y: rect.maxY - s/2, width: s, height: s).contains(point) { return .resizeTopRight }

        // Test intérieur (déplacement)
        if rect.contains(point) { return .move }

        return .none
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        startPoint = point
        currentPoint = point

        if hasExistingZone {
            dragMode = hitTest(point: point)
            if dragMode != .none {
                // Éditer la zone existante
                dragStartRect = existingRect
                isDragging = true
            } else {
                // Clic en dehors → redessiner
                isDrawingNew = true
                isDragging = true
            }
        } else {
            // Pas de zone existante → dessiner
            isDragging = true
        }

        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        currentPoint = point

        if hasExistingZone && dragMode != .none {
            // Modifier la zone existante
            let deltaX = point.x - startPoint.x
            let deltaY = point.y - startPoint.y

            var newRect = dragStartRect

            switch dragMode {
            case .move:
                newRect.origin.x += deltaX
                newRect.origin.y += deltaY

            case .resizeBottomLeft:
                newRect.origin.x += deltaX
                newRect.size.width -= deltaX
                newRect.origin.y += deltaY
                newRect.size.height -= deltaY

            case .resizeBottomRight:
                newRect.size.width += deltaX
                newRect.origin.y += deltaY
                newRect.size.height -= deltaY

            case .resizeTopLeft:
                newRect.origin.x += deltaX
                newRect.size.width -= deltaX
                newRect.size.height += deltaY

            case .resizeTopRight:
                newRect.size.width += deltaX
                newRect.size.height += deltaY

            case .resizeBottom:
                newRect.origin.y += deltaY
                newRect.size.height -= deltaY

            case .resizeTop:
                newRect.size.height += deltaY

            case .resizeLeft:
                newRect.origin.x += deltaX
                newRect.size.width -= deltaX

            case .resizeRight:
                newRect.size.width += deltaX

            case .none:
                break
            }

            // Assurer une taille minimum
            if newRect.width >= 20 && newRect.height >= 20 {
                existingRect = newRect
            }
        }

        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false

        let rect: CGRect
        if isDrawingNew {
            rect = selectionRect
            isDrawingNew = false

            // Ignorer les sélections trop petites
            guard rect.width > 20 && rect.height > 20 else {
                needsDisplay = true
                return
            }

            // Mettre à jour la zone existante
            existingRect = rect
            hasExistingZone = true
        } else if hasExistingZone {
            // Zone modifiée, rester en mode édition
            rect = existingRect
        } else {
            rect = selectionRect
            guard rect.width > 20 && rect.height > 20 else {
                needsDisplay = true
                return
            }
            existingRect = rect
            hasExistingZone = true
        }

        dragMode = .none
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53:  // Échap
            overlayWindow?.cancelSelection()

        case 36:  // Entrée → valider
            if hasExistingZone {
                overlayWindow?.completeSelection(rect: existingRect)
            }

        default:
            break
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

    // MARK: - Item Slots Calibration

    private var itemSlotsWindow: ItemSlotsCalibrationWindow?

    func startItemSlotsSelection() {
        isSelecting = true
        currentZone = .items

        itemSlotsWindow = ItemSlotsCalibrationWindow()
        itemSlotsWindow?.startCalibration { [weak self] config in
            guard let self = self else { return }

            CalibrationStore.shared.updateItemSlots(config)

            print("[Calibration] Item slots configured: \(config.slotCount) slots")

            self.isSelecting = false
            self.currentZone = nil
            self.itemSlotsWindow = nil

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                AppDelegate.shared?.showPopover()
                self.shouldShowCalibrationView = true
            }
        }
    }

    func cancelItemSlotsSelection() {
        itemSlotsWindow?.cancelCalibration()
        isSelecting = false
        currentZone = nil
        itemSlotsWindow = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AppDelegate.shared?.showPopover()
            self.shouldShowCalibrationView = true
        }
    }
}

// MARK: - Item Slots Calibration Window

/// Fenêtre de calibration des 10 slots d'items
class ItemSlotsCalibrationWindow: NSWindow {
    var onCalibrationComplete: ((ItemSlotsConfig) -> Void)?

    init() {
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)

        super.init(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.hasShadow = false

        let calibrationView = ItemSlotsCalibrationView(window: self)
        self.contentView = calibrationView
    }

    // Nécessaire pour qu'une fenêtre borderless puisse recevoir les événements clavier
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    func startCalibration(completion: @escaping (ItemSlotsConfig) -> Void) {
        self.onCalibrationComplete = completion

        // Forcer l'activation de l'application
        NSApp.activate(ignoringOtherApps: true)

        self.makeKeyAndOrderFront(nil)
        self.orderFrontRegardless()

        // S'assurer que la vue a le focus clavier
        if let calibrationView = self.contentView as? ItemSlotsCalibrationView {
            self.makeFirstResponder(calibrationView)
        }

        NSCursor.crosshair.set()
    }

    func completeCalibration(config: ItemSlotsConfig) {
        self.orderOut(nil)
        NSCursor.arrow.set()
        onCalibrationComplete?(config)
    }

    func cancelCalibration() {
        self.orderOut(nil)
        NSCursor.arrow.set()
    }
}

/// Vue de calibration des slots
class ItemSlotsCalibrationView: NSView, NSTextFieldDelegate {
    weak var calibrationWindow: ItemSlotsCalibrationWindow?

    // Phase 1: Dessin du premier slot
    // Phase 2: Ajustement avec preview des 10 slots
    private var phase: Int = 1

    // Dessin
    private var isDragging = false
    private var startPoint: CGPoint = .zero
    private var currentPoint: CGPoint = .zero

    // Configuration des slots
    private var slotOrigin: CGPoint = .zero      // Coin supérieur gauche du premier slot (en pixels écran)
    private var slotSize: CGFloat = 30           // Taille du slot (carré)
    private var slotSpacing: CGFloat = 5         // Espacement entre slots
    private let slotCount = 10

    // Drag en phase 2
    private var dragType: DragType = .none
    private var dragStartOrigin: CGPoint = .zero
    private var dragStartSize: CGFloat = 0
    private var dragStartSpacing: CGFloat = 0

    // Panneau de saisie précise
    private var inputPanel: NSView?
    private var sizeTextField: NSTextField?
    private var spacingTextField: NSTextField?

    enum DragType {
        case none
        case move
        case resize
    }

    init(window: ItemSlotsCalibrationWindow) {
        self.calibrationWindow = window
        let viewFrame = CGRect(origin: .zero, size: window.frame.size)
        super.init(frame: viewFrame)

        // Charger la calibration existante si disponible
        loadExistingCalibration()
    }


    private func loadExistingCalibration() {
        let existingConfig = CalibrationStore.shared.calibration.itemSlots

        guard existingConfig.isValid else {
            // Pas de calibration existante → rester en phase 1
            return
        }

        // Convertir les valeurs normalisées en pixels
        let screenSize = calibrationWindow?.frame.size ?? bounds.size

        // firstSlotOrigin est normalisé par width/height
        // Mais attention: Y est inversé (normalisé Y=0 en haut, NSView Y=0 en bas)
        let normalizedX = existingConfig.firstSlotOrigin.x
        let normalizedY = existingConfig.firstSlotOrigin.y

        // Convertir en coordonnées NSView (Y inversé)
        let pixelX = normalizedX * screenSize.width
        let pixelY = screenSize.height - (normalizedY * screenSize.height)

        // Size et spacing sont normalisés par la hauteur
        let pixelSize = existingConfig.slotSize * screenSize.height
        let pixelSpacing = existingConfig.spacing * screenSize.height

        // Appliquer les valeurs
        slotOrigin = CGPoint(x: pixelX, y: pixelY)
        slotSize = pixelSize
        slotSpacing = pixelSpacing

        // Passer directement en phase 2
        phase = 2

        // Créer le panneau de saisie après un court délai pour laisser la vue se configurer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.createInputPanel()
            self.needsDisplay = true
            // Remettre le focus sur la vue principale (pas les text fields)
            self.window?.makeFirstResponder(self)
        }

        print("[ItemSlots] Loaded existing calibration:")
        print("  Origin: \(slotOrigin)")
        print("  Size: \(slotSize)px, Spacing: \(slotSpacing)px")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Input Panel (Phase 2)

    private func createInputPanel() {
        guard inputPanel == nil else { return }

        // Panneau de fond - positionné à côté du premier slot
        let panelWidth: CGFloat = 180
        let panelHeight: CGFloat = 120
        let panelX = slotOrigin.x + slotSize + 15  // À droite du premier slot
        let panelY = slotOrigin.y - panelHeight + 20  // Aligné avec le haut du premier slot

        let panel = NSView(frame: CGRect(x: panelX, y: panelY, width: panelWidth, height: panelHeight))
        panel.wantsLayer = true
        panel.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.85).cgColor
        panel.layer?.cornerRadius = 10

        // Titre
        let titleLabel = NSTextField(labelWithString: "Ajustement précis")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.frame = CGRect(x: 15, y: panelHeight - 30, width: panelWidth - 30, height: 20)
        panel.addSubview(titleLabel)

        // Label Taille
        let sizeLabel = NSTextField(labelWithString: "Taille (px):")
        sizeLabel.font = NSFont.systemFont(ofSize: 12)
        sizeLabel.textColor = .lightGray
        sizeLabel.frame = CGRect(x: 15, y: panelHeight - 60, width: 80, height: 18)
        panel.addSubview(sizeLabel)

        // TextField Taille
        let sizeField = NSTextField(frame: CGRect(x: 100, y: panelHeight - 62, width: 80, height: 22))
        sizeField.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        sizeField.stringValue = String(format: "%.1f", slotSize)
        sizeField.delegate = self
        sizeField.tag = 1  // Tag pour identifier le champ
        panel.addSubview(sizeField)
        self.sizeTextField = sizeField

        // Label Espacement
        let spacingLabel = NSTextField(labelWithString: "Espacement:")
        spacingLabel.font = NSFont.systemFont(ofSize: 12)
        spacingLabel.textColor = .lightGray
        spacingLabel.frame = CGRect(x: 15, y: panelHeight - 90, width: 80, height: 18)
        panel.addSubview(spacingLabel)

        // TextField Espacement
        let spacingField = NSTextField(frame: CGRect(x: 100, y: panelHeight - 92, width: 80, height: 22))
        spacingField.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        spacingField.stringValue = String(format: "%.1f", slotSpacing)
        spacingField.delegate = self
        spacingField.tag = 2  // Tag pour identifier le champ
        panel.addSubview(spacingField)
        self.spacingTextField = spacingField

        // Instructions
        let helpLabel = NSTextField(labelWithString: "Tab pour changer • Entrée=OK")
        helpLabel.font = NSFont.systemFont(ofSize: 10)
        helpLabel.textColor = .gray
        helpLabel.frame = CGRect(x: 15, y: 8, width: panelWidth - 30, height: 14)
        panel.addSubview(helpLabel)

        addSubview(panel)
        self.inputPanel = panel
    }

    private func updateInputFields() {
        sizeTextField?.stringValue = String(format: "%.1f", slotSize)
        spacingTextField?.stringValue = String(format: "%.1f", slotSpacing)
    }

    private func updatePanelPosition() {
        guard let panel = inputPanel else { return }
        let panelX = slotOrigin.x + slotSize + 15
        let panelY = slotOrigin.y - panel.frame.height + 20
        panel.frame.origin = CGPoint(x: panelX, y: panelY)
    }

    private func removeInputPanel() {
        inputPanel?.removeFromSuperview()
        inputPanel = nil
        sizeTextField = nil
        spacingTextField = nil
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        guard let textField = obj.object as? NSTextField else { return }

        // Parser la valeur
        let value = CGFloat(Double(textField.stringValue) ?? 0)

        if textField.tag == 1 {
            // Taille
            slotSize = max(10, value)
        } else if textField.tag == 2 {
            // Espacement
            slotSpacing = max(0, value)
        }

        needsDisplay = true
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(insertNewline(_:)) {
            // Entrée pressée dans un champ texte → valider
            validateAndComplete()
            return true
        }

        if commandSelector == #selector(cancelOperation(_:)) {
            // Échap pressée dans un champ texte → annuler
            calibrationWindow?.cancelCalibration()
            return true
        }

        // Flèches haut/bas pour incrémenter/décrémenter
        let increment: CGFloat = NSEvent.modifierFlags.contains(.shift) ? 0.1 : 0.5

        if commandSelector == #selector(moveUp(_:)) {
            // Flèche haut → augmenter la valeur
            if let textField = control as? NSTextField {
                adjustTextFieldValue(textField, by: increment)
            }
            return true
        }

        if commandSelector == #selector(moveDown(_:)) {
            // Flèche bas → diminuer la valeur
            if let textField = control as? NSTextField {
                adjustTextFieldValue(textField, by: -increment)
            }
            return true
        }

        return false
    }

    private func adjustTextFieldValue(_ textField: NSTextField, by delta: CGFloat) {
        let currentValue = CGFloat(Double(textField.stringValue) ?? 0)
        let newValue: CGFloat

        if textField.tag == 1 {
            // Taille (min 10)
            newValue = max(10, currentValue + delta)
            slotSize = newValue
        } else {
            // Espacement (min 0)
            newValue = max(0, currentValue + delta)
            slotSpacing = newValue
        }

        textField.stringValue = String(format: "%.1f", newValue)
        updatePanelPosition()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // Fond semi-transparent
        NSColor.black.withAlphaComponent(0.4).setFill()
        dirtyRect.fill()

        if phase == 1 {
            drawPhase1()
        } else {
            drawPhase2()
        }
    }

    private func drawPhase1() {
        // Instructions
        let instructions = "Dessinez UN slot (sera dupliqué 10 fois verticalement) • Échap pour annuler"
        drawInstructions(instructions)

        // Rectangle de sélection en cours
        if isDragging {
            let rect = currentSelectionRect
            drawSlotPreview(at: rect.origin, size: rect.width, count: 1, highlight: 0)

            // Afficher les dimensions
            let sizeText = "\(Int(rect.width)) × \(Int(rect.width)) px"
            drawSizeLabel(sizeText, below: rect)
        }
    }

    private func drawPhase2() {
        // Instructions
        let instructions = "Glisser=déplacer • ⌘+Glisser=taille • Clic dehors=redessiner • Entrée=OK • Échap=annuler"
        drawInstructions(instructions)

        // Dessiner les 10 slots
        drawSlotPreview(at: slotOrigin, size: slotSize, count: slotCount, highlight: -1)

        // Créer le panneau de saisie si pas encore fait
        if inputPanel == nil {
            createInputPanel()
        }
    }

    private func drawInstructions(_ text: String) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let size = text.size(withAttributes: attributes)
        let point = CGPoint(x: (bounds.width - size.width) / 2, y: bounds.height - 50)
        text.draw(at: point, withAttributes: attributes)
    }

    private func drawSlotPreview(at origin: CGPoint, size: CGFloat, count: Int, highlight: Int) {
        let color = NSColor.systemOrange

        for i in 0..<count {
            let y = origin.y - CGFloat(i) * (size + slotSpacing)  // Y décroissant (vers le bas en coordonnées NSView)
            let rect = CGRect(x: origin.x, y: y - size, width: size, height: size)

            // Fond
            if i == highlight {
                color.withAlphaComponent(0.4).setFill()
            } else {
                color.withAlphaComponent(0.2).setFill()
            }
            let path = NSBezierPath(rect: rect)
            path.fill()

            // Bordure
            color.setStroke()
            path.lineWidth = 2
            path.stroke()

            // Numéro du slot
            let numAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let numText = "\(i)"
            let numSize = numText.size(withAttributes: numAttrs)
            let numPoint = CGPoint(x: rect.midX - numSize.width/2, y: rect.midY - numSize.height/2)
            numText.draw(at: numPoint, withAttributes: numAttrs)
        }
    }

    private func drawSizeLabel(_ text: String, below rect: CGRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]
        let textPoint = CGPoint(x: rect.midX - 40, y: rect.minY - 25)
        text.draw(at: textPoint, withAttributes: attrs)
    }

    private var currentSelectionRect: CGRect {
        let x = min(startPoint.x, currentPoint.x)
        let y = min(startPoint.y, currentPoint.y)
        let width = abs(currentPoint.x - startPoint.x)
        let height = abs(currentPoint.y - startPoint.y)
        // Forcer un carré (prendre la plus petite dimension)
        let size = min(width, height)
        return CGRect(x: x, y: y, width: size, height: size)
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if phase == 1 {
            startPoint = point
            currentPoint = point
            isDragging = true
        } else {
            // Phase 2: vérifier si on clique sur un slot
            if isPointInSlots(point) {
                if event.modifierFlags.contains(.command) {
                    dragType = .resize
                    dragStartSize = slotSize
                } else {
                    dragType = .move
                    dragStartOrigin = slotOrigin
                }
                startPoint = point
            } else {
                // Clic en dehors des slots → redessiner
                removeInputPanel()
                phase = 1
                startPoint = point
                currentPoint = point
                isDragging = true
            }
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if phase == 1 {
            currentPoint = point
        } else {
            let delta = CGPoint(x: point.x - startPoint.x, y: point.y - startPoint.y)

            switch dragType {
            case .move:
                slotOrigin = CGPoint(x: dragStartOrigin.x + delta.x, y: dragStartOrigin.y + delta.y)
                updatePanelPosition()
            case .resize:
                slotSize = max(10, dragStartSize + delta.x)
                updateInputFields()
                updatePanelPosition()
            case .none:
                break
            }
        }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if phase == 1 && isDragging {
            isDragging = false
            let rect = currentSelectionRect

            // Ignorer les sélections trop petites
            guard rect.width > 10 else {
                needsDisplay = true
                return
            }

            // Passer en phase 2
            slotOrigin = CGPoint(x: rect.origin.x, y: rect.origin.y + rect.height)  // Coin supérieur gauche
            slotSize = rect.width
            slotSpacing = slotSize * 0.15  // Espacement par défaut: 15% de la taille
            phase = 2

            // S'assurer qu'on a le focus clavier pour les ajustements
            window?.makeFirstResponder(self)
        }

        dragType = .none
        needsDisplay = true
    }

    private func isPointInSlots(_ point: CGPoint) -> Bool {
        for i in 0..<slotCount {
            let y = slotOrigin.y - CGFloat(i) * (slotSize + slotSpacing)
            let rect = CGRect(x: slotOrigin.x, y: y - slotSize, width: slotSize, height: slotSize)
            if rect.contains(point) {
                return true
            }
        }
        return false
    }

    // MARK: - Keyboard Events

    override func keyDown(with event: NSEvent) {
        // Incrément: 0.1 avec Shift, 0.5 par défaut
        let increment: CGFloat = event.modifierFlags.contains(.shift) ? 0.1 : 0.5

        switch event.keyCode {
        case 53:  // Échap
            calibrationWindow?.cancelCalibration()

        case 36:  // Entrée
            if phase == 2 {
                validateAndComplete()
            }

        case 126:  // Flèche haut → réduire espacement
            if phase == 2 {
                slotSpacing = max(0, slotSpacing - increment)
                updateInputFields()
                needsDisplay = true
            }

        case 125:  // Flèche bas → augmenter espacement
            if phase == 2 {
                slotSpacing += increment
                updateInputFields()
                needsDisplay = true
            }

        case 123:  // Flèche gauche → réduire taille
            if phase == 2 {
                slotSize = max(10, slotSize - increment)
                updateInputFields()
                needsDisplay = true
            }

        case 124:  // Flèche droite → augmenter taille
            if phase == 2 {
                slotSize += increment
                updateInputFields()
                needsDisplay = true
            }

        default:
            break
        }
    }

    private func validateAndComplete() {
        let screenSize = bounds.size

        // Convertir en coordonnées normalisées (0-1)
        // Attention: NSView a Y=0 en bas, mais on veut Y=0 en haut pour l'image
        let flippedY = screenSize.height - slotOrigin.y

        // IMPORTANT: Normaliser SIZE et SPACING par la HAUTEUR de l'écran
        // car les slots sont disposés verticalement et on veut des carrés
        let config = ItemSlotsConfig(
            firstSlotOrigin: CGPoint(
                x: slotOrigin.x / screenSize.width,
                y: flippedY / screenSize.height
            ),
            slotSize: slotSize / screenSize.height,  // Normaliser par la HAUTEUR
            spacing: slotSpacing / screenSize.height,
            slotCount: slotCount
        )

        print("[ItemSlots] Configuration:")
        print("  Origin: (\(slotOrigin.x), \(slotOrigin.y)) -> normalized: (\(config.firstSlotOrigin.x), \(config.firstSlotOrigin.y))")
        print("  Size: \(slotSize)px -> normalized: \(config.slotSize)")
        print("  Spacing: \(slotSpacing)px -> normalized: \(config.spacing)")
        print("  Screen: \(screenSize)")

        calibrationWindow?.completeCalibration(config: config)
    }
}
