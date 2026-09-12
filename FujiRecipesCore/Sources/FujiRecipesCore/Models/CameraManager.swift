import Foundation

/// Protocol-based camera manager that works with any PTPClientProtocol implementation.
/// macOS uses MacOSSession, iOS uses IOSSession.
@MainActor
public final class CameraManager: ObservableObject {
    public init() {}

    @Published public private(set) var status: CameraStatus = .disconnected
    @Published public private(set) var cameraInfo: PTPCameraInfo?
    @Published public private(set) var activeSettings: [String: AnyHashable]?
    @Published public var lastError: String?

    private var client: PTPClientProtocol?

    // MARK: - Connection

    public func connect(using session: PTPClientProtocol, loadouts: LoadoutStore? = nil) async {
        guard status == .disconnected else { return }

        DebugLogger.info("CameraManager.connect() called", category: .camera)
        status = .connecting
        lastError = nil
        client = session

        do {
            try await withTimeout(timeout: 15.0) {
                try await session.connect()
            }

            let info = session.cameraInfo
            self.cameraInfo = PTPCameraInfo(
                model: info.model,
                vendorExtensionId: info.vendorExtensionId
            )
            status = .connected

            // Active settings can fail for properties not supported in the current
            // USB mode; don't let that fail the whole connection.
            await readActiveSettings()

            // Auto-sync C-states from camera, but do not clobber local names if
            // the camera read fails for a slot.
            DebugLogger.info("Auto-reading C-States from camera...", category: .camera)
            let presetData = await readCStates()
            DebugLogger.info("Read \(presetData.count) C-States", category: .camera)

            if let loadouts = loadouts {
                loadouts.syncFromCameraPresetData(presetData)
            }
        } catch {
            status = .error
            lastError = error.localizedDescription
            client = nil
        }
    }

    public func disconnect() {
        client?.disconnect()
        client = nil
        status = .disconnected
        cameraInfo = nil
        activeSettings = nil
    }

    // MARK: - Active Settings

    public func readActiveSettings() async {
        guard let client = client, client.isConnected else { return }
        let settings = await readAllActiveSettings()
        self.activeSettings = settings
    }

    // MARK: - Read C-States

    public func readCStates() async -> [PTPClientPresetData] {
        guard let client = client, client.isConnected else { return [] }

        var presetData: [PTPClientPresetData] = []

        for slot in 1...7 {
            do {
                let data = try await client.readPresetSlot(slot)
                presetData.append(data)
            } catch {
                DebugLogger.warning("Failed to read preset slot \(slot): \(error.localizedDescription)", category: .camera)
                // Preserve the slot ordering but do not fabricate empty data that
                // would overwrite locally-stored names/settings.
            }
        }

        return presetData
    }

    // MARK: - Import Recipe to C-State

    public func importRecipeToCState(_ recipe: Recipe, slot: Int) async throws {
        guard let client = client, client.isConnected else {
            throw CameraError.notConnected
        }
        guard (1...7).contains(slot) else {
            throw PTPError.invalidResponse("Preset slot must be 1–7")
        }

        let presetData = PTPClientPresetData(
            slot: slot,
            name: recipe.name,
            imageQuality: nil,
            dynamicRange: recipe.dynamicRange?.rawValue,
            filmSimulation: recipe.filmSimulation?.rawValue,
            grainEffect: recipe.grainEffect?.rawValue,
            colorChrome: recipe.colorChrome?.rawValue,
            colorChromeFxBlue: recipe.colorChromeFxBlue?.rawValue,
            smoothSkin: recipe.smoothSkin?.rawValue,
            whiteBalance: recipe.whiteBalanceMode?.actualPTPValue,
            wbShiftRed: recipe.wbShiftRed,
            wbShiftBlue: recipe.wbShiftBlue,
            colorTemp: recipe.colorTempK,
            highlight: recipe.highlight,
            shadow: recipe.shadow,
            color: recipe.color,
            sharpness: recipe.sharpness,
            clarity: recipe.clarity,
            longExpNr: recipe.highIsoNr.map { UInt32($0) },
            colorSpace: nil
        )

        try await client.writePresetSlot(slot, data: presetData)
    }

    // MARK: - Write Loadout

    public func writeLoadout(_ loadout: Loadout, to slot: Int) async throws {
        guard let client = client, client.isConnected else {
            throw CameraError.notConnected
        }
        guard (1...7).contains(slot) else {
            throw PTPError.invalidResponse("Preset slot must be 1–7")
        }

        let presetData = PTPClientPresetData(
            slot: slot,
            name: loadout.name,
            dynamicRange: loadout.dr?.rawValue,
            filmSimulation: loadout.filmSim?.rawValue,
            grainEffect: loadout.grain?.rawValue,
            whiteBalance: loadout.wb?.actualPTPValue,
            highlight: loadout.highlight,
            shadow: loadout.shadow,
            color: loadout.color,
            sharpness: loadout.sharpness
        )

        try await client.writePresetSlot(slot, data: presetData)
    }

    // MARK: - RAF Conversion

    public func convertRAF(_ raf: RAFFile, profileModifier: ((inout Data) -> Void)? = nil) async throws -> JPEGFile? {
        guard let client = client, client.isConnected else {
            throw CameraError.notConnected
        }
        // Profile modification is intentionally unsupported for the X100VI pipeline.
        _ = profileModifier
        return try await client.convertRAF(raf, profileModifier: nil)
    }

    public func capturePreview() async throws -> JPEGFile? {
        guard let client = client, client.isConnected else {
            throw CameraError.notConnected
        }
        return try await client.capturePreview()
    }

    // MARK: - Helpers

    private func readAllActiveSettings() async -> [String: AnyHashable] {
        guard let client = client else { return [:] }

        var settings: [String: AnyHashable] = [:]

        let propertyCodes: [String: UInt16] = [
            "FilmSim": 0xD001, "Color": 0xD002, "DR": 0xD007,
            "WB": 0x5005, "WBRed": 0xD00B, "WBBlue": 0xD00C,
            "ColorTemp": 0xD017, "HighIsoNr": 0xD01C,
            "Grain": 0xD023, "Highlight": 0xD320, "Shadow": 0xD321,
            "ISO": 0x500F, "Sharpness": 0x5015, "ExpoComp": 0x5010
        ]

        for (name, code) in propertyCodes {
            do {
                let response = try await client.readProperty(code)
                switch response {
                case .uint32(let value):
                    settings[name] = value as AnyHashable
                case .int32(let value):
                    settings[name] = value as AnyHashable
                case .string(let value):
                    settings[name] = value as AnyHashable
                case .data(let data):
                    settings[name] = data as AnyHashable
                case .unsupported, .error:
                    DebugLogger.debug("Property 0x\(String(code, radix: 16)) unsupported or errored", category: .camera)
                }
            } catch {
                DebugLogger.debug("Property 0x\(String(code, radix: 16)) read failed: \(error.localizedDescription)", category: .camera)
            }
        }

        return settings
    }
}

// MARK: - Camera Status

public enum CameraStatus: String, Sendable {
    case disconnected
    case connecting
    case connected
    case error
}

// MARK: - Camera Error

public enum CameraError: Error, LocalizedError {
    case notConnected

    public var errorDescription: String? {
        "Camera not connected. Connect via USB-C to continue."
    }
}
