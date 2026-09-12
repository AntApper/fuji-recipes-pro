import SwiftUI
import AppKit
import FujiRecipesCore

@MainActor
public enum SnapshotRenderer {
    public static func renderSnapshots() {
        let store = RecipeStore()
        store.loadRecipes()
        let camera = CameraManager()
        
        let outputDir = URL(fileURLWithPath: "/Users/ant/Documents/project/fuji-recipes-research/docs/screenshots")
        try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        // 1. Recipes Studio View
        let recipesWindow = makeWindow(tab: .recipes, store: store, camera: camera) {
            RecipeListView(store: store)
        }
        renderWindow(recipesWindow, to: outputDir.appendingPathComponent("fuji_recipes_studio.png"), size: CGSize(width: 1180, height: 780))
        
        // 2. Loadouts Matrix View
        let loadoutsWindow = makeWindow(tab: .loadouts, store: store, camera: camera) {
            LoadoutsView(loadouts: store.loadouts)
        }
        renderWindow(loadoutsWindow, to: outputDir.appendingPathComponent("fuji_custom_dial_matrix.png"), size: CGSize(width: 1180, height: 780))
        
        // 3. Camera Hub View
        let cameraWindow = makeWindow(tab: .camera, store: store, camera: camera) {
            CameraConnectionView(manager: camera, loadouts: store.loadouts)
        }
        renderWindow(cameraWindow, to: outputDir.appendingPathComponent("fuji_camera_telemetry_hub.png"), size: CGSize(width: 1180, height: 780))
        
        // 4. RAF Darkroom View
        let darkroomWindow = makeWindow(tab: .darkroom, store: store, camera: camera) {
            RAFDarkroomView(manager: camera)
        }
        renderWindow(darkroomWindow, to: outputDir.appendingPathComponent("fuji_in_camera_darkroom.png"), size: CGSize(width: 1180, height: 780))
    }
    
    private static func makeWindow<Content: View>(
        tab: AppTab,
        store: RecipeStore,
        camera: CameraManager,
        @ViewBuilder detail: () -> Content
    ) -> some View {
        ZStack {
            GlassWindowBackground()
            
            HStack(spacing: 0) {
                SidebarView(
                    selection: .constant(tab),
                    recipeStore: store,
                    cameraManager: camera
                )
                .frame(width: 250)
                
                Rectangle()
                    .fill(Theme.specularBorder)
                    .frame(width: 1)
                
                detail()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .frame(width: 1180, height: 780)
        .tint(Theme.fujiAmber)
    }
    
    private static func renderWindow<V: View>(_ view: V, to url: URL, size: CGSize) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: size)
        
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = hostingView
        window.layoutIfNeeded()
        window.display()
        
        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            print("Failed to allocate bitmap rep for \(url.lastPathComponent)")
            return
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)
        
        if let pngData = rep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: url)
            print("Successfully rendered: \(url.lastPathComponent) (\(pngData.count) bytes)")
        }
    }
}
