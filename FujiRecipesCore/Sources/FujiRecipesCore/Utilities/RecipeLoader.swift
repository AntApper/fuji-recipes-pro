import Foundation

// MARK: - JSON Data Model

/// Top-level structure of `recipes-data.json`.
public struct RecipesData: Codable, Sendable {
    public let version: String
    public let exportDate: String
    public let camera: CameraInfo
    public let filmSimulationEnum: [String: Int]
    public let wbModeEnum: [String: Int]
    public let dynamicRangeEnum: [String: Int]
    public let grainEffectEnum: [String: Int]
    public let activeProperties: [String: PropertyInfo]
    public let recipes: [RecipeJSON]
}

public struct CameraInfo: Codable, Sendable {
    public let model: String
    public let sensorGeneration: String
}

public struct PropertyInfo: Codable, Sendable {
    public let property: String
    public let type: String
    public let description: String
}

public struct RecipeJSON: Codable, Sendable {
    public let id: String
    public let name: String
    public let sensorGeneration: String
    public let filmSimulation: String?
    public let filmSimEnum: Int?
    public let settings: [String: String]
    public let ptpSettings: [String: Double]
    public let presetSettings: [String: Double]
    public let sourceUrl: String?
    public let previewImageUrl: String?
    public let imageUrls: [String]?
    public let date: String?
    public let compatibleCameras: [String]?

    public init(
        id: String,
        name: String,
        sensorGeneration: String,
        filmSimulation: String?,
        filmSimEnum: Int?,
        settings: [String: String],
        ptpSettings: [String: Double],
        presetSettings: [String: Double],
        sourceUrl: String?,
        previewImageUrl: String?,
        imageUrls: [String]?,
        date: String?,
        compatibleCameras: [String]?
    ) {
        self.id = id
        self.name = name
        self.sensorGeneration = sensorGeneration
        self.filmSimulation = filmSimulation
        self.filmSimEnum = filmSimEnum
        self.settings = settings
        self.ptpSettings = ptpSettings
        self.presetSettings = presetSettings
        self.sourceUrl = sourceUrl
        self.previewImageUrl = previewImageUrl
        self.imageUrls = imageUrls
        self.date = date
        self.compatibleCameras = compatibleCameras
    }
}

// MARK: - Recipe Loader

/// Shared recipe loading logic.  Both the macOS and iOS app targets parse
/// the same `recipes-data.json` schema, so the parsing code lives here.
public enum RecipeLoader {
    /// Load recipes from `recipes-data.json` in the given bundle.
    /// - Returns: Recipes sorted by film-simulation display name, then recipe name.
    public static func loadRecipes(from bundle: Bundle) throws -> [Recipe] {
        guard let url = bundle.url(forResource: "recipes-data", withExtension: "json") else {
            throw RecipeLoaderError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        let json = try JSONDecoder().decode(RecipesData.self, from: data)

        let parsed = json.recipes
            .filter { recipe in
                recipe.sensorGeneration == "X-Trans V" &&
                (recipe.compatibleCameras ?? []).contains("X100VI")
            }
            .map { jsonRecipe -> Recipe in
                let filmSim: FilmSimulation? = {
                    guard let enumInt = jsonRecipe.filmSimEnum,
                          let enumVal = FilmSimulation(rawValue: UInt32(enumInt)) else {
                        return nil
                    }
                    return enumVal
                }()

                let dr: DynamicRange? = {
                    guard let rawVal = jsonRecipe.ptpSettings["dynamicRange"],
                          let enumVal = DynamicRange(rawValue: UInt32(rawVal)) else {
                        return nil
                    }
                    return enumVal
                }()

                let grain: GrainEffect? = {
                    guard let val = jsonRecipe.ptpSettings["grainEffect"],
                          let enumVal = GrainEffect(rawValue: UInt32(val)) else {
                        return nil
                    }
                    return enumVal
                }()

                let wb: WhiteBalanceMode? = {
                    guard let rawVal = jsonRecipe.ptpSettings["whiteBalance"],
                          let enumVal = WhiteBalanceMode(rawValue: UInt32(rawVal)) else {
                        return nil
                    }
                    return enumVal
                }()

                return Recipe(
                    id: jsonRecipe.id,
                    name: jsonRecipe.name,
                    source: "Fuji X Weekly",
                    sourceUrl: jsonRecipe.sourceUrl,
                    previewImageUrl: jsonRecipe.previewImageUrl,
                    imageUrls: jsonRecipe.imageUrls,
                    date: nil,
                    dateString: jsonRecipe.date,
                    filmSimulation: filmSim,
                    dynamicRange: dr,
                    grainEffect: grain,
                    colorChrome: nil,
                    colorChromeFxBlue: nil,
                    smoothSkin: nil,
                    whiteBalanceMode: wb,
                    wbShiftRed: jsonRecipe.ptpSettings["wbShiftRed"]?.int32Value,
                    wbShiftBlue: jsonRecipe.ptpSettings["wbShiftBlue"]?.int32Value,
                    colorTempK: nil,
                    highlight: jsonRecipe.ptpSettings["highlight"]?.int32Value,
                    shadow: jsonRecipe.ptpSettings["shadow"]?.int32Value,
                    color: jsonRecipe.ptpSettings["color"]?.int32Value,
                    sharpness: jsonRecipe.ptpSettings["sharpness"]?.int32Value,
                    highIsoNr: jsonRecipe.ptpSettings["highIsoNr"]?.int32Value,
                    clarity: nil,
                    iso: jsonRecipe.settings["iso"],
                    exposureCompensation: jsonRecipe.settings["exposureCompensation"],
                    settings: jsonRecipe.settings,
                    sensorGeneration: jsonRecipe.sensorGeneration,
                    compatibleCameras: jsonRecipe.compatibleCameras,
                    tags: jsonRecipe.filmSimulation.map { [$0] } ?? [],
                    parseStatus: .ok
                )
            }

        return parsed.sorted { lhs, rhs in
            let lhsName = lhs.filmSimulation?.displayName.lowercased() ?? ""
            let rhsName = rhs.filmSimulation?.displayName.lowercased() ?? ""
            if lhsName != rhsName { return lhsName < rhsName }
            return lhs.name.lowercased() < rhs.name.lowercased()
        }
    }
}

// MARK: - Errors

public enum RecipeLoaderError: Error, LocalizedError {
    case fileNotFound

    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "recipes-data.json was not found in the app bundle."
        }
    }
}

// MARK: - Numeric Helpers

extension Double {
    public var intValue: Int { Int(self) }
    public var int32Value: Int32 { Int32(self) }
}
