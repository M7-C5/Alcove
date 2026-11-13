import Foundation

/// Preset furniture catalog item for Add & Swap workflows in Stage 2.
/// Uses `assetIdentifier` as the future `.usdz` hook while falling back to `ProceduralFurnitureBuilder`.
public struct FurnitureCatalogItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let category: FurnitureCategory
    public let width: Double
    public let length: Double
    public let height: Double
    public let assetIdentifier: String?

    public init(
        id: String,
        name: String,
        category: FurnitureCategory,
        width: Double,
        length: Double,
        height: Double,
        assetIdentifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.width = width
        self.length = length
        self.height = height
        self.assetIdentifier = assetIdentifier
    }

    /// Creates a new `Furniture` model instance from this catalog preset.
    public func makeFurniture(
        positionX: Double = 0.0,
        positionZ: Double = 0.0,
        rotationYaw: Double = 0.0,
        isUserAdded: Bool = true
    ) -> Furniture {
        Furniture(
            name: name,
            category: category,
            positionX: positionX,
            positionY: 0.0,
            positionZ: positionZ,
            rotationYaw: rotationYaw,
            width: width,
            length: length,
            height: height,
            isArchived: false,
            isUserAdded: isUserAdded,
            assetIdentifier: assetIdentifier
        )
    }
}

/// Built-in procedural-first furniture presets sized to match `ProceduralFurnitureBuilder` silhouettes.
public enum FurnitureCatalog {
    public static let presets: [FurnitureCatalogItem] = [
        // Beds
        FurnitureCatalogItem(
            id: "twin_bed",
            name: "Twin Bed",
            category: .bed,
            width: 1.05,
            length: 1.95,
            height: 0.95,
            assetIdentifier: "bed_twin"
        ),
        FurnitureCatalogItem(
            id: "queen_bed",
            name: "Queen Bed",
            category: .bed,
            width: 1.60,
            length: 2.05,
            height: 1.00,
            assetIdentifier: "bed_queen"
        ),
        FurnitureCatalogItem(
            id: "king_bed",
            name: "King Bed",
            category: .bed,
            width: 1.95,
            length: 2.05,
            height: 1.05,
            assetIdentifier: "bed_king"
        ),

        // Tables & Desks
        FurnitureCatalogItem(
            id: "nightstand",
            name: "Nightstand",
            category: .table,
            width: 0.50,
            length: 0.45,
            height: 0.55,
            assetIdentifier: "table_nightstand"
        ),
        FurnitureCatalogItem(
            id: "compact_desk",
            name: "Compact Desk",
            category: .table,
            width: 1.10,
            length: 0.65,
            height: 0.75,
            assetIdentifier: "table_compact_desk"
        ),
        FurnitureCatalogItem(
            id: "study_desk",
            name: "Study Desk",
            category: .table,
            width: 1.45,
            length: 0.75,
            height: 0.76,
            assetIdentifier: "table_study_desk"
        ),

        // Seating
        FurnitureCatalogItem(
            id: "desk_chair",
            name: "Desk Chair",
            category: .seating,
            width: 0.62,
            length: 0.62,
            height: 0.95,
            assetIdentifier: "seating_desk_chair"
        ),
        FurnitureCatalogItem(
            id: "accent_chair",
            name: "Accent Chair",
            category: .seating,
            width: 0.78,
            length: 0.78,
            height: 0.85,
            assetIdentifier: "seating_accent_chair"
        ),

        // Storage
        FurnitureCatalogItem(
            id: "low_dresser",
            name: "Low Dresser",
            category: .storage,
            width: 1.20,
            length: 0.50,
            height: 0.85,
            assetIdentifier: "storage_low_dresser"
        ),
        FurnitureCatalogItem(
            id: "tall_wardrobe",
            name: "Tall Wardrobe",
            category: .storage,
            width: 1.00,
            length: 0.60,
            height: 2.00,
            assetIdentifier: "storage_tall_wardrobe"
        ),

        // Lighting
        FurnitureCatalogItem(
            id: "floor_lamp",
            name: "Floor Lamp",
            category: .lighting,
            width: 0.40,
            length: 0.40,
            height: 1.65,
            assetIdentifier: "lighting_floor_lamp"
        )
    ]

    public static func presets(for category: FurnitureCategory?) -> [FurnitureCatalogItem] {
        guard let category else { return presets }
        return presets.filter { $0.category == category }
    }
}
