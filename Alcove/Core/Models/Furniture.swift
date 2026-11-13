import Foundation
import SwiftData

public enum FurnitureCategory: String, Codable, CaseIterable, Sendable {
    case seating
    case table
    case storage
    case bed
    case lighting
    case decor
    case other

    public var icon: String {
        switch self {
        case .seating: return "chair.fill"
        case .table: return "table.furniture.fill"
        case .storage: return "cabinet.fill"
        case .bed: return "bed.double.fill"
        case .lighting: return "lamp.desk.fill"
        case .decor: return "photo.artframe"
        case .other: return "cube.fill"
        }
    }
}

@Model
public final class Furniture {
    public var id: UUID
    public var name: String
    public var categoryRaw: String
    public var positionX: Double
    public var positionY: Double
    public var positionZ: Double
    public var rotationYaw: Double
    public var width: Double
    public var length: Double
    public var height: Double
    public var isArchived: Bool
    public var isUserAdded: Bool = false
    public var assetIdentifier: String?

    public var layout: Layout?

    public var category: FurnitureCategory {
        get { FurnitureCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        category: FurnitureCategory = .other,
        positionX: Double = 0.0,
        positionY: Double = 0.0,
        positionZ: Double = 0.0,
        rotationYaw: Double = 0.0,
        width: Double = 1.0,
        length: Double = 1.0,
        height: Double = 0.8,
        isArchived: Bool = false,
        isUserAdded: Bool = false,
        assetIdentifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.positionX = positionX
        self.positionY = positionY
        self.positionZ = positionZ
        self.rotationYaw = rotationYaw
        self.width = width
        self.length = length
        self.height = height
        self.isArchived = isArchived
        self.isUserAdded = isUserAdded
        self.assetIdentifier = assetIdentifier
    }

    /// Deep copy clone for layout snapshotting
    public func copy() -> Furniture {
        Furniture(
            id: UUID(),
            name: self.name,
            category: self.category,
            positionX: self.positionX,
            positionY: self.positionY,
            positionZ: self.positionZ,
            rotationYaw: self.rotationYaw,
            width: self.width,
            length: self.length,
            height: self.height,
            isArchived: self.isArchived,
            isUserAdded: self.isUserAdded,
            assetIdentifier: self.assetIdentifier
        )
    }
}
