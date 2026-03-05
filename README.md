# TFT Assistant

Application macOS menu bar pour assister les joueurs de Teamfight Tactics via reconnaissance d'écran.

## Fonctionnalités (planifiées)

- Détection du stage/round via OCR
- Détection des augments (OCR + fallback icônes)
- Détection des items/composants (template matching)
- Item builder (affiche les recettes possibles)
- Calibration personnalisée des zones de détection

## Prérequis

- macOS 12.3+ (Monterey)
- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (pour générer le projet)

## Installation

### 1. Installer xcodegen (si nécessaire)

```bash
brew install xcodegen
```

### 2. Générer le projet Xcode

```bash
cd /Users/micha/web/tft-assistant
xcodegen
```

### 3. Ouvrir dans Xcode

```bash
open TFTAssistant.xcodeproj
```

### 4. Build & Run

- Sélectionner le scheme "TFTAssistant"
- Appuyer sur ⌘R (Run)

## Utilisation

1. L'application apparaît dans la barre de menu (icône manette)
2. Cliquer sur l'icône pour ouvrir le popover
3. (À venir) Configurer les zones de calibration
4. (À venir) Lancer TFT en plein écran

## Permissions requises

- **Screen Recording** : Nécessaire pour capturer l'écran de TFT

## Structure du projet

```
tft-assistant/
├── Sources/
│   ├── App/          # Point d'entrée et AppDelegate
│   ├── Capture/      # Capture d'écran (ScreenCaptureKit)
│   ├── Vision/       # OCR et template matching
│   ├── Data/         # Modèles et persistance
│   └── UI/           # Vues SwiftUI
├── Data/             # Fichiers JSON (recettes, augments)
└── Assets/           # Templates d'icônes
```

## Contraintes de sécurité

Cette application respecte les conditions d'utilisation de Riot Games :

- Aucune injection ou modification du client
- Aucune lecture de la mémoire du jeu
- Aucune automatisation du gameplay
- Utilise uniquement la capture d'écran standard macOS

## Développement

Voir `CLAUDE.md` pour l'état actuel du développement et la checklist de progression.

## Licence

Usage personnel uniquement.
