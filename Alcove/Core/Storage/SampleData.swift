import Foundation
import SwiftData

public enum SampleData {
    public static func createStarterRoom() -> Room {
        let baselineFurnitures = [
            Furniture(
                name: "Queen Bed",
                category: .bed,
                positionX: -1.2,
                positionY: 0.0,
                positionZ: -1.5,
                rotationYaw: 0.0,
                width: 1.6,
                length: 2.1,
                height: 0.9
            ),
            Furniture(
                name: "Work Desk",
                category: .table,
                positionX: 1.3,
                positionY: 0.0,
                positionZ: -1.0,
                rotationYaw: 0.0,
                width: 1.2,
                length: 0.7,
                height: 0.75
            ),
            Furniture(
                name: "Ergonomic Chair",
                category: .seating,
                positionX: 1.3,
                positionY: 0.0,
                positionZ: -0.3,
                rotationYaw: Double.pi,
                width: 0.6,
                length: 0.6,
                height: 0.95
            ),
            Furniture(
                name: "Bookshelf",
                category: .storage,
                positionX: -1.8,
                positionY: 0.0,
                positionZ: 1.0,
                rotationYaw: Double.pi / 2,
                width: 0.8,
                length: 0.35,
                height: 1.8
            ),
            Furniture(
                name: "Floor Lamp",
                category: .lighting,
                positionX: -1.8,
                positionY: 0.0,
                positionZ: -2.0,
                rotationYaw: 0.0,
                width: 0.4,
                length: 0.4,
                height: 1.6
            )
        ]

        let baseline = Layout(
            name: "Original Room Scan",
            isBaseline: true,
            createdAt: Date(),
            furnitures: baselineFurnitures
        )

        let working = baseline.createCopy(name: "Active Workspace", isBaseline: false)

        let room = Room(
            name: "Sample Studio Apartment",
            dimensionsWidth: 4.5,
            dimensionsLength: 5.5,
            dimensionsHeight: 2.6,
            baselineLayout: baseline,
            workingLayout: working
        )

        baseline.room = room
        working.room = room

        return room
    }

    public static func createCozyBedroom() -> Room {
        let bedroomFurnitures = [
            Furniture(
                name: "King Bed",
                category: .bed,
                positionX: 0.0,
                positionY: 0.0,
                positionZ: -1.2,
                rotationYaw: 0.0,
                width: 1.9,
                length: 2.1,
                height: 1.0
            ),
            Furniture(
                name: "Nightstand Left",
                category: .storage,
                positionX: -1.3,
                positionY: 0.0,
                positionZ: -1.2,
                rotationYaw: 0.0,
                width: 0.5,
                length: 0.5,
                height: 0.6
            ),
            Furniture(
                name: "Nightstand Right",
                category: .storage,
                positionX: 1.3,
                positionY: 0.0,
                positionZ: -1.2,
                rotationYaw: 0.0,
                width: 0.5,
                length: 0.5,
                height: 0.6
            ),
            Furniture(
                name: "Reading Armchair",
                category: .seating,
                positionX: -1.2,
                positionY: 0.0,
                positionZ: 1.1,
                rotationYaw: Double.pi / 4,
                width: 0.85,
                length: 0.85,
                height: 0.9
            ),
            Furniture(
                name: "Wardrobe",
                category: .storage,
                positionX: 1.3,
                positionY: 0.0,
                positionZ: 1.0,
                rotationYaw: Double.pi,
                width: 1.2,
                length: 0.6,
                height: 2.1
            )
        ]

        let fixtures = [
            LightFixture(
                name: "Ceiling Flushmount",
                layer: .ambient,
                positionX: 0.0,
                positionZ: 0.0,
                elevationY: 2.5,
                lumens: 2400.0,
                colorTemperatureKelvin: 3000,
                isOn: true
            ),
            LightFixture(
                name: "Bedside Reading Lamp",
                layer: .task,
                positionX: -1.3,
                positionZ: -1.2,
                elevationY: 0.7,
                lumens: 450.0,
                colorTemperatureKelvin: 2700,
                isOn: true
            ),
            LightFixture(
                name: "Headboard LED Strip",
                layer: .accent,
                positionX: 0.0,
                positionZ: -2.1,
                elevationY: 1.2,
                lumens: 300.0,
                colorTemperatureKelvin: 2500,
                isOn: true
            )
        ]

        let baseline = Layout(
            name: "Original Bedroom Scan",
            isBaseline: true,
            createdAt: Date(),
            furnitures: bedroomFurnitures,
            lightFixtures: fixtures
        )

        let working = baseline.createCopy(name: "Active Bedroom", isBaseline: false)

        let room = Room(
            name: "Cozy Master Bedroom",
            dimensionsWidth: 4.2,
            dimensionsLength: 4.8,
            dimensionsHeight: 2.7,
            baselineLayout: baseline,
            workingLayout: working
        )

        baseline.room = room
        working.room = room

        return room
    }
}
