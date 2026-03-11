import Foundation

/// Service pour gérer les recettes d'items TFT
class ItemRecipeService {
    static let shared = ItemRecipeService()

    // MARK: - Data Structures

    struct RecipeData: Codable {
        let dataVersion: String
        let components: [String]
        let recipes: [String: [String]]
    }

    struct CraftableItem {
        let name: String
        let templateId: String
        let components: [String]
        let componentTemplateIds: [String]
    }

    // MARK: - Properties

    private var recipeData: RecipeData?
    private(set) var components: Set<String> = []
    private(set) var recipes: [String: [String]] = [:]

    // MARK: - Init

    private init() {
        loadRecipes()
    }

    // MARK: - Loading

    private func loadRecipes() {
        // Chercher le fichier dans le bundle ou le projet
        let possiblePaths = [
            Bundle.main.path(forResource: "items_recipes", ofType: "json"),
            "/Users/micha/WEB/PROJECT/tft-assistant/Data/items_recipes.json"
        ]

        for path in possiblePaths.compactMap({ $0 }) {
            if let data = FileManager.default.contents(atPath: path) {
                do {
                    recipeData = try JSONDecoder().decode(RecipeData.self, from: data)
                    components = Set(recipeData?.components ?? [])
                    recipes = recipeData?.recipes ?? [:]
                    print("[ItemRecipeService] Loaded \(recipes.count) recipes, \(components.count) components")
                    return
                } catch {
                    print("[ItemRecipeService] Error parsing JSON: \(error)")
                }
            }
        }
        print("[ItemRecipeService] Warning: Could not load recipes")
    }

    // MARK: - Recipe Logic

    /// Convertit un template ID en nom de composant
    /// Ex: "TFT_Item_BFSword" -> "BFSword"
    func templateIdToComponentName(_ templateId: String) -> String {
        // Enlever les préfixes connus
        var name = templateId
            .replacingOccurrences(of: "TFT_Item_", with: "")
            .replacingOccurrences(of: "TFT_Consumable_", with: "")

        // Cas spéciaux de mapping
        let mappings: [String: String] = [
            "TearOfTheGoddess": "TearOfTheGoddess",
            "Rageblade": "Rageblade",
            "GuinsoosRageblade": "Rageblade"
        ]

        if let mapped = mappings[name] {
            name = mapped
        }

        return name
    }

    /// Convertit un nom de composant en template ID
    /// Ex: "BFSword" -> "TFT_Item_BFSword"
    func componentNameToTemplateId(_ name: String) -> String {
        return "TFT_Item_\(name)"
    }

    /// Vérifie si un template ID correspond à un composant de base
    func isComponent(_ templateId: String) -> Bool {
        let name = templateIdToComponentName(templateId)
        return components.contains(name)
    }

    /// Trouve tous les items craftables à partir des composants détectés
    func findCraftableItems(from detectedTemplateIds: [String]) -> [CraftableItem] {
        // Convertir les template IDs en noms de composants
        let detectedComponents = detectedTemplateIds.map { templateIdToComponentName($0) }

        // Compter les occurrences de chaque composant
        var componentCounts: [String: Int] = [:]
        for component in detectedComponents {
            componentCounts[component, default: 0] += 1
        }

        var craftableItems: [CraftableItem] = []

        // Pour chaque recette, vérifier si on a les composants nécessaires
        for (itemName, requiredComponents) in recipes {
            // Compter les composants requis
            var requiredCounts: [String: Int] = [:]
            for component in requiredComponents {
                requiredCounts[component, default: 0] += 1
            }

            // Vérifier si on a assez de chaque composant
            var canCraft = true
            for (component, required) in requiredCounts {
                if (componentCounts[component] ?? 0) < required {
                    canCraft = false
                    break
                }
            }

            if canCraft {
                let item = CraftableItem(
                    name: formatItemName(itemName),
                    templateId: componentNameToTemplateId(itemName),
                    components: requiredComponents,
                    componentTemplateIds: requiredComponents.map { componentNameToTemplateId($0) }
                )
                craftableItems.append(item)
            }
        }

        // Trier par nom
        return craftableItems.sorted { $0.name < $1.name }
    }

    /// Formate un nom d'item pour l'affichage
    /// Ex: "BladeOfTheRuinedKing" -> "Blade Of The Ruined King"
    private func formatItemName(_ name: String) -> String {
        var result = ""
        for char in name {
            if char.isUppercase && !result.isEmpty {
                result += " "
            }
            result += String(char)
        }
        return result
    }

    // MARK: - Debug

    func printAllRecipes() {
        print("[ItemRecipeService] === All Recipes ===")
        for (item, components) in recipes.sorted(by: { $0.key < $1.key }) {
            print("  \(item): \(components.joined(separator: " + "))")
        }
    }
}
