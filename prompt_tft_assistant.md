# Projet : TFT Menu Bar Assistant (macOS)

## Contexte

Créer une app macOS "menu bar" (SwiftUI) qui assiste Teamfight Tactics via screen recognition : OCR du stage/round, détection des augments et items par analyse d'image. Projet à long terme, développé de manière incrémentale sur plusieurs sessions.

---

## Contraintes de sécurité (non négociables)

### Interdit
- Injection / hooking / lecture mémoire du jeu
- Automatisation du gameplay (botting), simulation d'inputs
- Contournement anti-cheat, modification du client

### Autorisé
- Capture d'écran via APIs macOS officielles
- OCR (Vision framework), template matching local
- Affichage d'infos dans une UI séparée (menu bar)

---

## Spécifications techniques

| Élément | Valeur |
|---------|--------|
| macOS cible | 12.3+ (Monterey) |
| Swift | 5.9+ |
| Xcode | 15+ |
| Architectures | Intel + Apple Silicon (Universal) |
| Capture | ScreenCaptureKit (fallback CGDisplayStream) |
| OCR | Vision (VNRecognizeTextRequest) |
| FPS cible | 5 fps (configurable) |
| Mode TFT | Plein écran |

---

## CHECKLIST DE PROGRESSION GLOBALE

> **Instruction** : Mettre à jour cette checklist à chaque session. Cocher les sous-tâches terminées.

### Phase 1 : MVP Core

#### Étape 0 — Base app
- [ ] 0.1 Créer projet Xcode + structure dossiers
- [ ] 0.2 Menu bar icon (NSStatusBar) fonctionnel
- [ ] 0.3 Popover SwiftUI basique (vide)
- [ ] 0.4 UserDefaults pour settings de base
- [ ] 0.5 Raccourci clavier global (⌥Space)

#### Étape 1 — Capture écran
- [ ] 1.1 Demande permission Screen Recording + gestion refus
- [ ] 1.2 ScreenCaptureManager : capture single frame
- [ ] 1.3 Afficher image capturée dans popover (debug)
- [ ] 1.4 Capture continue à 5 fps (scheduler)
- [ ] 1.5 Toggle start/stop capture dans UI

#### Étape 2 — Calibration
- [ ] 2.1 Modèle CalibrationData (struct + Codable)
- [ ] 2.2 UI sélection rectangle zone Stage
- [ ] 2.3 UI sélection rectangle zone Augments
- [ ] 2.4 UI sélection rectangle zone Items
- [ ] 2.5 Sauvegarde JSON + chargement au démarrage
- [ ] 2.6 Preview des crops en temps réel

#### Étape 3 — OCR Stage/Round
- [ ] 3.1 StageOCR : Vision request basique
- [ ] 3.2 Extraction regex `\d-\d`
- [ ] 3.3 Affichage stage dans UI
- [ ] 3.4 Debounce (stabilisation)
- [ ] 3.5 Score confiance + affichage

### Phase 2 : Détection Items

#### Étape 4 — Template matching items
- [ ] 4.1 Chargement templates PNG au démarrage
- [ ] 4.2 TemplateMatcher : algorithme basique
- [ ] 4.3 Gestion multi-scale (Retina)
- [ ] 4.4 Liste items détectés dans UI
- [ ] 4.5 Score confiance par item

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

## ÉTAT DE LA SESSION

> **Instruction** : Cette section doit être mise à jour dans le CLAUDE.md du projet à chaque fin de session.

```markdown
## Dernière session

**Date** : [À REMPLIR]
**Durée approximative** : [À REMPLIR]

### Ce qui a été implémenté
- [Liste des sous-tâches complétées]

### Fichiers créés/modifiés
- [Liste des fichiers]

### État actuel
- **Dernière sous-tâche terminée** : [ex: 1.3]
- **Prochaine sous-tâche** : [ex: 1.4]
- **L'app compile** : Oui/Non
- **L'app est testable** : Oui/Non

### Comment tester l'état actuel
1. [Instructions de test]
2. [Résultat attendu]

### Notes / Problèmes en suspens
- [Bugs connus, questions, décisions à prendre]

### Pour reprendre
1. Ouvrir le projet dans Xcode : `[chemin]`
2. Lire cette section
3. Continuer à partir de la sous-tâche : [X.X]
```

---

## DÉTAIL DES SOUS-TÂCHES (avec tests)

### Étape 0 — Base app

#### 0.1 Créer projet Xcode + structure dossiers
**Livrable** : Projet Xcode vide avec structure de dossiers
**Test** : Le projet s'ouvre dans Xcode sans erreur
**Fichiers** : TFTAssistant.xcodeproj, dossiers Sources/, Data/, Assets/

#### 0.2 Menu bar icon fonctionnel
**Livrable** : Icône apparaît dans la barre de menu
**Test** :
1. Lancer l'app
2. Vérifier : icône visible dans menu bar
3. Clic sur icône = pas de crash
**Fichiers** : AppDelegate.swift

#### 0.3 Popover SwiftUI basique
**Livrable** : Popover s'ouvre au clic sur l'icône
**Test** :
1. Cliquer sur l'icône menu bar
2. Vérifier : popover s'affiche avec texte "TFT Assistant"
3. Cliquer ailleurs = popover se ferme
**Fichiers** : PopoverView.swift

#### 0.4 UserDefaults pour settings
**Livrable** : Settings persistent entre relances
**Test** :
1. Ajouter un toggle dans le popover
2. Changer sa valeur
3. Quitter et relancer l'app
4. Vérifier : valeur conservée
**Fichiers** : SettingsManager.swift

#### 0.5 Raccourci clavier global
**Livrable** : ⌥Space ouvre/ferme le popover
**Test** :
1. Popover fermé
2. Appuyer ⌥Space
3. Vérifier : popover s'ouvre
4. Appuyer ⌥Space à nouveau
5. Vérifier : popover se ferme
**Fichiers** : HotkeyManager.swift

---

### Étape 1 — Capture écran

#### 1.1 Permission Screen Recording
**Livrable** : Demande de permission + gestion du refus
**Test** :
1. Lancer l'app (première fois)
2. Vérifier : popup système demande permission
3. Si refusé : message explicatif dans l'UI
**Fichiers** : ScreenCaptureManager.swift

#### 1.2 Capture single frame
**Livrable** : Fonction qui capture une image de l'écran
**Test** :
1. Bouton "Capture" dans popover
2. Cliquer = log dans console avec dimensions image
3. Pas de crash si TFT fermé
**Fichiers** : ScreenCaptureManager.swift

#### 1.3 Afficher image dans popover
**Livrable** : Image capturée visible dans l'UI
**Test** :
1. Cliquer "Capture"
2. Vérifier : image (réduite) s'affiche dans popover
3. Image correspond à l'écran actuel
**Fichiers** : DebugImageView.swift

#### 1.4 Capture continue 5 fps
**Livrable** : Scheduler qui capture en boucle
**Test** :
1. Bouton "Start" démarre la capture
2. Console affiche "Frame captured" ~5x/seconde
3. CPU reste < 10%
**Fichiers** : CaptureScheduler.swift

#### 1.5 Toggle start/stop
**Livrable** : UI pour contrôler la capture
**Test** :
1. Bouton "Start" → devient "Stop"
2. Logs s'affichent
3. Bouton "Stop" → logs s'arrêtent
**Fichiers** : StatusView.swift

---

### Étape 2 — Calibration

#### 2.1 Modèle CalibrationData
**Livrable** : Struct pour stocker les rectangles
**Test** :
1. Créer instance en code
2. Encoder en JSON
3. Décoder depuis JSON
4. Valeurs identiques
**Fichiers** : CalibrationData.swift

#### 2.2 UI sélection zone Stage
**Livrable** : Écran pour dessiner un rectangle sur l'image
**Test** :
1. Ouvrir écran Calibration
2. Image de capture affichée
3. Drag pour dessiner rectangle
4. Rectangle visible en surbrillance
**Fichiers** : CalibrationView.swift, RectangleSelector.swift

#### 2.3 UI sélection zone Augments
**Livrable** : Même chose pour zone Augments
**Test** : Idem 2.2, rectangle différent (couleur)
**Fichiers** : CalibrationView.swift

#### 2.4 UI sélection zone Items
**Livrable** : Même chose pour zone Items
**Test** : Idem 2.2, rectangle différent (couleur)
**Fichiers** : CalibrationView.swift

#### 2.5 Sauvegarde/chargement JSON
**Livrable** : Persistance de la calibration
**Test** :
1. Définir les 3 zones
2. Cliquer "Sauvegarder"
3. Quitter l'app
4. Relancer
5. Vérifier : rectangles rechargés correctement
**Fichiers** : CalibrationStore.swift

#### 2.6 Preview crops en temps réel
**Livrable** : Afficher les 3 régions croppées
**Test** :
1. Calibration définie
2. Capture active
3. 3 petites images (crops) s'affichent
4. Correspondent aux zones définies
**Fichiers** : RegionCropper.swift, CropPreviewView.swift

---

### Étape 3 — OCR Stage/Round

#### 3.1 Vision request basique
**Livrable** : OCR sur la région Stage
**Test** :
1. Capture avec zone Stage calibrée
2. Console affiche le texte brut détecté
**Fichiers** : StageOCR.swift

#### 3.2 Extraction regex
**Livrable** : Parser le pattern X-X
**Test** :
1. OCR retourne "Stage 3-2"
2. Extraction donne (3, 2)
3. OCR retourne "garbage" → nil
**Fichiers** : StageOCR.swift

#### 3.3 Affichage dans UI
**Livrable** : Stage affiché en gros dans l'onglet Round
**Test** :
1. TFT ouvert au stage 2-5
2. UI affiche "2-5"
**Fichiers** : RoundTab.swift

#### 3.4 Debounce
**Livrable** : Stabilisation des valeurs
**Test** :
1. Stage change de 3-1 à 3-2
2. UI met ~0.5s à changer (pas de flicker)
3. Valeur stable entre les changements
**Fichiers** : StageOCR.swift (debounce logic)

#### 3.5 Score confiance
**Livrable** : Afficher la confiance OCR
**Test** :
1. UI affiche "3-2 (95%)"
2. Si confiance < 50%, affiche "?" ou ancien stage
**Fichiers** : RoundTab.swift

---

## Architecture modulaire

```
TFTAssistant/
├── TFTAssistant.xcodeproj
├── CLAUDE.md                    # État du projet + reprise
├── README.md                    # Instructions build/run
├── Sources/
│   ├── App/
│   │   ├── TFTAssistantApp.swift
│   │   └── AppDelegate.swift
│   ├── Capture/
│   │   ├── ScreenCaptureManager.swift
│   │   ├── RegionCropper.swift
│   │   └── CaptureScheduler.swift
│   ├── Vision/
│   │   ├── StageOCR.swift
│   │   ├── AugmentOCR.swift
│   │   └── TemplateMatcher.swift
│   ├── Data/
│   │   ├── CalibrationStore.swift
│   │   ├── CalibrationData.swift
│   │   ├── SettingsManager.swift
│   │   ├── ItemRecipes.swift
│   │   └── AugmentDatabase.swift
│   └── UI/
│       ├── PopoverView.swift
│       ├── StatusTab.swift
│       ├── RoundTab.swift
│       ├── AugmentsTab.swift
│       ├── ItemsTab.swift
│       ├── CalibrationView.swift
│       ├── RectangleSelector.swift
│       ├── CropPreviewView.swift
│       └── DebugImageView.swift
├── Data/
│   ├── items_recipes.json
│   ├── augments.json
│   └── augment_icons.json
└── Assets/
    └── Templates/
        ├── Items/
        └── Augments/
```

---

## Données JSON (exemples)

### items_recipes.json
```json
{
  "dataVersion": "Set13_Patch14.1",
  "recipes": {
    "Bloodthirster": ["BFSword", "NegatronCloak"],
    "Deathblade": ["BFSword", "BFSword"],
    "GuardianAngel": ["BFSword", "ChainVest"]
  },
  "components": ["BFSword", "RecurveBow", "NeedlesslyLargeRod", "TearOfTheGoddess", "ChainVest", "NegatronCloak", "GiantsBelt", "SparringGloves", "Spatula"]
}
```

### augments.json
```json
{
  "dataVersion": "Set13_Patch14.1",
  "augments": [
    {"id": "TFT_Augment_1", "name": "Buried Treasures", "tier": "silver"},
    {"id": "TFT_Augment_2", "name": "Component Grab Bag", "tier": "silver"}
  ]
}
```

---

## Gestion des erreurs

| Situation | Comportement |
|-----------|-------------|
| Permission Screen Recording refusée | Message + bouton vers Préférences Système |
| TFT non détecté | Indicateur "En attente de TFT..." |
| OCR confiance faible | Afficher "?" plutôt qu'une valeur fausse |
| Template non trouvé | Log warning, continuer |

---

## Assets : stratégie

Les icônes TFT ne sont pas incluses. Options :
1. **Placeholders** : Images placeholder + instructions pour remplacement
2. **Capture intégrée** : Fonction "Capturer icône" dans calibration

Sources légales : Community Dragon, Data Dragon Riot

---

## Mode de travail (IMPORTANT)

### Début de session
```
1. Lire le CLAUDE.md du projet (section "Dernière session")
2. Identifier la prochaine sous-tâche à faire
3. Annoncer : "Je reprends à la sous-tâche X.X : [description]"
```

### Pendant la session
```
1. Implémenter UNE sous-tâche à la fois
2. Fournir le code
3. Donner les instructions de test
4. Attendre validation OU continuer si temps disponible
5. Mettre à jour la checklist (cocher)
```

### Fin de session (OBLIGATOIRE)
```
1. S'assurer que l'app COMPILE
2. S'assurer que l'état actuel est TESTABLE
3. Mettre à jour le CLAUDE.md avec :
   - Sous-tâches complétées
   - Fichiers modifiés
   - Instructions pour reprendre
   - Bugs/questions en suspens
```

### Règle d'or
> **Ne JAMAIS terminer une session au milieu d'une sous-tâche.**
> Si le temps manque, finir la sous-tâche en cours OU annuler les changements non testables.

---

## Limitations connues

- Résolutions non testées → recalibration nécessaire
- Patchs TFT peuvent casser la détection
- Template matching sensible au scaling
- OCR moins fiable sur textes stylisés

---

## Fichiers à générer (session initiale)

- [ ] Projet Xcode (structure ci-dessus)
- [ ] CLAUDE.md dans le repo
- [ ] README.md
- [ ] Placeholders JSON
- [ ] Placeholders images

---

*Ce fichier est la référence du projet. Le CLAUDE.md dans le repo trace l'avancement réel session par session.*
