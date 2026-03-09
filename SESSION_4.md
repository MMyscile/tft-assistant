# Session #4 — 7-8 mars 2026

## Objectif
Implémenter un système de calibration par **10 slots individuels** avec capture en résolution native Retina.

## Branche Git
```
* feature/item-slots-calibration  ← Branche actuelle
  main                            ← Version GitHub stable (session #2)
  session3-backup                 ← Backup des tentatives session #3
```

## Fichiers modifiés cette session

| Fichier | Changements |
|---------|-------------|
| `CalibrationData.swift` | Ajout `ItemSlotsConfig` (struct pour 10 slots) + init membre-par-membre |
| `CalibrationStore.swift` | `updateItemSlots()`, `getItemSlotRects()`, `hasItemSlots`, migration v1→v2 |
| `CalibrationOverlay.swift` | Calibration slots avec **panneau de saisie précise** (champs texte décimaux) |
| `CalibrationView.swift` | Bouton séparé "Items (10 slots)" + méthode `startItemSlotsSelection()` |
| `PopoverView.swift` | Bouton **"Capturer slots → Bureau"** dans debug + logs détaillés |
| `ItemDetector.swift` | Support des 2 systèmes (slots OU zone rectangulaire) |
| `ScreenCaptureManager.swift` | **Capture en résolution native Retina** (×2) |

## État actuel

### Ce qui fonctionne
- [x] Capture en résolution native Retina (3024×1964 au lieu de 1512×982)
- [x] UI de calibration des 10 slots (Phase 1: dessiner, Phase 2: ajuster)
- [x] **Panneau de saisie précise** avec champs texte pour taille et espacement décimaux
- [x] Flèches ↑↓←→ ajustent de 0.5 px (Shift+flèche = 0.1 px)
- [x] Sauvegarde/chargement de la config des slots
- [x] Bouton capture debug qui sauvegarde les images dans `~/Desktop/TFT_Debug/`
- [x] Images capturées nettes et lisibles (~40×40 px)

### Problème résolu : images trop petites
**Cause** : `SCDisplay.width/height` retourne des points, pas des pixels.
**Solution** : Multiplier par `NSScreen.main?.backingScaleFactor` pour capturer en résolution native.

### Problème en cours : décalage cumulatif des slots
Les slots 0-3 sont bien cadrés, mais les slots suivants dérivent progressivement.
**Cause** : l'espacement calibré n'était pas assez précis (incréments de 1 px).
**Solution** : Ajout de champs texte pour saisir des valeurs décimales (ex: 5.3 px).

## Commandes utiles

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
git status
git diff --stat
```

## Calibration actuelle (à recalibrer après fix)

```json
{
  "itemSlots": {
    "spacing": 0.0103,
    "slotCount": 10,
    "slotSize": 0.0201,
    "firstSlotOrigin": [0.0055, 0.3056]
  }
}
```

Avec écran 982px de haut → slotSize attendu = 19.7px
Mais images capturées = 11px → ratio ~0.56 (probablement 756/982 ?)
