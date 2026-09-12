import SwiftUI
import FujiRecipesCore

// MARK: - Loadouts View

struct LoadoutsView: View {
    @ObservedObject var loadouts: LoadoutStore
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Preset Slots (C1–C7)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Text("\(loadouts.loadoutCountWithSettings())/7 slots configured")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                ], spacing: 12) {
                    ForEach((1...7).map { Loadout(slot: $0, name: "C\($0)") }) { emptySlot in
                        if let loadout = loadouts.loadout(for: emptySlot.slot) {
                            LoadoutCard(loadout: loadout, loadouts: loadouts)
                        } else {
                            EmptyLoadoutCard(slot: emptySlot.slot)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("C1-C7 Loadouts")
    }
}

// MARK: - Loadout Card

struct LoadoutCard: View {
    let loadout: Loadout
    @ObservedObject var loadouts: LoadoutStore
    
    private var slotColor: Color {
        switch loadout.slot {
        case 1: return .blue
        case 2: return .green
        case 3: return .orange
        case 4: return .purple
        case 5: return .pink
        case 6: return .cyan
        case 7: return .indigo
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "square.grid.2x2")
                    .foregroundStyle(slotColor)
                    .font(.title3)
                Text(loadout.displayLabel)
                    .font(.headline)
                Spacer()
                Text("\(loadout.settingCount)/8")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                if let fs = loadout.filmSim {
                    settingBadge(fs.displayName, color: slotColor)
                }
                if let dr = loadout.dr {
                    settingBadge(dr.displayName, color: .green)
                }
                if let grain = loadout.grain {
                    settingBadge(grain.displayName, color: .orange)
                }
                if let wb = loadout.wb {
                    settingBadge(wb.displayName, color: .purple)
                }
                if let hl = loadout.highlight {
                    Text("Highlight: \(hl.formatValue)").font(.caption).foregroundStyle(.secondary)
                }
                if let sh = loadout.shadow {
                    Text("Shadow: \(sh.formatValue)").font(.caption).foregroundStyle(.secondary)
                }
                if let c = loadout.color {
                    Text("Color: \(c.formatValue)").font(.caption).foregroundStyle(.secondary)
                }
                if let s = loadout.sharpness {
                    Text("Sharp: \(s.formatValue)").font(.caption).foregroundStyle(.secondary)
                }
                if !loadout.hasAnySettings {
                    Text("No settings").font(.caption).foregroundStyle(.secondary).italic()
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(slotColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func settingBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(4)
    }
}

// MARK: - Empty Loadout Card

struct EmptyLoadoutCard: View {
    let slot: Int
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("C\(slot)")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Empty")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color.gray.opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
