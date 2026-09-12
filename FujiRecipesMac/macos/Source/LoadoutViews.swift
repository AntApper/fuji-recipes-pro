import SwiftUI
import FujiRecipesCore

// MARK: - 2026 C1–C7 Custom Dial Matrix View

public struct LoadoutsView: View {
    @ObservedObject public var loadouts: LoadoutStore
    @State private var slotPendingClear: Int?
    @State private var slotToEdit: Loadout?
    @State private var selectedDialSlot: Int = 1

    private let columns = [
        GridItem(.adaptive(minimum: 270, maximum: 360), spacing: 14)
    ]

    public init(loadouts: LoadoutStore) {
        self.loadouts = loadouts
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header Panel
                headerPanel

                // Interactive Rotary Dial Strip
                rotaryDialStrip

                // Loadout Grid (C1 to C7)
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(1...7, id: \.self) { slot in
                        let loadout = loadouts.loadout(for: slot)
                        LoadoutCard(
                            loadout: loadout,
                            slot: slot,
                            isSelected: selectedDialSlot == slot,
                            onClear: { slotPendingClear = slot },
                            onEdit: { slotToEdit = loadout }
                        )
                    }
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.8), value: loadouts.loadoutCountWithSettings())
            }
            .padding(16)
        }
        .navigationTitle("C1–C7 Preset Dial Matrix")
        .confirmationDialog(
            "Clear Custom Slot?",
            isPresented: Binding(
                get: { slotPendingClear != nil },
                set: { if !$0 { slotPendingClear = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Clear Slot", role: .destructive) {
                if let slot = slotPendingClear {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        loadouts.clearLoadout(for: slot)
                    }
                }
                slotPendingClear = nil
            }
            Button("Cancel", role: .cancel) { slotPendingClear = nil }
        } message: {
            if let slot = slotPendingClear {
                Text("This will remove all custom film recipe parameters from C\(slot).")
            }
        }
        .sheet(item: $slotToEdit) { loadout in
            SlotEditorSheet(loadout: loadout, store: loadouts, isPresented: Binding(
                get: { slotToEdit != nil },
                set: { if !$0 { slotToEdit = nil } }
            ))
        }
    }

    private var headerPanel: some View {
        SectionHeader(
            title: "Custom Dial Bank (C1–C7)",
            subtitle: "Map your favorite recipes to physical camera dial positions C1–C7. Sync directly over USB-C.",
            icon: "dial.low.fill",
            trailingValue: "\(loadouts.loadoutCountWithSettings()) / 7",
            trailingLabel: "SLOTS ARMED",
            accentColor: Theme.fujiAmber
        )
    }

    private var rotaryDialStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text("QUICK DIAL:")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.leading, 4)

                ForEach(1...7, id: \.self) { slot in
                    let loadout = loadouts.loadout(for: slot)
                    let isFilled = loadout?.hasAnySettings ?? false
                    let isSelected = selectedDialSlot == slot
                    let accent = slotAccent(slot)

                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.76)) {
                            selectedDialSlot = slot
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(isFilled ? accent : Color.white.opacity(0.15))
                                .frame(width: 7, height: 7)
                                .shadow(color: isFilled ? accent.opacity(0.8) : Color.clear, radius: 3)
                                .scaleEffect(isSelected ? 1.25 : 1.0)

                            Text("C\(slot)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(isSelected ? Color.black : (isFilled ? Color.white : Theme.textTertiary))

                            if let name = loadout?.recipeName, !name.isEmpty {
                                Text(name)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(isSelected ? Color.black.opacity(0.8) : Theme.textSecondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: 80)
                                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(isSelected ? Theme.fujiAmber : (isFilled ? Color.white.opacity(0.08) : Color.white.opacity(0.03)))
                        )
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Theme.fujiAmber : (isFilled ? accent.opacity(0.4) : Theme.specularBorder), lineWidth: 0.8)
                        )
                        .shadow(color: isSelected ? Theme.fujiAmber.opacity(0.35) : Color.clear, radius: 8, y: 2)
                        .scaleEffect(isSelected ? 1.03 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.26, dampingFraction: 0.78), value: isSelected)
                    .animation(.spring(response: 0.26, dampingFraction: 0.78), value: isFilled)
                }
                Spacer(minLength: 4)
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Slot Accent Colors

public func slotAccent(_ slot: Int) -> Color {
    switch slot {
    case 1: return Color(red: 0.28, green: 0.65, blue: 0.98) // Reala/Provia Blue
    case 2: return Color(red: 0.98, green: 0.35, blue: 0.45) // Velvia Red
    case 3: return Color(red: 0.48, green: 0.76, blue: 0.65) // Classic Chrome Sage
    case 4: return Color(red: 0.96, green: 0.70, blue: 0.32) // Nostalgic Gold
    case 5: return Color(red: 0.88, green: 0.54, blue: 0.38) // Classic Neg Terracotta
    case 6: return Color(red: 0.24, green: 0.74, blue: 0.70) // Eterna Teal
    case 7: return Color(red: 0.85, green: 0.87, blue: 0.92) // Acros Platinum
    default: return Theme.fujiAmber
    }
}

// MARK: - Loadout Slot Card

public struct LoadoutCard: View {
    public let loadout: Loadout?
    public let slot: Int
    public var isSelected: Bool = false
    public var onClear: () -> Void = {}
    public var onEdit: () -> Void = {}

    @State private var isHovered = false

    private var accent: Color { slotAccent(slot) }
    private var isConfigured: Bool { loadout?.hasAnySettings ?? false }

    public init(
        loadout: Loadout?,
        slot: Int,
        isSelected: Bool = false,
        onClear: @escaping () -> Void = {},
        onEdit: @escaping () -> Void = {}
    ) {
        self.loadout = loadout
        self.slot = slot
        self.isSelected = isSelected
        self.onClear = onClear
        self.onEdit = onEdit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Slot Indicator & Actions
            slotHeader

            Divider()
                .overlay(Theme.specularBorder)
                .padding(.horizontal, 12)

            // Body
            if isConfigured, let loadout {
                configuredBody(loadout)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                emptyBody
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 160)
        .glassCard(
            padding: 0,
            radius: 14,
            tint: isConfigured ? accent.opacity(0.06) : Theme.glassPanelBg,
            borderColor: isSelected ? Theme.fujiAmber : (isConfigured ? accent.opacity(0.4) : nil)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Theme.fujiAmber : Color.clear, lineWidth: 1.5)
        )
        .scaleEffect(isHovered ? 1.012 : (isSelected ? 1.008 : 1.0))
        .shadow(color: isHovered ? accent.opacity(0.25) : (isSelected ? Theme.fujiAmber.opacity(0.2) : Color.clear), radius: 14, y: 5)
        .animation(.spring(response: 0.26, dampingFraction: 0.76), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isConfigured)
        .onHover { isHovered = $0 }
    }

    private var slotHeader: some View {
        HStack(spacing: 8) {
            // Tactile Dial Badge
            HStack(spacing: 5) {
                Circle()
                    .fill(accent)
                    .frame(width: 7, height: 7)
                    .shadow(color: isConfigured ? accent.opacity(0.8) : Color.clear, radius: 4)

                Text("DIAL C\(slot)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(isConfigured ? accent : Theme.textTertiary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(isConfigured ? accent.opacity(0.15) : Color.white.opacity(0.04))
            )

            Spacer()

            if isConfigured {
                HStack(spacing: 5) {
                    Button(action: onEdit) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(5)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                    .help("Edit parameters for C\(slot)")

                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                            .padding(3)
                    }
                    .buttonStyle(.plain)
                    .help("Clear slot C\(slot)")
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            } else {
                Text("EMPTY SLOT")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.textMuted)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func configuredBody(_ loadout: Loadout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Recipe Title
            Text(loadout.recipeName ?? loadout.name)
                .font(.system(size: 14, weight: .bold))
                .glassPrimary()
                .lineLimit(1)

            // Film Sim Badge + Dynamic Range
            HStack(spacing: 5) {
                if let fs = loadout.filmSim {
                    FilmSimBadge(name: fs.displayName, isCompact: true)
                }

                if let dr = loadout.dr {
                    Text("DR\(dr.rawValue)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.emeraldGreen)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.emeraldGreen.opacity(0.15))
                        .clipShape(Capsule())
                }

                if let wb = loadout.wb {
                    Text(wb.displayName)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Theme.cyanAccent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.cyanAccent.opacity(0.12))
                        .clipShape(Capsule())
                        .lineLimit(1)
                }
            }

            // Tone Radar
            ToneCurveRadar(
                highlight: loadout.highlight,
                shadow: loadout.shadow,
                color: loadout.color,
                sharpness: loadout.sharpness,
                accentColor: accent
            )

            Spacer(minLength: 2)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var emptyBody: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "dial.low")
                    .font(.body)
                    .foregroundStyle(Theme.textTertiary)
                Text("Slot Unassigned")
                    .font(.caption.weight(.semibold))
                    .glassSecondary()
            }
            Text("Choose any recipe from the Recipes tab and click “Send to Dial”.")
                .font(.caption2)
                .glassTertiary()
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - In-Place Slot Parameter Editor Sheet

public struct SlotEditorSheet: View {
    @State public var loadout: Loadout
    @ObservedObject public var store: LoadoutStore
    @Binding public var isPresented: Bool

    @State private var selectedFilmSim: FilmSimulation?
    @State private var selectedDR: DynamicRange?
    @State private var highlight: Int32 = 0
    @State private var shadow: Int32 = 0
    @State private var color: Int32 = 0
    @State private var sharpness: Int32 = 0

    public init(loadout: Loadout, store: LoadoutStore, isPresented: Binding<Bool>) {
        self._loadout = State(initialValue: loadout)
        self.store = store
        self._isPresented = isPresented
        self._selectedFilmSim = State(initialValue: loadout.filmSim)
        self._selectedDR = State(initialValue: loadout.dr)
        self._highlight = State(initialValue: loadout.highlight ?? 0)
        self._shadow = State(initialValue: loadout.shadow ?? 0)
        self._color = State(initialValue: loadout.color ?? 0)
        self._sharpness = State(initialValue: loadout.sharpness ?? 0)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Theme.obsidianBlack.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(
                            title: "Edit Custom Slot C\(loadout.slot)",
                            subtitle: "Adjust film simulation curve and color shifts for this dial position.",
                            icon: "slider.horizontal.3",
                            accentColor: slotAccent(loadout.slot)
                        )

                        // Film Simulation Selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("FILM SIMULATION")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.textTertiary)

                            Picker("Film Sim", selection: $selectedFilmSim) {
                                Text("None").tag(Optional<FilmSimulation>.none)
                                ForEach(FilmSimulation.allCases, id: \.self) { sim in
                                    Text(sim.displayName).tag(Optional(sim))
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(6)
                            .glassCard(padding: 4, radius: 10)
                        }

                        // Tone Offset Sliders
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TONE & DETAIL OFFSETS")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Theme.textTertiary)

                            stepperRow(title: "Highlight Tone", value: $highlight)
                            stepperRow(title: "Shadow Tone", value: $shadow)
                            stepperRow(title: "Color Saturation", value: $color)
                            stepperRow(title: "Sharpness", value: $sharpness)
                        }
                        .glassCard()
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Slot C\(loadout.slot) Configuration")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Changes") {
                        saveChanges()
                        isPresented = false
                    }
                    .buttonStyle(GlassProminentButtonStyle(color: Theme.fujiAmber, height: 30))
                }
            }
        }
        .frame(minWidth: 440, minHeight: 400)
    }

    private func stepperRow(title: String, value: Binding<Int32>) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .glassPrimary()
            Spacer()
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        if value.wrappedValue > -4 { value.wrappedValue -= 1 }
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)

                Text(value.wrappedValue.formatValue)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(value.wrappedValue == 0 ? Theme.textTertiary : (value.wrappedValue > 0 ? Theme.fujiAmber : Theme.cyanAccent))
                    .frame(width: 36)
                    .contentTransition(.numericText())

                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                        if value.wrappedValue < 4 { value.wrappedValue += 1 }
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func saveChanges() {
        let slot = loadout.slot
        if let sim = selectedFilmSim {
            store.setFilmSim(for: slot, filmSim: sim)
        }
        store.setHighlight(for: slot, highlight: highlight)
        store.setShadow(for: slot, shadow: shadow)
        store.setColor(for: slot, color: color)
        store.setSharpness(for: slot, sharpness: sharpness)
    }
}
