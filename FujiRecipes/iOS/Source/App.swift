import SwiftUI
import FujiRecipesCore
import PTPClient
import PTPClientiOS

@main
struct FujiRecipesApp: App {
    @StateObject private var recipeStore = RecipeStore()
    @StateObject private var cameraManager = CameraManager()
    @State private var selectedTab: Int = 0
    
    init() {
        // Initialize debug logging framework
        DebugLogger.setMinimumLevel(.debug)
        DebugLogger.log(.info, category: .app, "🚀 FujiRecipes iOS launching")
        DebugLogger.log(.info, category: .app, "Version: \(DebugLogger.appInfo["version"] ?? "?")")
        DebugLogger.log(.info, category: .app, "Build: \(DebugLogger.appInfo["build"] ?? "?")")
        
        // Set up crash reporting
        CrashReportHelper.setup()
        
        // Log startup diagnostics
        DebugLogger.info("CrashReportHelper.setup() complete", category: .app)
        DebugLogger.info("Debug builds: 3-finger tap opens debug HUD", category: .debug)
    }
    
    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    recipesList
                }
                .tabItem {
                    Label("Recipes", systemImage: "film")
                }
                .tag(0)
                
                NavigationStack {
                    LoadoutsView(loadouts: recipeStore.loadouts)
                }
                .tabItem {
                    Label("Loadouts", systemImage: "square.grid.2x2")
                }
                .tag(1)
                
                NavigationStack {
                    CameraConnectionView(manager: cameraManager)
                }
                .tabItem {
                    Label("Camera", systemImage: "camera")
                }
                .tag(2)
            }
            .debugHUD()
        }
    }
    
    @ViewBuilder
    private var recipesList: some View {
        List(recipeStore.filteredRecipes) { recipe in
            NavigationLink {
                RecipeDetailView(recipe: recipe, favorites: recipeStore.favorites, loadouts: recipeStore.loadouts)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(recipe.filmSimulation?.displayName ?? "Recipe")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                            if recipeStore.favorites.isFavorite(recipe.id) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(Color.orange)
                                    .font(.caption2)
                            }
                        }
                        Text(recipe.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Spacer()
                    if recipe.hasFullPTPMapped {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption2)
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowSeparator(.visible)
        }
            .searchable(text: $recipeStore.searchTerm, prompt: "Search recipes")
            .navigationTitle("Recipes")
            .onAppear {
                recipeStore.loadRecipes()
            }
            .alert("Couldn’t Load Recipes", isPresented: Binding(
                get: { recipeStore.lastError != nil },
                set: { if !$0 { recipeStore.lastError = nil } }
            )) {
                Button("OK") { recipeStore.lastError = nil }
            } message: {
                Text(recipeStore.lastError ?? "")
            }
    }
}
