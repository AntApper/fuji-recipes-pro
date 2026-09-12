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
        let recipesView = ZStack {
            GlassWindowBackground()
            NavigationSplitView {
                SidebarView(selection: .constant(.recipes), recipeStore: store, cameraManager: camera)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 280)
            } detail: {
                RecipeListView(store: store)
            }
            .navigationSplitViewStyle(.balanced)
            .tint(Theme.fujiAmber)
        }
        .preferredColorScheme(.dark)
        .frame(width: 1180, height: 780)
        
        renderView(recipesView, to: outputDir.appendingPathComponent("recipes_view.png"), size: CGSize(width: 1180, height: 780))
        
        // 2. Loadouts Matrix View
        let loadoutsView = ZStack {
            GlassWindowBackground()
            NavigationSplitView {
                SidebarView(selection: .constant(.loadouts), recipeStore: store, cameraManager: camera)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 280)
            } detail: {
                LoadoutsView(loadouts: store.loadouts)
            }
            .navigationSplitViewStyle(.balanced)
            .tint(Theme.fujiAmber)
        }
        .preferredColorScheme(.dark)
        .frame(width: 1180, height: 780)
        
        renderView(loadoutsView, to: outputDir.appendingPathComponent("loadouts_view.png"), size: CGSize(width: 1180, height: 780))
        
        // 3. Camera Hub View
        let cameraView = ZStack {
            GlassWindowBackground()
            NavigationSplitView {
                SidebarView(selection: .constant(.camera), recipeStore: store, cameraManager: camera)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 280)
            } detail: {
                CameraConnectionView(manager: camera, loadouts: store.loadouts)
            }
            .navigationSplitViewStyle(.balanced)
            .tint(Theme.fujiAmber)
        }
        .preferredColorScheme(.dark)
        .frame(width: 1180, height: 780)
        
        renderView(cameraView, to: outputDir.appendingPathComponent("camera_hub_view.png"), size: CGSize(width: 1180, height: 780))
        
        // 4. RAF Darkroom View
        let darkroomView = ZStack {
            GlassWindowBackground()
            NavigationSplitView {
                SidebarView(selection: .constant(.darkroom), recipeStore: store, cameraManager: camera)
                    .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 280)
            } detail: {
                RAFDarkroomView(manager: camera)
            }
            .navigationSplitViewStyle(.balanced)
            .tint(Theme.fujiAmber)
        }
        .preferredColorScheme(.dark)
        .frame(width: 1180, height: 780)
        
        renderView(darkroomView, to: outputDir.appendingPathComponent("darkroom_view.png"), size: CGSize(width: 1180, height: 780))
    }
    
    private static func renderView<V: View>(_ view: V, to url: URL, size: CGSize) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0 // Retina 2x render
        if let image = renderer.nsImage {
            if let tiff = image.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: url)
                print("Rendered: \(url.lastPathComponent) (\(Int(size.width * 2))x\(Int(size.height * 2)))")
            }
        }
    }
}
