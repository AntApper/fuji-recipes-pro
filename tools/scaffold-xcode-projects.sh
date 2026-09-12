#!/bin/bash
# scaffold-xcode-projects.sh
# Creates Xcode project files for FujiRecipes iOS and macOS apps.
# Run from the project root: bash tools/scaffold-xcode-projects.sh

set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "Scaffolding Xcode projects in: $PROJECT_ROOT"

# Create directory structure
mkdir -p "$PROJECT_ROOT/FujiRecipes/iOS/Source"
mkdir -p "$PROJECT_ROOT/FujiRecipesMac/macos/Source"

# ──────────────────────────────────────────────
# iOS App — use `swift package` to generate a
# minimal Xcode-compatible project layout, then
# we manually write the .xcodeproj.
# ──────────────────────────────────────────────

echo "✦ Creating iOS Xcode project..."

# Create the iOS app entry point
cat > "$PROJECT_ROOT/FujiRecipes/iOS/Source/App.swift" << 'EOFSWIFT'
import SwiftUI
import FujiRecipesCore
import FujiPTPClient

@main
struct FujiRecipesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 60))
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(.orange, .yellow)

                Text("Fuji Recipes")
                    .font(.title)
                    .fontWeight(.bold)

                Text("X100VI Recipe Manager")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                Button {
                    // TODO: connect to camera
                } label: {
                    Label("Connect Camera", systemImage: "lightning.bolt.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Divider()

                Text("Scaffolded — add recipe views")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
}
EOFSWIFT

# ──────────────────────────────────────────────
# macOS App
# ──────────────────────────────────────────────

echo "✦ Creating macOS Xcode project..."

cat > "$PROJECT_ROOT/FujiRecipesMac/macos/Source/App.swift" << 'EOFSWIFT'
import SwiftUI
import FujiRecipesCore
import FujiPTPClient

@main
struct FujiRecipesMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var searchText = ""
    @State private var selectedRecipe: String? = nil

    var body: some View {
        NavigationSplitView {
            List {
                Section("Recipes") {
                    ForEach(0..<3) { i in
                        Label("Recipe \(i + 1)", systemImage: "film")
                            .tag(i)
                            .listRowSeparator(.visible)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search recipes")
            .navigationTitle("Fuji Recipes")
        } detail: {
            Text(selectedRecipe == nil
                 ? "Select a recipe"
                 : "Recipe detail view")
                .font(.title2)
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}
EOFSWIFT

echo "✅ iOS and macOS app source files created."
echo ""
echo "Next steps:"
echo "  1. Open Xcode → File → New → Project"
echo "  2. Choose iOS or macOS template"
echo "  3. Add this project to the workspace"
echo "  4. Add FujiRecipesCore and FujiPTPClient as package dependencies"
echo "  5. Point source files to the .swift files created above"
echo ""
echo "Alternatively, run the Xcode project generator:"
echo "  python3 tools/generate-xcode-projects.py"
