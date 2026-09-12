import Foundation
import SwiftUI
import FujiRecipesCore

// MARK: - Modern 2026 Recipe Store with Multi-Dimensional Filtering & Sorting

@MainActor
public final class RecipeStore: ObservableObject {
    public let favorites = FavoritesStore()
    public let loadouts = LoadoutStore()

    @Published public var recipes: [Recipe] = []
    @Published public var selectedFilterCategory: FilterCategory? = nil
    @Published public var selectedFilmSimFamily: FilmSimFamily = .all
    @Published public var selectedDRFilter: DRFilter = .all
    @Published public var sortOrder: SortOrder = .recommended
    @Published public var searchQuery: String = ""
    @Published public var lastError: String?

    public enum FilterCategory: String, CaseIterable, Identifiable, Hashable {
        case favorites

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .favorites: return "Favorites"
            }
        }
    }

    public enum FilmSimFamily: String, CaseIterable, Identifiable {
        case all = "All Sims"
        case classicChrome = "Classic Chrome"
        case realaAce = "Reala Ace"
        case classicNeg = "Classic Neg"
        case velvia = "Velvia"
        case acros = "Acros / B&W"
        case nostalgicNeg = "Nostalgic Neg"
        case proviaAstia = "Provia / Astia"
        case eterna = "Eterna"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .all: return "square.stack.3d.up.fill"
            case .classicChrome: return "camera.filters"
            case .realaAce: return "sparkles"
            case .classicNeg: return "film"
            case .velvia: return "sun.max.fill"
            case .acros: return "circle.lefthalf.filled"
            case .nostalgicNeg: return "clock.arrow.circlepath"
            case .proviaAstia: return "camera.aperture"
            case .eterna: return "video.fill"
            }
        }
    }

    public enum DRFilter: String, CaseIterable, Identifiable {
        case all = "All DR"
        case dr400 = "DR400"
        case dr200 = "DR200"
        case dr100 = "DR100"

        public var id: String { rawValue }
    }

    public enum SortOrder: String, CaseIterable, Identifiable {
        case recommended = "Featured"
        case alphabetical = "Name (A–Z)"
        case filmSim = "By Film Sim"
        case newest = "Newest"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .recommended: return "sparkles"
            case .alphabetical: return "textformat.abc"
            case .filmSim: return "film"
            case .newest: return "calendar"
            }
        }
    }

    public init() {}

    public var filteredRecipes: [Recipe] {
        var list = recipes

        // 1. Favorites filter
        if selectedFilterCategory == .favorites {
            list = list.filter { favorites.isFavorite($0.id) }
        }

        // 2. Film Sim family filter
        if selectedFilmSimFamily != .all {
            list = list.filter { recipe in
                let name = (recipe.filmSimulation?.displayName ?? recipe.settings?["filmSimulation"] ?? "").lowercased()
                switch selectedFilmSimFamily {
                case .all: return true
                case .classicChrome: return name.contains("classic chrome")
                case .realaAce: return name.contains("reala")
                case .classicNeg: return name.contains("classic neg") || name.contains("classic negative")
                case .velvia: return name.contains("velvia")
                case .acros: return name.contains("acros") || name.contains("mono") || name.contains("black")
                case .nostalgicNeg: return name.contains("nostalgic")
                case .proviaAstia: return name.contains("provia") || name.contains("astia") || name.contains("pro neg")
                case .eterna: return name.contains("eterna")
                }
            }
        }

        // 3. Dynamic Range filter
        if selectedDRFilter != .all {
            list = list.filter { recipe in
                let dr = recipe.dynamicRange?.rawValue ?? 0
                switch selectedDRFilter {
                case .all: return true
                case .dr400: return dr == 400 || (recipe.settings?["dynamicRange"] ?? "").contains("400")
                case .dr200: return dr == 200 || (recipe.settings?["dynamicRange"] ?? "").contains("200")
                case .dr100: return dr == 100 || (recipe.settings?["dynamicRange"] ?? "").contains("100")
                }
            }
        }

        // 4. Text search
        let query = searchQuery.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            list = list.filter { recipe in
                recipe.name.lowercased().contains(query)
                    || (recipe.filmSimulation?.displayName.lowercased() ?? "").contains(query)
                    || (recipe.settings?.values.contains { $0.lowercased().contains(query) } ?? false)
                    || (recipe.tags?.contains { $0.lowercased().contains(query) } ?? false)
            }
        }

        // 5. Sorting
        switch sortOrder {
        case .recommended:
            return list
        case .alphabetical:
            return list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .filmSim:
            return list.sorted {
                ($0.filmSimulation?.displayName ?? "").localizedCaseInsensitiveCompare($1.filmSimulation?.displayName ?? "") == .orderedAscending
            }
        case .newest:
            return list.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        }
    }

    public func loadRecipes() {
        let bundle = Bundle.module.url(forResource: "recipes-data", withExtension: "json") != nil
            ? Bundle.module
            : Bundle.main

        do {
            recipes = try RecipeLoader.loadRecipes(from: bundle)
            lastError = nil
            DebugLogger.info("Loaded \(recipes.count) recipes", category: .recipes)
        } catch {
            lastError = error.localizedDescription
            DebugLogger.error("Failed to load recipes: \(error.localizedDescription)", category: .recipes)
        }
    }
}
