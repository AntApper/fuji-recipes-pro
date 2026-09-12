import SwiftUI
import FujiRecipesCore

// MARK: - 2026 Sleek Recipe Gallery & Cards View

public struct RecipeListView: View {
    @ObservedObject public var store: RecipeStore
    @State private var expandedRecipeIDs: Set<Recipe.ID> = []
    @State private var recipeToLoad: Recipe?
    @State private var showLoadToSlot = false
    @State private var selectedPhotoUrl: String? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 540), spacing: 14)
    ]

    public init(store: RecipeStore) {
        self.store = store
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Sleek Floating Control Header
                headerControlBar

                // Filter & Sort Pills
                filterAndSortBar

                // Recipe Cards Grid
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(store.filteredRecipes) { recipe in
                        RecipeCard(
                            recipe: recipe,
                            isExpanded: expandedRecipeIDs.contains(recipe.id),
                            favorites: store.favorites,
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                                    if expandedRecipeIDs.contains(recipe.id) {
                                        expandedRecipeIDs.remove(recipe.id)
                                    } else {
                                        expandedRecipeIDs.insert(recipe.id)
                                    }
                                }
                            },
                            onLoadToSlot: {
                                recipeToLoad = recipe
                                showLoadToSlot = true
                            },
                            onSelectPhoto: { url in
                                selectedPhotoUrl = url
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.94)).combined(with: .offset(y: 10)),
                            removal: .opacity.combined(with: .scale(scale: 0.96))
                        ))
                    }
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.8), value: store.filteredRecipes.map(\.id))

                if store.filteredRecipes.isEmpty {
                    emptyState
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(16)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: store.filteredRecipes.isEmpty)
        }
        .navigationTitle("Fuji Recipes Studio")
        .searchable(text: $store.searchQuery, placement: .toolbar, prompt: "Search recipes, film sims, Kelvin, tags…")
        .alert("Couldn’t Load Recipes", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button("OK") { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "")
        }
        .confirmationDialog("Load into Camera Custom Slot", isPresented: $showLoadToSlot, titleVisibility: .visible) {
            ForEach(1...7, id: \.self) { slot in
                let current = store.loadouts.loadout(for: slot)
                Button("C\(slot) — \(current?.displayLabel ?? "Empty")") {
                    if let recipe = recipeToLoad {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            store.loadouts.applyRecipe(recipe, to: slot)
                        }
                    }
                }
            }
        } message: {
            if let recipe = recipeToLoad {
                Text("Select dial slot for \"\(recipe.name)\"")
            }
        }
        .sheet(isPresented: Binding(
            get: { selectedPhotoUrl != nil },
            set: { if !$0 { selectedPhotoUrl = nil } }
        )) {
            if let urlStr = selectedPhotoUrl, let url = URL(string: urlStr) {
                PhotoLightboxView(imageUrl: url, isPresented: Binding(
                    get: { selectedPhotoUrl != nil },
                    set: { if !$0 { selectedPhotoUrl = nil } }
                ))
            }
        }
    }

    private var headerControlBar: some View {
        ViewThatFits(in: .horizontal) {
            // Full horizontal layout for spacious windows
            HStack(alignment: .center, spacing: 14) {
                headerTextCluster
                Spacer(minLength: 12)
                headerFilterToggle
            }
            // Vertical stacked layout for compact windows
            VStack(alignment: .leading, spacing: 10) {
                headerTextCluster
                headerFilterToggle
            }
        }
        .glassPanel(padding: 14, radius: Glass.panelRadius, accentColor: Theme.fujiAmber)
    }

    private var headerTextCluster: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text("Recipes Studio")
                    .font(.title2.weight(.bold))
                    .glassPrimary()
                    .lineLimit(1)

                Text("\(store.filteredRecipes.count) RECIPES")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.fujiAmber)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Theme.fujiAmber.opacity(0.16))
                    .clipShape(Capsule())
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: store.filteredRecipes.count)
            }

            Text("Curated Fujifilm X100VI film simulation formulations & custom dial presets.")
                .font(.caption)
                .glassSecondary()
                .lineLimit(2)
        }
    }

    private var headerFilterToggle: some View {
        GlassPillToggle(
            options: [
                (value: Optional<RecipeStore.FilterCategory>.none, label: "All (\(store.recipes.count))"),
                (value: Optional<RecipeStore.FilterCategory>.some(.favorites), label: "★ Favorites (\(store.favorites.favoriteIDs.count))")
            ],
            selection: $store.selectedFilterCategory,
            accentColor: Theme.fujiAmber
        )
    }

    private var filterAndSortBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Film Sim Family Quick Filters
                ForEach(RecipeStore.FilmSimFamily.allCases) { family in
                    let isSelected = store.selectedFilmSimFamily == family
                    let accent = family == .all ? Theme.fujiAmber : Theme.filmSimColor(for: family.rawValue)

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            store.selectedFilmSimFamily = family
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: family.icon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(family.rawValue)
                                .font(.caption.weight(isSelected ? .semibold : .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(isSelected ? Color.black : Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(isSelected ? accent : Color.white.opacity(0.05))
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? accent : Theme.specularBorder, lineWidth: 0.8)
                        )
                        .shadow(color: isSelected ? accent.opacity(0.35) : Color.clear, radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
                }

                Divider()
                    .frame(height: 16)
                    .overlay(Theme.specularBorder)

                // DR Filter
                ForEach(RecipeStore.DRFilter.allCases) { dr in
                    let isSelected = store.selectedDRFilter == dr
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            store.selectedDRFilter = dr
                        }
                    } label: {
                        Text(dr.rawValue)
                            .font(.caption.weight(isSelected ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.black : Theme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(isSelected ? Theme.emeraldGreen : Color.white.opacity(0.04))
                            )
                            .overlay(
                                Capsule().stroke(isSelected ? Theme.emeraldGreen : Theme.specularBorder, lineWidth: 0.8)
                            )
                            .shadow(color: isSelected ? Theme.emeraldGreen.opacity(0.35) : Color.clear, radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
                }

                Spacer(minLength: 4)

                // Sort Order Menu
                Menu {
                    ForEach(RecipeStore.SortOrder.allCases) { order in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                store.sortOrder = order
                            }
                        } label: {
                            HStack {
                                Text(order.rawValue)
                                if store.sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: store.sortOrder.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(store.sortOrder.rawValue)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8))
                    }
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color.white.opacity(0.07))
                    )
                    .overlay(
                        Capsule().stroke(Theme.specularBorder, lineWidth: 0.8)
                    )
                }
                .menuStyle(.borderlessButton)
            }
            .padding(.vertical, 2)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 64, height: 64)
                Image(systemName: emptyIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.fujiAmber.opacity(0.8))
                    .symbolEffect(.bounce, value: store.filteredRecipes.count)
            }

            VStack(spacing: 4) {
                Text(emptyTitle)
                    .font(.headline.weight(.semibold))
                    .glassPrimary()
                Text(emptyMessage)
                    .font(.caption)
                    .glassSecondary()
            }

            if !store.searchQuery.isEmpty || store.selectedFilmSimFamily != .all || store.selectedDRFilter != .all {
                Button("Reset Filters") {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        store.searchQuery = ""
                        store.selectedFilmSimFamily = .all
                        store.selectedDRFilter = .all
                        store.selectedFilterCategory = nil
                    }
                }
                .buttonStyle(GlassBorderedButtonStyle(accentColor: Theme.fujiAmber, height: 32))
                .frame(width: 140)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
        .glassCard(tint: Color.white.opacity(0.02))
    }

    private var emptyIcon: String {
        if !store.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return "magnifyingglass"
        }
        return store.selectedFilterCategory == .favorites ? "star.slash" : "film.stack"
    }

    private var emptyTitle: String {
        if !store.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return "No matching recipes"
        }
        return store.selectedFilterCategory == .favorites ? "No favorites starred" : "No recipes found"
    }

    private var emptyMessage: String {
        if !store.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Try searching for a different film sim, Kelvin value, or tag."
        }
        return store.selectedFilterCategory == .favorites
            ? "Click the star icon on any recipe to add it to your favorites."
            : "Ensure recipes-data.json is loaded."
    }
}

// MARK: - Ultra-Sleek Recipe Card

private struct RecipeCard: View {
    let recipe: Recipe
    let isExpanded: Bool
    @ObservedObject var favorites: FavoritesStore
    let onToggleExpand: () -> Void
    let onLoadToSlot: () -> Void
    let onSelectPhoto: (String) -> Void

    @State private var isHovered = false

    private var isFavorite: Bool {
        favorites.isFavorite(recipe.id)
    }

    private var simName: String {
        recipe.filmSimulation?.displayName ?? recipe.settings?["filmSimulation"] ?? "Custom Sim"
    }

    private var accent: Color {
        Theme.filmSimColor(for: simName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main Card Header
            headerWithActions

            // Expanded Recipe Formula & Details
            if isExpanded {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.98))
                    ))
            }
        }
        .glassCard(
            padding: 0,
            radius: Glass.cardRadius,
            tint: isHovered ? Color.white.opacity(0.07) : Theme.glassPanelBg,
            borderColor: isHovered ? accent.opacity(0.45) : nil
        )
        .overlay(
            // Top Accent Color Ribbon
            RoundedRectangle(cornerRadius: Glass.cardRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [accent.opacity(isHovered ? 0.75 : 0.4), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
                .allowsHitTesting(false)
        )
        .scaleEffect(isHovered ? 1.012 : 1.0)
        .shadow(color: isHovered ? accent.opacity(0.18) : Color.clear, radius: 14, y: 6)
        .animation(.spring(response: 0.26, dampingFraction: 0.76), value: isHovered)
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isExpanded)
        .onHover { isHovered = $0 }
    }

    private var headerWithActions: some View {
        ZStack {
            Button(action: onToggleExpand) {
                cardHeaderContent
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Floating Quick Action Cluster (Load to Slot + Favorite Star + Expand Chevron)
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                
                VStack(spacing: 6) {
                    // Send to C1-C7 button
                    Button(action: onLoadToSlot) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 28, height: 28)
                            Image(systemName: "dial.low.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Theme.fujiAmber)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Load recipe into C1–C7 preset slot")
                    .accessibilityLabel("Load recipe into a custom slot")

                    // Star Favorite Button
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            favorites.toggleFavorite(for: recipe.id)
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(isFavorite ? Theme.warmGold.opacity(0.2) : Color.white.opacity(0.08))
                                .frame(width: 28, height: 28)
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(isFavorite ? Theme.warmGold : Theme.textSecondary)
                                .symbolEffect(.bounce, value: isFavorite)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(isFavorite ? "Remove favorite" : "Add to favorites")
                }

                // Expand Chevron
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(isHovered || isExpanded ? Theme.textPrimary : Theme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isExpanded)
                    .padding(.leading, 1)
            }
            .padding(.trailing, 10)
            .padding(.vertical, 10)
        }
        .frame(minHeight: 110)
    }

    private var cardHeaderContent: some View {
        HStack(alignment: .top, spacing: 12) {
            // Recipe Thumbnail with Film Simulation Overlay
            previewThumbnail

            VStack(alignment: .leading, spacing: 4) {
                // Film Sim Badge + Dynamic Range Chip
                HStack(spacing: 5) {
                    FilmSimBadge(name: simName, isCompact: true)

                    if let dr = recipe.dynamicRange {
                        Text("DR\(dr.rawValue)")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.emeraldGreen)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Theme.emeraldGreen.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                // Recipe Title
                Text(recipe.name)
                    .font(.system(size: 14, weight: .bold))
                    .glassPrimary()
                    .lineLimit(2)

                // Tone Curve Radar & Kelvin Swatch (adaptive horizontal wrapping)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        ToneCurveRadar(
                            highlight: recipe.highlight,
                            shadow: recipe.shadow,
                            color: recipe.color,
                            sharpness: recipe.sharpness,
                            accentColor: accent
                        )

                        KelvinChip(
                            kelvin: recipe.colorTempK,
                            modeName: recipe.whiteBalanceMode?.displayName ?? recipe.settings?["whiteBalance"]
                        )
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        ToneCurveRadar(
                            highlight: recipe.highlight,
                            shadow: recipe.shadow,
                            color: recipe.color,
                            sharpness: recipe.sharpness,
                            accentColor: accent
                        )

                        KelvinChip(
                            kelvin: recipe.colorTempK,
                            modeName: recipe.whiteBalanceMode?.displayName ?? recipe.settings?["whiteBalance"]
                        )
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 72)
        }
        .padding(12)
    }

    private var previewThumbnail: some View {
        Group {
            if let urlString = recipe.previewImageUrl ?? recipe.imageUrls.first,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        thumbnailPlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    case .failure:
                        thumbnailPlaceholder
                    @unknown default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 6, y: 3)
    }

    private var thumbnailPlaceholder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [accent.opacity(0.2), Color.white.opacity(0.04)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "film")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(accent.opacity(0.7))
            )
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(Theme.specularBorder)
                .padding(.horizontal, 12)

            // Sample Photos Carousel
            if !recipe.imageUrls.isEmpty {
                samplePhotosSection
            }

            // Recipe Camera Menu Formula Grid
            formulaGridSection

            // Actions & Links
            ViewThatFits(in: .horizontal) {
                HStack {
                    sourceLink
                    Spacer(minLength: 8)
                    sendToDialButton
                }
                VStack(alignment: .leading, spacing: 8) {
                    sourceLink
                    sendToDialButton
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private var sourceLink: some View {
        if let sourceUrl = recipe.sourceUrl, let url = URL(string: sourceUrl) {
            Link(destination: url) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.up.right.square")
                    Text("Recipe Guide")
                }
                .font(.caption.weight(.medium))
                .lineLimit(1)
            }
            .buttonStyle(.link)
        }
    }

    private var sendToDialButton: some View {
        Button(action: onLoadToSlot) {
            HStack(spacing: 5) {
                Image(systemName: "arrow.right.circle.fill")
                Text("Send to Dial (C1–C7)")
            }
            .font(.caption.weight(.semibold))
            .lineLimit(1)
        }
        .buttonStyle(GlassBorderedButtonStyle(accentColor: Theme.fujiAmber, height: 28))
    }

    private var samplePhotosSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("SAMPLE SHOTS")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                Text("CLICK TO ZOOM")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(.horizontal, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recipe.imageUrls.prefix(8), id: \.self) { urlString in
                        if let url = URL(string: urlString) {
                            SampleThumbnailButton(urlString: urlString, url: url, onSelect: onSelectPhoto)
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }

    private var formulaGridSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CAMERA PARAMETER FORMULA")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 12)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 6)], spacing: 6) {
                ForEach(settingRows, id: \.label) { item in
                    HStack(spacing: 6) {
                        Text(item.label)
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(item.value)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.black.opacity(0.24))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.06), lineWidth: 0.6)
                    )
                }
            }
            .padding(.horizontal, 12)
        }
    }

    private var settingRows: [FormulaSettingItem] {
        var items: [FormulaSettingItem] = []
        let raw = recipe.settings ?? [:]

        func add(_ key: String, display: String) {
            if let val = raw[key], !val.isEmpty {
                items.append(FormulaSettingItem(label: display, value: val))
            }
        }

        add("filmSimulation", display: "Film Sim")
        add("dynamicRange", display: "Dynamic Range")
        add("grainEffect", display: "Grain")
        add("colorChromeEffect", display: "Color Chrome")
        add("colorChromeFxBlue", display: "Chrome FX Blue")
        add("whiteBalance", display: "White Balance")
        if let r = recipe.wbShiftRed, let b = recipe.wbShiftBlue {
            items.append(FormulaSettingItem(label: "WB Shift", value: "R:\(r.formatValue) B:\(b.formatValue)"))
        }
        add("highlight", display: "Highlight")
        add("shadow", display: "Shadow")
        add("color", display: "Color")
        add("sharpness", display: "Sharpness")
        add("highIsoNr", display: "Noise Reduction")
        add("clarity", display: "Clarity")
        add("iso", display: "ISO")
        add("exposureCompensation", display: "Exp. Comp")

        return items
    }
}

private struct SampleThumbnailButton: View {
    let urlString: String
    let url: URL
    let onSelect: (String) -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            onSelect(urlString)
        } label: {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.05))
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.05))
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 120, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(isHovered ? Theme.fujiAmber.opacity(0.6) : Color.white.opacity(0.12), lineWidth: isHovered ? 1.2 : 0.8)
            )
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .shadow(color: isHovered ? Theme.fujiAmber.opacity(0.3) : Color.black.opacity(0.3), radius: isHovered ? 8 : 4, y: 2)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct FormulaSettingItem {
    let label: String
    let value: String
}

// MARK: - Lightbox Image Modal

public struct PhotoLightboxView: View {
    let imageUrl: URL
    @Binding var isPresented: Bool

    public var body: some View {
        ZStack {
            Theme.obsidianBlack.ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .padding()
                }

                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        ProgressView().tint(Theme.fujiAmber)
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: Color.black.opacity(0.6), radius: 24, y: 8)
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                    case .failure:
                        Text("Unable to load full photo").foregroundStyle(Theme.textSecondary)
                    @unknown default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - Formatting helpers

public extension Int32 {
    var formatValue: String {
        if self > 0 { return "+\(self)" }
        return "\(self)"
    }
}
