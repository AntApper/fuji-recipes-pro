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
        
        renderHostingView(recipesView, to: outputDir.appendingPathComponent("recipes_view.png"), size: CGSize(width: 1180, height: 780))
        
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
        
        renderHostingView(loadoutsView, to: outputDir.appendingPathComponent("loadouts_view.png"), size: CGSize(width: 1180, height: 780))
        
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
        
        renderHostingView(cameraView, to: outputDir.appendingPathComponent("camera_hub_view.png"), size: CGSize(width: 1180, height: 780))
        
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
        
        renderHostingView(darkroomView, to: outputDir.appendingPathComponent("darkroom_view.png"), size: CGSize(width: 1180, height: 780))
    }
    
    private static func renderHostingView<V: View>(_ view: V, to url: URL, size: CGSize) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: size)
        
        // Create an offscreen window to guarantee layout, appearance, and subview hierarchy rendering
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
