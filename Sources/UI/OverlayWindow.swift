import SwiftUI
import AppKit

/// Fenêtre overlay flottante et transparente pour afficher les infos en jeu
class OverlayWindow: NSWindow {

    static let shared = OverlayWindow()

    private init() {
        super.init(
            contentRect: NSRect(x: 100, y: 100, width: 280, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        setupWindow()
        loadSavedPosition()
    }

    private func setupWindow() {
        // Toujours au-dessus des autres fenêtres
        level = .floating

        // Fond transparent - IMPORTANT pour coins arrondis
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // Pas de barre de titre
        titlebarAppearsTransparent = true
        titleVisibility = .hidden

        // Reste visible même quand l'app n'est pas active
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Permet de la déplacer
        isMovableByWindowBackground = true

        // Contenu SwiftUI
        let hostingView = NSHostingView(rootView: OverlayContentView())
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 12
        hostingView.layer?.masksToBounds = true
        contentView = hostingView
    }

    // MARK: - Position persistence

    private let positionKey = "overlayWindowPosition"

    private func loadSavedPosition() {
        if let data = UserDefaults.standard.data(forKey: positionKey),
           let point = try? JSONDecoder().decode(CGPoint.self, from: data) {
            setFrameOrigin(point)
        } else {
            // Position par défaut : coin bas-droit
            if let screen = NSScreen.main {
                let x = screen.frame.maxX - frame.width - 20
                let y = screen.frame.minY + 100
                setFrameOrigin(CGPoint(x: x, y: y))
            }
        }
    }

    func savePosition() {
        if let data = try? JSONEncoder().encode(frame.origin) {
            UserDefaults.standard.set(data, forKey: positionKey)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        savePosition()
    }

    // MARK: - Show/Hide

    func toggle() {
        if isVisible {
            orderOut(nil)
        } else {
            orderFront(nil)
        }
    }

    func showOverlay() {
        orderFront(nil)
    }

    func hideOverlay() {
        orderOut(nil)
    }
}

// MARK: - Overlay Content View

struct OverlayContentView: View {
    @ObservedObject private var itemDetector = ItemDetector.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var isHovered = false
    @AppStorage("overlayIsVertical") private var isVertical = false

    // Calcul de la largeur dynamique
    private var dynamicWidth: CGFloat {
        if isVertical {
            return 80 // Largeur fixe en mode vertical
        }

        let detectedIds = itemDetector.detectedItems.map { $0.itemId }
        let craftableCount = ItemRecipeService.shared.findCraftableItems(from: detectedIds).count

        if craftableCount == 0 {
            return 120 // Largeur min pour état vide
        }

        // 48px par item (40 + 8 spacing) + 24px padding
        let itemsToShow = min(craftableCount, 10)
        let calculatedWidth = CGFloat(itemsToShow) * 48 + 24

        // Min 120, max 504 (10 items)
        return max(120, min(calculatedWidth, 504))
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Header avec drag handle
            headerView

            // Contenu principal
            if settings.captureEnabled {
                contentView
            } else {
                disabledView
            }
        }
        .frame(width: dynamicWidth)
        .animation(.easeInOut(duration: 0.2), value: dynamicWidth)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(isHovered ? 0.85 : 0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isVertical.toggle()
                }
            }) {
                Image(systemName: isVertical ? "arrow.left.and.right" : "arrow.up.and.down")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            if !isVertical {
                Spacer()
            }

            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))

            if !isVertical {
                Spacer()
            }

            Button(action: {
                OverlayWindow.shared.hideOverlay()
            }) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .padding(.horizontal, isVertical ? 10 : 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
    }

    // MARK: - Content

    private var contentView: some View {
        let detectedIds = itemDetector.detectedItems.map { $0.itemId }
        let craftable = ItemRecipeService.shared.findCraftableItems(from: detectedIds)

        return Group {
            if isVertical {
                // Mode vertical
                verticalContent(craftable: craftable)
            } else {
                // Mode horizontal
                horizontalContent(craftable: craftable)
            }
        }
        .padding(8)
    }

    private func horizontalContent(craftable: [ItemRecipeService.CraftableItem]) -> some View {
        VStack(spacing: 6) {
            if craftable.isEmpty {
                emptyStateView
            } else {
                if craftable.count > 10 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(craftable, id: \.name) { item in
                                CraftableItemCell(item: item)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        ForEach(craftable, id: \.name) { item in
                            CraftableItemCell(item: item)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func verticalContent(craftable: [ItemRecipeService.CraftableItem]) -> some View {
        VStack(alignment: .center, spacing: 6) {
            if craftable.isEmpty {
                emptyStateViewCompact
            } else {
                if craftable.count > 10 {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .center, spacing: 8) {
                            ForEach(craftable, id: \.name) { item in
                                CraftableItemCell(item: item)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxHeight: 480)
                } else {
                    VStack(alignment: .center, spacing: 8) {
                        ForEach(craftable, id: \.name) { item in
                            CraftableItemCell(item: item)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var emptyStateView: some View {
        VStack(spacing: 6) {
            Image(systemName: "hammer.fill")
                .font(.title3)
                .foregroundColor(.white.opacity(0.3))

            if itemDetector.detectedItems.count < 2 {
                Text("2+ composants")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            } else {
                Text("Aucun craft")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var emptyStateViewCompact: some View {
        VStack(spacing: 4) {
            Image(systemName: "hammer.fill")
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.vertical, 8)
    }

    private var disabledView: some View {
        VStack(spacing: 8) {
            Image(systemName: "eye.slash")
                .font(.title2)
                .foregroundColor(.white.opacity(0.4))
            Text("Capture désactivée")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    // MARK: - Helpers

    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence > 0.85 {
            return .green
        } else if confidence > 0.7 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Craftable Item Cell

struct CraftableItemCell: View {
    let item: ItemRecipeService.CraftableItem
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 2) {
            if let image = TemplateMatcher.shared.templateImage(for: item.templateId) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.yellow.opacity(isHovered ? 1.0 : 0.3), lineWidth: isHovered ? 2 : 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.orange.opacity(0.5))
                    .frame(width: 40, height: 40)
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .popover(isPresented: $isHovered, arrowEdge: .bottom) {
            componentsPopover
        }
        .help(item.name)
    }

    private var componentsPopover: some View {
        HStack(spacing: 6) {
            ForEach(item.componentTemplateIds, id: \.self) { compId in
                if let image = TemplateMatcher.shared.templateImage(for: compId) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 28, height: 28)
                        .cornerRadius(4)
                }
            }
        }
        .padding(8)
    }
}

// MARK: - Preview

#Preview {
    OverlayContentView()
        .frame(width: 280, height: 400)
        .background(Color.gray)
}
