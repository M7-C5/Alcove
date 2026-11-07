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
}
