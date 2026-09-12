import SwiftUI
import FujiRecipesCore

@main
struct FujiRecipesMacApp: App {
    @StateObject private var recipeStore = RecipeStore()
    @StateObject private var cameraManager = CameraManager()
    @State private var selectedTab: AppTab = .recipes

    init() {
        DebugLogger.setMinimumLevel(.debug)
        DebugLogger.log(.info, category: .app, "🚀 FujiRecipesMac Pro launching")
        DebugLogger.log(.info, category: .app, "Version: \(DebugLogger.appInfo["version"] ?? "2026.1")")

        CrashReportHelper.setup()
        DebugLogger.info("CrashReportHelper.setup() complete", category: .app)
        
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--generate-snapshots") {
            Task { @MainActor in
                SnapshotRenderer.renderSnapshots()
                exit(0)
            }
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                GlassWindowBackground()

                NavigationSplitView {
                    SidebarView(
                        selection: $selectedTab,
                        recipeStore: recipeStore,
                        cameraManager: cameraManager
                    )
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
                } detail: {
                    ZStack {
                        Color.clear
                        Group {
                            switch selectedTab {
                            case .recipes:
                                RecipeListView(store: recipeStore, cameraManager: cameraManager)
                            case .loadouts:
                                LoadoutsView(loadouts: recipeStore.loadouts)
                            case .camera:
                                CameraConnectionView(manager: cameraManager, loadouts: recipeStore.loadouts)
                            case .darkroom:
                                RAFDarkroomView(manager: cameraManager)
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.985)).combined(with: .offset(y: 6)),
                            removal: .opacity.combined(with: .scale(scale: 1.01))
                        ))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.spring(response: 0.35, dampingFraction: 0.82), value: selectedTab)
                }
                .navigationSplitViewStyle(.balanced)
                .frame(minWidth: 780, minHeight: 520)
                .tint(Theme.fujiAmber)
                .background(.clear)
                .scrollContentBackground(.hidden)
            }
            .preferredColorScheme(.dark)
            .debugHUD()
            .onAppear {
                DebugLogger.log(.info, category: .app, "App appeared — Tab: \(selectedTab.rawValue)")
                recipeStore.loadRecipes()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1100, height: 720)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Refresh Recipes") {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        recipeStore.loadRecipes()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Divider()
                ForEach(Array(AppTab.allCases.enumerated()), id: \.element) { index, tab in
                    Button(tab.title) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedTab = tab
                        }
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
        }
    }
}
