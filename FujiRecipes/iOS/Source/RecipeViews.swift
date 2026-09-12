import SwiftUI
import FujiRecipesCore

// MARK: - Recipe Detail View

struct RecipeDetailView: View {
    let recipe: Recipe
    @ObservedObject var favorites: FavoritesStore
    @ObservedObject var loadouts: LoadoutStore
    @State private var showLoadToSlot = false
    
    private var isFavorite: Bool {
        favorites.isFavorite(recipe.id)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                
                Divider()
                
                if let active = recipe.activeSettings {
                    section("Active Settings", icon: "sliders.2.horizontal", content: active)
                }
                
                if let preset = recipe.presetSettings {
                    section("Preset Settings (C1–C7)", icon: "square.grid.2x2", content: preset)
                }
                
                if let notes = recipe.notes {
                    section("Notes & Tips", icon: "info.circle", content: notes)
                }
                
                if let url = recipe.sourceUrl {
                    Link(destination: URL(string: url) ?? URL(fileURLWithPath: "/")) {
                        HStack {
                            Image(systemName: "link.circle")
                            Text("Original article")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding()
        }
        .confirmationDialog("Load to slot", isPresented: $showLoadToSlot, titleVisibility: .visible) {
            ForEach((1...7).map { $0 }, id: \.self) { slot in
                let destination = loadouts.isCameraSlotEmpty(slot)
                    ? "New profile draft"
                    : (loadouts.loadout(for: slot)?.displayLabel ?? "empty")
                Button("C\(slot) — \(destination)") {
                    loadouts.applyRecipe(recipe, to: slot)
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recipe.filmSimulation?.displayName ?? "Recipe")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.accentColor)
                Text(recipe.name)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: { favorites.toggleFavorite(for: recipe.id) }) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(isFavorite ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                Button(action: { showLoadToSlot.toggle() }) {
                    Image(systemName: "square.grid.2x2")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            if let iso = recipe.iso {
                Text(iso)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func section(_ title: String, icon: String, content: [SettingRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(content) { row in
                    settingRow(row)
                }
            }
        }
    }
    
    private func settingRow(_ row: SettingRow) -> some View {
        HStack(spacing: 8) {
            Text(row.label)
                .font(.body)
                .frame(width: 140, alignment: .leading)
            Text(row.value)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            if let ptpCode = row.ptpCode {
                Text(ptpCode)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - Setting Row Model

struct SettingRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let ptpCode: String?
}

// MARK: - Recipe Extensions (computed properties)

extension Recipe {
    var activeSettings: [SettingRow]? {
        var rows: [SettingRow] = []
        if let fs = filmSimulation {
            rows.append(SettingRow(label: "Film Sim", value: fs.displayName, ptpCode: "0xD001"))
        }
        if let dr = dynamicRange {
            rows.append(SettingRow(label: "Dynamic Range", value: dr.displayName, ptpCode: "0xD007"))
        }
        if let grain = grainEffect {
            rows.append(SettingRow(label: "Grain", value: grain.displayName, ptpCode: "0xD023"))
        }
        if let wb = whiteBalanceMode {
            rows.append(SettingRow(label: "White Balance", value: wb.displayName, ptpCode: "0x5005"))
        }
        if let color = color {
            rows.append(SettingRow(label: "Color", value: color.formatValue, ptpCode: "0xD002"))
        }
        if let highlight = highlight {
            rows.append(SettingRow(label: "Highlight", value: highlight.formatValue, ptpCode: "0xD320"))
        }
        if let shadow = shadow {
            rows.append(SettingRow(label: "Shadow", value: shadow.formatValue, ptpCode: "0xD321"))
        }
        if let sharpness = sharpness {
            rows.append(SettingRow(label: "Sharpness", value: sharpness.formatValue, ptpCode: "0x5015"))
        }
        if let isoNr = highIsoNr {
            rows.append(SettingRow(label: "ISO NR", value: isoNr.formatValue, ptpCode: "0xD01C"))
        }
        return rows.isEmpty ? nil : rows
    }
    
    var presetSettings: [SettingRow]? {
        var rows: [SettingRow] = []
        rows.append(SettingRow(label: "Highlight", value: presetHighlightValue, ptpCode: "0xD320"))
        rows.append(SettingRow(label: "Shadow", value: presetShadowValue, ptpCode: "0xD321"))
        if let sharpness = sharpness {
            rows.append(SettingRow(label: "Sharpness", value: sharpness.formatValue, ptpCode: "0x5015"))
        }
        if let clarity = clarity {
            rows.append(SettingRow(label: "Clarity", value: clarity.formatValue, ptpCode: "0xD185"))
        }
        return rows.isEmpty ? nil : rows
    }
    
    var notes: [SettingRow]? {
        var rows: [SettingRow] = []
        if let iso = iso {
            rows.append(SettingRow(label: "ISO", value: iso, ptpCode: nil))
        }
        if let ec = exposureCompensation {
            rows.append(SettingRow(label: "Exposure", value: ec, ptpCode: nil))
        }
        return rows.isEmpty ? nil : rows
    }
    
    private var presetHighlightValue: String {
        if let highlight { return highlight.formatValue }
        return "—"
    }
    
    private var presetShadowValue: String {
        if let shadow { return shadow.formatValue }
        return "—"
    }
}

// MARK: - Int32 Formatting Helpers

extension Int32 {
    var formatValue: String {
        if self > 0 { return "+\(self)" }
        return "\(self)"
    }
}
