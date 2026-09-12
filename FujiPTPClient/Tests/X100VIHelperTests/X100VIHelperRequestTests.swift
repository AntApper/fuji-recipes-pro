import Foundation
import XCTest
@testable import X100VIHelper
@testable import FujiRecipesCore

final class X100VIHelperRequestTests: XCTestCase {
    func testUniversalNegativeEncoderObjectSerializesToVerifiedHelperRequest() throws {
        // Use the exact production source record selected during C4 validation,
        // not an independently derived request vector.
        let testFile = URL(fileURLWithPath: #filePath)
        let repository = testFile
            .deletingLastPathComponent() // X100VIHelperTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // FujiPTPClient
            .deletingLastPathComponent() // repository root
        let resource = repository
            .appendingPathComponent("FujiRecipesMac/macos/Resources/recipes-data.json")
        let database = try JSONDecoder().decode(RecipesData.self, from: Data(contentsOf: resource))
        let source = try XCTUnwrap(database.recipes.first {
            $0.id == "universal-negative-14-fujifilm-x100vi-x-trans-v-film-simulation-recipes-yes-14"
        })
        let recipe = RecipeLoader.recipe(from: source)
        let preset = try CSlotPresetEncoder.encode(recipe: recipe, slot: 4)

        let params = X100VIHelperClient.presetWriteParameters(index: 4, data: preset)
        let data = try X100VIHelperClient.helperRequestData(
            id: "c4-regression",
            command: "write_preset_slot",
            params: params
        )
        let request = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(request["id"] as? String, "c4-regression")
        XCTAssertEqual(request["command"] as? String, "write_preset_slot")
        XCTAssertEqual(request["index"] as? Int, 4)
        XCTAssertEqual(request["color_chrome_fx_blue"] as? Int, 2, "D197")
        XCTAssertEqual(request["high_iso_nr"] as? Int, 32_768, "D1A1")
    }
}
