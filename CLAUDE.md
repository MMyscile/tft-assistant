# TFT Menu Bar Assistant — Suivi du projet

## Description

App macOS menu bar (SwiftUI) qui assiste Teamfight Tactics via screen recognition :
- OCR du stage/round
- Détection des items par **pHash + Color Histogram**
- Calibration par **10 slots individuels** (précision décimale)
- Capture en **résolution native Retina**

## Contraintes de sécurité (non négociables)

**Interdit** : injection, hooking, lecture mémoire, automatisation gameplay, contournement anti-cheat

**Autorisé** : capture écran (APIs macOS), OCR (Vision), template matching local, affichage UI

## Spécifications

- macOS 12.3+, Swift 5.9+, Xcode 15+
- Intel + Apple Silicon
- ScreenCaptureKit + Vision
- 5 fps (configurable)

---

## Branches Git

| Branche | Description | État |
|---------|-------------|------|
| `main` | Version stable GitHub (session #2) | Stable |
| `feature/item-slots-calibration` | Calibration 10 slots + Retina | Mergeable |
| `feature/item-detection` | **pHash + Histogram** (actuelle) | En cours |
| `feature/item-detection-sift-orb` | Alternative SIFT/ORB | À tester |
| `session3-backup` | Backup tentatives session #3 | Archive |

---

## Workflow de développement

### Compilation automatique
Claude compile automatiquement après chaque modification avec `xcodebuild`.
- **BUILD SUCCEEDED** → Tu peux tester dans Xcode (Cmd+R)
- **BUILD FAILED** → Claude corrige l'erreur avant de te demander de tester

### Commandes utiles (Terminal)
```bash
# Compiler
cd /Users/micha/WEB/PROJECT/tft-assistant
xcodebuild -project TFTAssistant.xcodeproj -scheme TFTAssistant build

# Ouvrir dans Xcode
open TFTAssistant.xcodeproj

# Voir les images debug
ls -la ~/Desktop/TFT_Debug/

# Voir la calibration sauvegardée
cat ~/Library/Application\ Support/TFTAssistant/calibration.json | python3 -m json.tool

# État git
git branch -a
git status
```

---

## CHECKLIST DE PROGRESSION

### Phase 1 : MVP Core (Complète)

#### Étape 0 — Base app
- [x] 0.1 Créer projet Xcode + structure dossiers
- [x] 0.2 Menu bar icon (NSStatusBar) fonctionnel
- [x] 0.3 Popover SwiftUI basique
- [x] 0.4 UserDefaults pour settings de base
- [x] 0.5 Raccourci clavier global (Option+T)

#### Étape 1 — Capture écran
- [x] 1.1 Demande permission Screen Recording + gestion refus
- [x] 1.2 ScreenCaptureManager : capture single frame
- [x] 1.3 Afficher image capturée dans popover (debug)
- [x] 1.4 Capture continue à 5 fps (scheduler)
- [x] 1.5 Toggle start/stop capture dans UI
- [x] 1.6 **Capture Retina native** (×2 backingScaleFactor)

#### Étape 2 — Calibration
- [x] 2.1 Modèle CalibrationData (struct + Codable)
- [x] 2.2 UI sélection rectangle zone Stage
- [x] 2.3 UI sélection rectangle zone Augments
- [x] 2.4 UI sélection rectangle zone Items
- [x] 2.5 Sauvegarde JSON + chargement au démarrage
- [x] 2.6 Preview des crops en temps réel
- [x] 2.7 **Calibration 10 slots individuels** avec panneau de saisie précise
- [x] 2.8 **Ajustement décimal** (flèches: 0.5px, Shift+flèches: 0.1px)
- [x] 2.9 **Chargement calibration existante** pour édition

#### Étape 3 — OCR Stage/Round
- [x] 3.1 StageOCR : Vision request basique
- [x] 3.2 Extraction regex `\d-\d`
- [x] 3.3 Affichage stage dans UI
- [x] 3.4 Debounce (stabilisation)
- [x] 3.5 Score confiance + affichage

### Phase 2 : Détection Items (En cours)

#### Étape 4 — Template matching items
- [x] 4.1 Chargement templates PNG au démarrage
- [x] 4.2 TemplateMatcher : **pHash (64-bit) + Color Histogram (64 bins)**
- [x] 4.3 Pré-calcul des fingerprints au chargement
- [x] 4.4 Liste items détectés dans UI
- [x] 4.5 Score confiance par item (combiné pH + histogram)
- [ ] 4.6 Améliorer scores (HSV histogram, cropping centre)

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
- [x] 8.3 Mode debug toggle global
- [ ] 8.4 Optimisations mémoire/CPU
- [ ] 8.5 Tests multi-résolutions

---

## Algorithme de détection actuel

### pHash + Color Histogram (scale-invariant)

```
Template (128×128 PNG)           Slot capturé (61×61 px)
         │                                │
         ▼                                ▼
┌─────────────────┐              ┌─────────────────┐
│ pHash 64-bit    │              │ pHash 64-bit    │
│ (structure)     │              │ (structure)     │
└────────┬────────┘              └────────┬────────┘
         │                                │
         ▼                                ▼
┌─────────────────┐              ┌─────────────────┐
│ Histogram 64    │              │ Histogram 64    │
│ bins (4×4×4 RGB)│              │ bins (4×4×4 RGB)│
└────────┬────────┘              └────────┬────────┘
         │                                │
         └───────────┬────────────────────┘
                     ▼
              Score combiné
         (40% pHash + 60% Histogram)
                     │
                     ▼
              Seuil > 50% → Match
```

**Avantages** :
- Scale-invariant (pas besoin de redimensionner)
- Rapide (~1ms par comparaison)
- Robuste aux variations de luminosité

---

## Templates d'items disponibles (10)

| Composants | Consommables |
|------------|--------------|
| BF Sword | Reforger |
| Chain Vest | Magnetic Remover |
| Giant's Belt | |
| Needlessly Large Rod | |
| Negatron Cloak | |
| Recurve Bow | |
| Sparring Gloves | |
| Tear of the Goddess | |

---

## Historique des sessions

### Session #5 — 10 mars 2026 (actuelle)
- Fix pHash (utilisait NSImage.size en points au lieu de CGImage pixels)
- Détection items **100% correcte** sur test 4 items
- Recherche algorithmes : pHash, SIFT/ORB, histogrammes
- Création branche `feature/item-detection-sift-orb` pour alternative

### Session #4 — 7-9 mars 2026
- Système calibration **10 slots individuels**
- Capture **Retina native** (3024×1964 au lieu de 1512×982)
- Panneau saisie précise (valeurs décimales)
- Fix focus fenêtre calibration (NSApp.activate)
- Coins redimensionnables pour zones

### Session #3 — mars 2026
- Tentatives détection items (non concluante)
- Backup dans branche `session3-backup`

### Session #2 — 5 mars 2026
- Étapes 1-4 complètes
- Calibration overlay, OCR stage, template matching basique
- Version stable sur `main`

---

## État actuel

**Date** : 10 mars 2026
**Branche** : `feature/item-detection`

### Ce qui fonctionne
- Capture Retina native (3024×1964 pixels)
- OCR Stage/Round (100% confiance)
- Calibration 10 slots avec ajustement précis
- Détection items par pHash + Histogram
- 4/4 items correctement identifiés dans les tests

### Scores de détection (exemple)
| Slot | Item | Score |
|------|------|-------|
| 0 | BF Sword | 92% |
| 1 | Magnetic Remover | 77% |
| 2 | Chain Vest | 91% |
| 3 | Tear of the Goddess | 81% |

### Prochaines étapes
1. Améliorer les scores (HSV histogram)
2. Tester avec plus d'items
3. Implémenter Item Builder (recettes)

### Comment tester
1. Ouvrir `TFTAssistant.xcodeproj` dans Xcode
2. Build & Run (Cmd+R)
3. Option+T ou cliquer sur l'icône
4. Settings → Calibrer les 10 slots
5. Activer la capture
6. Voir les items détectés dans l'onglet Items

---

## Architecture

```
tft-assistant/
├── TFTAssistant.xcodeproj
├── CLAUDE.md                    # Ce fichier
├── README.md
├── SESSION_4.md                 # Notes session #4
├── Sources/
│   ├── App/
│   │   ├── TFTAssistantApp.swift
│   │   └── AppDelegate.swift
│   ├── Capture/
│   │   ├── ScreenCaptureManager.swift  # Capture Retina native
│   │   └── RegionCropper.swift
│   ├── Vision/
│   │   ├── TemplateMatcher.swift       # pHash + Histogram
│   │   ├── ItemDetector.swift          # Détection par slots
│   │   └── StageOCR.swift
│   ├── Data/
│   │   ├── CalibrationData.swift       # ItemSlotsConfig
│   │   ├── CalibrationStore.swift
│   │   └── SettingsManager.swift
│   └── UI/
│       ├── PopoverView.swift
│       └── CalibrationOverlay.swift    # 10 slots + zones
├── Data/
│   ├── items_recipes.json
│   └── augments.json
└── Assets/
    └── Templates/
        └── Items/                       # 10 templates PNG 128×128
```

---

## Améliorations futures (backlog)

- [ ] **HSV Histogram** : Meilleure discrimination des couleurs
- [ ] **SIFT/ORB** : Tester sur branche dédiée
- [ ] **Riot Developer Portal** : Sync templates auto
- [ ] **Localisation FR** : Interface en français
- [ ] **Item Builder** : Afficher recettes possibles
- [ ] **Augments OCR** : Détection des choix d'augments
- [x] **Signing automatique** : Résolu (Toujours autoriser)
