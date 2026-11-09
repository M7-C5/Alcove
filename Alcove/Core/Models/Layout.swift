import Foundation
import SwiftData

@Model
public final class Layout {
    public var id: UUID
    public var name: String
    public var isBaseline: Bool
    public var createdAt: Date
    public var lightFixturesData: Data?

    @Relationship(deleteRule: .cascade, inverse: \Furniture.layout)
    public var furnitures: [Furniture]

    public var room: Room?

    public var lightFixtures: [LightFixture] {
        get {
            guard let data = lightFixturesData else { return [] }
            return (try? JSONDecoder().decode([LightFixture].self, from: data)) ?? []
        }
        set {
            lightFixturesData = try? JSONEncoder().encode(newValue)
        }
    }

    public init(
        id: UUID = UUID(),
        name: String = "Default Layout",
        isBaseline: Bool = false,
        createdAt: Date = Date(),
        furnitures: [Furniture] = [],
        lightFixtures: [LightFixture] = []
    ) {
        self.id = id
        self.name = name
        self.isBaseline = isBaseline
        self.createdAt = createdAt
        self.furnitures = furnitures
        if !lightFixtures.isEmpty {
            self.lightFixturesData = try? JSONEncoder().encode(lightFixtures)
        }
    }

    /// Creates a deep copy of this layout
    public func createCopy(name: String, isBaseline: Bool = false) -> Layout {
        let clonedFurnitures = furnitures.map { $0.copy() }
        let layoutCopy = Layout(
            id: UUID(),
            name: name,
            isBaseline: isBaseline,
            createdAt: Date(),
            furnitures: clonedFurnitures
        )
        layoutCopy.lightFixturesData = self.lightFixturesData
        return layoutCopy
    }
}
