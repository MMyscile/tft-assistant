import SwiftUI
import AppKit

struct CalibrationView: View {
    @ObservedObject private var calibrationStore = CalibrationStore.shared
    @ObservedObject private var screenCalibration = ScreenCalibrationManager.shared

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Calibration")
                    .font(.headline)
                Spacer()
                Button("Fermer") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            // Instructions
            Text("Placez la fenêtre de jeu visible, puis cliquez sur \"Définir\" pour chaque zone")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.top, 12)

            // Boutons de sélection pour chaque zone
            VStack(spacing: 16) {
                // Stage et Augments (système classique)
                ForEach([CalibrationZoneType.stage, CalibrationZoneType.augments], id: \.self) { zone in
                    HStack {
                        Circle()
                            .fill(colorForZone(zone))
                            .frame(width: 14, height: 14)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(zone.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(zone.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 160, alignment: .leading)

                        Spacer()

                        if calibrationStore.getZone(zone).isValid {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                        }

                        Button(calibrationStore.getZone(zone).isValid ? "Redéfinir" : "Définir") {
                            startSelection(for: zone)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(colorForZone(zone))
                    }
                    .padding(.horizontal)
                }

                Divider()
                    .padding(.horizontal)

                // Items (nouveau système avec 10 slots)
                HStack {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 14, height: 14)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Items (10 slots)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Calibrer les 10 emplacements d'items")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    .frame(width: 160, alignment: .leading)

                    Spacer()

                    if calibrationStore.hasItemSlots {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title3)
                    }

                    Button(calibrationStore.hasItemSlots ? "Redéfinir" : "Définir") {
                        startItemSlotsSelection()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 20)

            Divider()

            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Label("Dessinez un rectangle sur l'écran", systemImage: "rectangle.dashed")
                Label("Échap pour annuler", systemImage: "escape")
                Label("Coordonnées sauvegardées automatiquement", systemImage: "checkmark.seal")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()

            Spacer()

            Divider()

            // Status global
            if calibrationStore.calibration.isValid {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Calibration complète !")
                        .fontWeight(.medium)
                }
                .padding(.vertical, 8)
            } else {
                let count = [
                    calibrationStore.calibration.stageZone.isValid,
                    calibrationStore.calibration.augmentsZone.isValid,
                    calibrationStore.calibration.hasItemSlots
                ].filter { $0 }.count

                Text("\(count)/3 zones définies")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }

            // Actions
            HStack {
                Button("Réinitialiser tout") {
                    calibrationStore.reset()
                }
                .foregroundColor(.red)

                Spacer()

                Button("Fermer") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 420, height: 450)
    }

    // MARK: - Actions

    private func startSelection(for zone: CalibrationZoneType) {
        // Fermer temporairement
        dismiss()

        // Lancer la sélection après un court délai
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            ScreenCalibrationManager.shared.startSelection(for: zone)
        }
    }

    private func startItemSlotsSelection() {
        // Fermer temporairement
        dismiss()

        // Lancer la calibration des slots
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            ScreenCalibrationManager.shared.startItemSlotsSelection()
        }
    }

    // MARK: - Helpers

    private func colorForZone(_ zone: CalibrationZoneType) -> Color {
        switch zone {
        case .stage: return .blue
        case .augments: return .purple
        case .items: return .orange
        }
    }
}

#Preview {
    CalibrationView()
}
