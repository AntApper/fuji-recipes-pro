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
        renderWindow(recipesWindow, to: outputDir.appendingPathComponent("recipes_studio_v1789232273.png"), size: CGSize(width: 1200, height: 780))
        
        // 2. Loadouts Matrix View
        let loadoutsWindow = makeWindow(tab: .loadouts, store: store, camera: camera) {
            LoadoutsView(loadouts: store.loadouts)
        }
        renderWindow(loadoutsWindow, to: outputDir.appendingPathComponent("custom_dial_matrix_v1789232273.png"), size: CGSize(width: 1200, height: 780))
        
        // 3. Camera Hub View
        let cameraWindow = makeWindow(tab: .camera, store: store, camera: camera) {
            CameraConnectionView(manager: camera, loadouts: store.loadouts)
        }
        renderWindow(cameraWindow, to: outputDir.appendingPathComponent("camera_hub_v1789232273.png"), size: CGSize(width: 1200, height: 780))
        
        // 4. RAF Darkroom View
        let darkroomWindow = makeWindow(tab: .darkroom, store: store, camera: camera) {
            RAFDarkroomView(manager: camera)
        }
        renderWindow(darkroomWindow, to: outputDir.appendingPathComponent("darkroom_v1789232273.png"), size: CGSize(width: 1200, height: 780))
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
                // Fixed-width crisp sidebar
                SidebarStaticView(selection: tab, recipeStore: store, cameraManager: camera)
                    .frame(width: 250)
                
                Rectangle()
                    .fill(Theme.specularBorder)
                    .frame(width: 1)
                
                detail()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .frame(width: 1200, height: 780)
        .tint(Theme.fujiAmber)
    }
    
    private static func renderWindow<V: View>(_ view: V, to url: URL, size: CGSize) {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: size)
        
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
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

// Static snapshot sidebar avoiding dynamic ScrollView clipping during offscreen render
private struct SidebarStaticView: View {
    let selection: AppTab
    let recipeStore: RecipeStore
    let cameraManager: CameraManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Brand header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.22), Color(white: 0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(Theme.specularBorder, lineWidth: 1))

                    Circle()
                        .stroke(Theme.fujiRed, lineWidth: 1.5)
                        .frame(width: 12, height: 12)

                    Image(systemName: "camera.aperture")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.titaniumMist)
                }
                .shadow(color: Color.black.opacity(0.4), radius: 6, y: 3)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text("FUJIRECIPES")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .tracking(0.4)

                        Text("PRO")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Theme.fujiAmber)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Theme.fujiAmber.opacity(0.18))
                            .clipShape(Capsule())
                    }

                    Text("X100VI STUDIO")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Navigation items
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 3) {
                    ForEach(AppTab.allCases) { tab in
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(selection == tab ? tab.accentColor : Color.white.opacity(0.04))
                                    .frame(width: 26, height: 26)

                                Image(systemName: tab.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(selection == tab ? (tab.accentColor == Theme.fujiAmber ? Color.black : Color.white) : Theme.textSecondary)
                            }

                            Text(tab.title)
                                .font(.subheadline.weight(selection == tab ? .semibold : .regular))
                                .foregroundStyle(selection == tab ? Color.white : Theme.textSecondary)

                            Spacer(minLength: 0)

                            if let badge = tabBadge(for: tab) {
                                Text(badge)
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(selection == tab ? Color.black : Theme.fujiAmber)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(selection == tab ? Color.white : Theme.fujiAmber.opacity(0.18)))
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(selection == tab ? Color.white.opacity(0.12) : Color.clear)
                        )
                    }
                }

                // Film Sim shortcuts
                VStack(alignment: .leading, spacing: 6) {
                    Text("FILM SIMULATIONS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, 10)

                    VStack(spacing: 2) {
                        staticSimRow(title: "All Simulations", color: Theme.fujiAmber, count: 22)
                        staticSimRow(title: "Classic Chrome", color: Theme.filmSimColor(for: "Classic Chrome"))
                        staticSimRow(title: "Reala Ace", color: Theme.filmSimColor(for: "Reala Ace"))
                        staticSimRow(title: "Classic Negative", color: Theme.filmSimColor(for: "Classic Negative"))
                        staticSimRow(title: "Velvia", color: Theme.filmSimColor(for: "Velvia"))
                        staticSimRow(title: "Acros / Monochrome", color: Theme.filmSimColor(for: "Acros"))
                    }
                }

                // Dial Bank Mini
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("CUSTOM DIAL BANK")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.textTertiary)
                        Spacer()
                        Text("\(recipeStore.loadouts.loadoutCountWithSettings())/7")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.fujiAmber)
                    }
                    .padding(.horizontal, 10)

                    HStack(spacing: 3) {
                        ForEach(1...7, id: \.self) { slot in
                            let hasSetting = recipeStore.loadouts.loadout(for: slot)?.hasAnySettings ?? false
                            VStack(spacing: 1) {
                                Text("C\(slot)")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(hasSetting ? Color.black : Theme.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(hasSetting ? Theme.fujiAmber : Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .stroke(hasSetting ? Theme.fujiAmber.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 0.8)
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 0)

            // Status footer
            HStack(spacing: 8) {
                Circle()
                    .fill(cameraManager.status.tint)
                    .frame(width: 7, height: 7)
                    .shadow(color: cameraManager.status.tint.opacity(0.8), radius: 3)

                VStack(alignment: .leading, spacing: 1) {
                    Text(cameraManager.status.formattedLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("X100VI USB RAW")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(5)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
            )
        }
        .frame(width: 250)
        .background(Theme.deepCharcoal.opacity(0.95))
    }

    private func tabBadge(for tab: AppTab) -> String? {
        switch tab {
        case .recipes:
            let favs = recipeStore.favorites.favoriteIDs.count
            return favs > 0 ? "\(favs) ★" : nil
        case .loadouts:
            let count = recipeStore.loadouts.loadoutCountWithSettings()
            return count > 0 ? "\(count)/7" : nil
        case .camera:
            return cameraManager.status == .connected ? "ONLINE" : nil
        case .darkroom:
            return nil
        }
    }

    private func staticSimRow(title: String, color: Color, count: Int? = nil) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(title)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)

            Spacer()

            if let count {
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
