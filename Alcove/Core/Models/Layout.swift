import Foundation
import SwiftData

@Model
public final class Layout {
    public var id: UUID
    public var name: String
    public var isBaseline: Bool
    public var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Furniture.layout)
    public var furnitures: [Furniture]

    public var room: Room?

    public init(
        id: UUID = UUID(),
        name: String = "Default Layout",
        isBaseline: Bool = false,
        createdAt: Date = Date(),
        furnitures: [Furniture] = []
    ) {
        self.id = id
        self.name = name
        self.isBaseline = isBaseline
        self.createdAt = createdAt
        self.furnitures = furnitures
    }

    /// Creates a deep copy of this layout
    public func createCopy(name: String, isBaseline: Bool = false) -> Layout {
        let clonedFurnitures = furnitures.map { $0.copy() }
        return Layout(
            id: UUID(),
            name: name,
            isBaseline: isBaseline,
            createdAt: Date(),
            furnitures: clonedFurnitures
        )
    }
}
