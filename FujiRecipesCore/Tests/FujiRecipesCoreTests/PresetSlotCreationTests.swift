import XCTest
@testable import FujiRecipesCore

final class PresetSlotCreationTests: XCTestCase {
    func testCameraPresetNameMatchesVerifiedFifteenCharacterLimit() {
        XCTAssertEqual(CameraPresetName.label(for: "C4 PTP VERIFY B"), "C4 PTP VERIFY B")
        XCTAssertEqual(CameraPresetName.label(for: "PRO Negative 160C"), "PRO Negative 16")
        XCTAssertEqual(CameraPresetName.label(for: "Fujicolor 100 Industrial"), "Fujicolor 100 I")
    }

    func testCameraPresetNameNormalizesToSafeASCII() {
        XCTAssertEqual(
            CameraPresetName.label(for: "Ciné—Film\u{00A0}’86"),
            "Cin -Film '86"
        )
    }

    func testCameraPresetNamePayloadMatchesFilmKitPTPEncoding() {
        let label = CameraPresetName.label(for: "PRO Negative 160C")

        XCTAssertEqual(
            Array(CameraPresetName.ptpPayload(forCameraLabel: label)),
            [
                0x10,
                0x50, 0x00, 0x52, 0x00, 0x4F, 0x00, 0x20, 0x00,
                0x4E, 0x00, 0x65, 0x00, 0x67, 0x00, 0x61, 0x00,
                0x74, 0x00, 0x69, 0x00, 0x76, 0x00, 0x65, 0x00,
                0x20, 0x00, 0x31, 0x00, 0x36, 0x00, 0x00, 0x00
            ]
        )
    }

    func testEmptySlotMetadataIsExplicitRatherThanInferredFromName() {
        let unnamedConfiguredSlot = PTPClientPresetData(
            slot: 4,
            name: "",
            filmSimulation: 11
        )
        let neverConfiguredSlot = PTPClientPresetData(
            slot: 4,
            name: "",
            isEmptySlot: true
        )

        XCTAssertFalse(unnamedConfiguredSlot.isEmptySlot)
        XCTAssertTrue(neverConfiguredSlot.isEmptySlot)
    }

    func testCreationResultIsSeparateFromSlotReadState() {
        let creation = PTPPresetSlotWriteResult(slot: 4, createdFromEmpty: true)
        let update = PTPPresetSlotWriteResult(slot: 4)

        XCTAssertTrue(creation.createdFromEmpty)
        XCTAssertFalse(update.createdFromEmpty)
    }

    func testHighISONoiseReductionAndLongExposureNoiseReductionRemainDistinct() {
        let preset = PTPClientPresetData(
            slot: 2,
            highIsoNr: 3,
            longExpNr: 1
        )

        XCTAssertEqual(preset.highIsoNr, 3)
        XCTAssertEqual(preset.longExpNr, 1)
    }

    func testWriteResultRetainsNonFatalWarnings() {
        let result = PTPPresetSlotWriteResult(
            slot: 6,
            warnings: ["0xD19C: 0x201C"]
        )

        XCTAssertEqual(result.warnings, ["0xD19C: 0x201C"])
    }

    @MainActor
    func testCameraManagerMapsHighISONoiseReductionToD1A1Field() async throws {
        let client = RecordingPTPClient()
        let manager = CameraManager()
        await manager.connect(using: client)
        let recipe = Recipe(
            id: "high-iso-nr",
            name: "High ISO NR",
            source: "test",
            sourceUrl: nil,
            highIsoNr: 3
        )

        _ = try await manager.importRecipeToCState(recipe, slot: 1)

        XCTAssertEqual(client.writtenPreset?.highIsoNr, 0x6000)
        XCTAssertNil(client.writtenPreset?.longExpNr)
    }

    @MainActor
    func testCameraManagerRoutesC7ThroughPresetWrite() async throws {
        let client = RecordingPTPClient()
        let manager = CameraManager()
        await manager.connect(using: client)
        let recipe = Recipe(
            id: "c7",
            name: "C7 Recipe",
            source: "test",
            sourceUrl: nil
        )

        _ = try await manager.importRecipeToCState(recipe, slot: 7)

        XCTAssertEqual(client.writtenSlot, 7)
        XCTAssertEqual(client.writtenPreset?.slot, 7)
        XCTAssertEqual(client.writtenPreset?.name, "C7 Recipe")
    }

    @MainActor
    func testCameraManagerUsesCameraSafePresetLabel() async throws {
        let client = RecordingPTPClient()
        let manager = CameraManager()
        await manager.connect(using: client)
        let recipe = Recipe(
            id: "long-name",
            name: "PRO Negative 160C",
            source: "test",
            sourceUrl: nil
        )

        _ = try await manager.importRecipeToCState(recipe, slot: 4)

        XCTAssertEqual(client.writtenPreset?.name, "PRO Negative 16")
    }

    @MainActor
    func testCameraManagerRejectsSlotsOutsideC1ThroughC7() async {
        let client = RecordingPTPClient()
        let manager = CameraManager()
        await manager.connect(using: client)
        let recipe = Recipe(
            id: "invalid-slot",
            name: "Invalid",
            source: "test",
            sourceUrl: nil
        )

        do {
            _ = try await manager.importRecipeToCState(recipe, slot: 8)
            XCTFail("Expected an invalid C-slot error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Invalid response: Preset slot must be 1–7")
        }

        XCTAssertNil(client.writtenPreset)
    }
}

private final class RecordingPTPClient: PTPClientProtocol, @unchecked Sendable {
    var isConnected = false
    var cameraInfo = PTPCameraInfo(model: "Test Camera")
    var writtenPreset: PTPClientPresetData?
    var writtenSlot: Int?

    func connect() async throws { isConnected = true }
    func disconnect() { isConnected = false }
    func readProperty(_ code: UInt16) async throws -> PTPPropertyResponse { .unsupported }
    func writeProperty(_ code: UInt16, value: Int32) async throws {}
    func readPresetSlot(_ index: Int) async throws -> PTPClientPresetData {
        PTPClientPresetData(slot: index)
    }
    func writePresetSlot(_ index: Int, data: PTPClientPresetData) async throws -> PTPPresetSlotWriteResult {
        writtenSlot = index
        writtenPreset = data
        return PTPPresetSlotWriteResult(slot: index)
    }
    func readNativeProfile() async throws -> Data { Data() }
    func writePTPSettings(from recipe: Recipe) async throws {}
    func convertRAF(_ raf: RAFFile, profileModifier: ((inout Data) -> Void)?) async throws -> JPEGFile? { nil }
    func capturePreview() async throws -> JPEGFile? { nil }
}
