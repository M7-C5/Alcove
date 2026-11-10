import Foundation
import SwiftData

/// Generates mock rooms matching Alcove's SwiftData models for 3D Studio visualization.
public struct MockRoomGenerator {

    /// Generates a typical Bedroom & Office combo room:
    /// 4 walls, 1 bed, 1 desk, 1 chair, 1 cupboard, plus nightstand & floor lamp.
    @MainActor
    public static func generateBedroomOfficeCombo(name: String = "Bedroom & Office Combo") -> Room {
        let width = 4.5
        let length = 4.0
        let height = 2.6

        // 1. Bed (Queen Bed with headboard against back wall)
        let bed = Furniture(
            name: "Queen Bed",
            category: .bed,
            positionX: -1.1,
            positionY: 0.0,
            positionZ: -0.9,
            rotationYaw: 0.0,
            width: 1.6,
            length: 2.0,
            height: 0.85
        )

        // 2. Bedside Table / Nightstand
        let nightstand = Furniture(
            name: "Bedside Nightstand",
            category: .table,
            positionX: -2.0,
            positionY: 0.0,
            positionZ: -1.65,
            rotationYaw: 0.0,
            width: 0.5,
            length: 0.45,
            height: 0.55
        )

        // 3. Cupboard / Wardrobe
        let cupboard = Furniture(
            name: "Double Wardrobe Cupboard",
            category: .storage,
            positionX: -1.4,
            positionY: 0.0,
            positionZ: 1.3,
            rotationYaw: 0.0,
            width: 1.2,
            length: 0.6,
            height: 1.9
        )

        // 4. Work Desk (against right wall)
        let desk = Furniture(
            name: "Home Office Desk",
            category: .table,
            positionX: 1.3,
            positionY: 0.0,
            positionZ: -1.1,
            rotationYaw: 0.0,
            width: 1.3,
            length: 0.7,
            height: 0.75
        )

        // 5. Office Chair (facing desk)
        let chair = Furniture(
            name: "Ergonomic Desk Chair",
            category: .seating,
            positionX: 1.3,
            positionY: 0.0,
            positionZ: -0.35,
            rotationYaw: Double.pi,
            width: 0.6,
            length: 0.6,
            height: 0.95
        )

        // 6. Floor Lamp (corner illumination)
        let floorLamp = Furniture(
            name: "Corner Floor Lamp",
            category: .lighting,
            positionX: 1.8,
            positionY: 0.0,
            positionZ: 1.3,
            rotationYaw: 0.0,
            width: 0.4,
            length: 0.4,
            height: 1.6
        )

        let furnitures = [bed, nightstand, cupboard, desk, chair, floorLamp]

        let baselineLayout = Layout(
            name: "Original Layout",
            isBaseline: true,
            furnitures: furnitures.map { $0.copy() }
        )

        let workingLayout = Layout(
            name: "Working Layout",
            isBaseline: false,
            furnitures: furnitures
        )

        let room = Room(
            name: name,
            dimensionsWidth: width,
            dimensionsLength: length,
            dimensionsHeight: height,
            baselineLayout: baselineLayout,
            workingLayout: workingLayout
        )

        baselineLayout.room = room
        workingLayout.room = room

        return room
    }
}
