# TFT Menu Bar Assistant — Suivi du projet

## Description

App macOS menu bar (SwiftUI) qui assiste Teamfight Tactics via screen recognition :
- OCR du stage/round
- Détection des augments (OCR + fallback icônes)
- Matching d'icônes pour items/composants
- Calibration par rectangles

## Contraintes de sécurité (non négociables)

**Interdit** : injection, hooking, lecture mémoire, automatisation gameplay, contournement anti-cheat

**Autorisé** : capture écran (APIs macOS), OCR (Vision), template matching local, affichage UI

## Spécifications

- macOS 12.3+, Swift 5.9+, Xcode 15+
- Intel + Apple Silicon
- ScreenCaptureKit + Vision
- 5 fps (configurable)

---

## Workflow de développement

### Compilation automatique
Claude compile automatiquement après chaque modification avec `xcodebuild`.
- **✅ BUILD SUCCEEDED** → Tu peux tester dans Xcode (⌘R)
- **❌ BUILD FAILED** → Claude corrige l'erreur avant de te demander de tester

### Processus
1. Claude code et modifie les fichiers
2. Claude régénère le projet (`xcodegen`)
3. Claude compile (`xcodebuild`)
4. Si OK → Tu testes dans Xcode (⌘R)
5. Si erreur → Claude corrige et recompile

### Commandes utiles (Terminal)
```bash
# Régénérer le projet
cd /Users/micha/web/tft-assistant && xcodegen

# Ouvrir dans Xcode
open /Users/micha/web/tft-assistant/TFTAssistant.xcodeproj

# Compiler en ligne de commande
xcodebuild -project TFTAssistant.xcodeproj -scheme TFTAssistant build
```

---

## CHECKLIST DE PROGRESSION

### Phase 1 : MVP Core

#### Étape 0 — Base app
- [x] 0.1 Créer projet Xcode + structure dossiers
- [x] 0.2 Menu bar icon (NSStatusBar) fonctionnel
- [x] 0.3 Popover SwiftUI basique (vide)
- [x] 0.4 UserDefaults pour settings de base
- [x] 0.5 Raccourci clavier global (⌥T)

#### Étape 1 — Capture écran
- [x] 1.1 Demande permission Screen Recording + gestion refus
- [x] 1.2 ScreenCaptureManager : capture single frame
- [x] 1.3 Afficher image capturée dans popover (debug)
- [x] 1.4 Capture continue à 5 fps (scheduler)
- [x] 1.5 Toggle start/stop capture dans UI

#### Étape 2 — Calibration
- [x] 2.1 Modèle CalibrationData (struct + Codable)
- [x] 2.2 UI sélection rectangle zone Stage
- [x] 2.3 UI sélection rectangle zone Augments
- [x] 2.4 UI sélection rectangle zone Items
- [x] 2.5 Sauvegarde JSON + chargement au démarrage
- [x] 2.6 Preview des crops en temps réel

#### Étape 3 — OCR Stage/Round
- [x] 3.1 StageOCR : Vision request basique
- [x] 3.2 Extraction regex `\d-\d`
- [x] 3.3 Affichage stage dans UI
- [x] 3.4 Debounce (stabilisation)
- [x] 3.5 Score confiance + affichage

### Phase 2 : Détection Items

#### Étape 4 — Template matching items
- [x] 4.1 Chargement templates PNG au démarrage
- [x] 4.2 TemplateMatcher : algorithme basique
- [x] 4.3 Gestion multi-scale (Retina)
- [x] 4.4 Liste items détectés dans UI
- [x] 4.5 Score confiance par item
- [ ] 4.6 Réduire les faux positifs (améliorer algorithme)

#### Étape 5 — Item Builder
- [ ] 5.1 Parser items_recipes.json
- [ ] 5.2 UI liste composants détectés
- [ ] 5.3 Affichage items craftables
- [ ] 5.4 Highlight recettes possibles

### Phase 3 : Détection Augments

#### Étape 6 — OCR Augments
- [ ] 6.1 AugmentOCR : 3 zones séparées
- [ ] 6.2 Parser augments.json
- [ ] 6.3 Fuzzy matching (Levenshtein)
- [ ] 6.4 UI liste 3 augments + confiance
- [ ] 6.5 Normalisation texte robuste

#### Étape 7 — Fallback icônes
- [ ] 7.1 Chargement templates augments
- [ ] 7.2 Matching si OCR < seuil
- [ ] 7.3 Mapping augment_icons.json
- [ ] 7.4 UI indique méthode (OCR/icône)

### Phase 4 : Polish

#### Étape 8 — Finitions
- [ ] 8.1 Onglet Status complet (fps, latence, CPU)
- [ ] 8.2 Onglet Round/Timer
- [ ] 8.3 Mode debug toggle global
- [ ] 8.4 Optimisations mémoire/CPU
- [ ] 8.5 Tests multi-résolutions

---

## Améliorations futures (backlog)

- [ ] **Riot Developer Portal** : Explorer l'API Riot pour synchroniser automatiquement les templates à chaque patch, récupérer les stats des items, etc.
- [ ] **Localisation FR** : Traduire l'interface en français
- [ ] Support multi-langues (système de localisation SwiftUI)
- [ ] **Fenêtre réglages raccourcis** : Permettre à l'utilisateur de configurer son propre raccourci clavier
- [x] **Configurer signing automatique** : ~~Résoudre le problème de mot de passe trousseau~~ → Résolu ! Utiliser "Toujours autoriser" dans le dialogue trousseau

---

## Dernière session

**Date** : 5 mars 2026
**Session** : #2

### Ce qui a été implémenté
- Étapes 1, 2, 3, 4 complètes !
- Calibration avec overlay de sélection directe sur l'écran
- OCR Stage/Round fonctionnel (100% confiance)
- Template matching pour items (10 templates)
- Gestion Retina (échelles 0.06-0.15 pour templates 128px)
- Signature Apple Development configurée (plus de demande permission répétée)

### Templates d'items disponibles
- BF Sword, Chain Vest, Giant's Belt, Needlessly Large Rod
- Negatron Cloak, Recurve Bow, Sparring Gloves, Tear of the Goddess
- Reforger, Magnetic Remover (consommables)

### Fichiers créés/modifiés cette session
- `Sources/Vision/TemplateMatcher.swift` — Algorithme template matching
- `Sources/Vision/ItemDetector.swift` — Détection items en continu
- `Sources/Vision/StageOCR.swift` — OCR du stage/round
- `Sources/Capture/RegionCropper.swift` — Crop des zones calibrées
- `Sources/Data/CalibrationStore.swift` — Gestion calibration
- `Sources/UI/CalibrationOverlay.swift` — Overlay de sélection
- `Assets/Templates/Items/*.png` — 10 templates d'items

### État actuel
- **Dernière sous-tâche terminée** : 4.5 (Template matching items)
- **Prochaine sous-tâche** : 4.6 (Réduire faux positifs) ou 5.1 (Item Builder)
- **L'app compile** : Oui
- **L'app est testable** : Oui

### Comment tester l'état actuel
1. Ouvrir `TFTAssistant.xcodeproj` dans Xcode
2. Build & Run (⌘R)
3. Cliquer sur l'icône manette OU ⌥T
4. Onglet Settings → Calibrer les zones (Stage, Items)
5. Activer la capture
6. Voir le stage détecté dans l'onglet Round
7. Voir les items détectés dans l'onglet Items

### Notes / Problèmes en suspens
- Quelques faux positifs dans la détection d'items (seuil à 85%)
- Interface en anglais → prévoir localisation FR

### Pour reprendre
1. Ouvrir le projet : `/Users/micha/web/tft-assistant/TFTAssistant.xcodeproj`
2. Lire cette section
3. Continuer avec l'amélioration de la détection ou l'Item Builder

---

## Architecture

```
tft-assistant/
├── TFTAssistant.xcodeproj      # Généré par xcodegen
├── project.yml                  # Config xcodegen
├── CLAUDE.md                    # Ce fichier
├── README.md
├── Sources/
│   ├── App/
│   │   ├── TFTAssistantApp.swift
│   │   └── AppDelegate.swift
│   ├── Capture/                 # À implémenter (étape 1)
│   ├── Vision/                  # À implémenter (étape 3+)
│   ├── Data/                    # À implémenter (étape 2+)
│   └── UI/
│       └── PopoverView.swift
├── Data/
│   ├── items_recipes.json
│   ├── augments.json
│   └── augment_icons.json
└── Assets/
    └── Templates/
        ├── Items/               # Placeholders
        └── Augments/            # Placeholders
```
