import Foundation
import FujiRecipesCore

// MARK: - Recipe Store

@MainActor
final class RecipeStore: ObservableObject {
    let favorites = FavoritesStore()
    let loadouts = LoadoutStore()
    @Published var recipes: [Recipe] = []
    @Published var searchTerm = ""
    @Published var selectedFilterCategory: FilterCategory? = nil
    @Published var lastError: String?

    enum FilterCategory: String, CaseIterable, Identifiable {
        case favorites, filmSim, dynamicRange, grainEffect, whiteBalance

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .favorites: return "⭐ Favorites"
            case .filmSim: return "Film Simulation"
            case .dynamicRange: return "Dynamic Range"
            case .grainEffect: return "Grain"
            case .whiteBalance: return "White Balance"
            }
        }
    }

    var filteredRecipes: [Recipe] {
        var result = recipes

        if let category = selectedFilterCategory {
            switch category {
            case .favorites:
                result = result.filter { favorites.isFavorite($0.id) }
            case .filmSim:
                result = result.filter { $0.filmSimulation != nil }
            case .dynamicRange:
                result = result.filter { $0.dynamicRange != nil }
            case .grainEffect:
                result = result.filter { $0.grainEffect != nil }
            case .whiteBalance:
                result = result.filter { $0.whiteBalanceMode != nil }
            }
        }

        if !searchTerm.isEmpty {
            let lower = searchTerm.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(lower) ||
                ($0.filmSimulation?.displayName.lowercased() ?? "").contains(lower)
            }
        }

        return result
    }

    func loadRecipes() {
        do {
            recipes = try RecipeLoader.loadRecipes(from: .main)
            lastError = nil
            DebugLogger.info("Loaded \(recipes.count) recipes", category: .recipes)
        } catch {
            lastError = error.localizedDescription
            DebugLogger.error("Failed to load recipes: \(error.localizedDescription)", category: .recipes)
        }
    }
}
