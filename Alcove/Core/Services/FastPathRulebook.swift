import Foundation

/// Fast-Path rule engine delivering instantaneous (<100ms) spatial heuristics
public struct FastPathRulebook: Sendable {

    public init() {}

    public func evaluateMicroMove(
        event: FurnitureMoveEvent,
        roomDimensions: (width: Double, length: Double),
        allFurnitures: [Furniture]
    ) -> MicroReaction? {
        let halfW = roomDimensions.width / 2.0
        let halfL = roomDimensions.length / 2.0
        let newX = event.newPosition.x
        let newZ = event.newPosition.z

        // Rule 1: Boundary check
        let wallDistanceX = halfW - abs(newX)
        let wallDistanceZ = halfL - abs(newZ)
        let minWallDist = min(wallDistanceX, wallDistanceZ)

        if minWallDist < 0.15 && event.category == .bed {
            return MicroReaction(
                message: "Anchored nicely against the wall!",
                emotion: .happy
            )
        }

        // Rule 2: Walkway clearance & crowding check against other furniture
        for item in allFurnitures where item.name != event.furnitureName && !item.isArchived {
            let dx = item.positionX - newX
            let dz = item.positionZ - newZ
            let dist = sqrt(dx * dx + dz * dz)

            let isNightstandBedPair = (event.category == .bed && item.name.localizedCaseInsensitiveContains("nightstand")) ||
                                      (item.category == .bed && event.furnitureName.localizedCaseInsensitiveContains("nightstand"))
            if isNightstandBedPair && dist >= 0.30 { continue } // Nightstands naturally sit adjacent to a bed

            let combinedRadius = (item.width + item.length) / 4.0 + 0.30 // Physical encroachment threshold
            if dist < combinedRadius {
                return MicroReaction(
                    message: "Careful! \(event.furnitureName) is crowding \(item.name). It feels a little too tight to walk through—try giving them more breathing room!",
                    emotion: .warning
                )
            }
        }

        // Rule 3: Seating orientation
        if event.category == .seating {
            if abs(newX) < 1.0 && abs(newZ) < 1.0 {
                return MicroReaction(
                    message: "Creating a cozy conversation zone in the center!",
                    emotion: .curious
                )
            }
        }

        // Rule 4: General positive reinforcement
        let movedDist = sqrt(pow(event.newPosition.x - event.oldPosition.x, 2) + pow(event.newPosition.z - event.oldPosition.z, 2))
        if movedDist > 0.8 {
            return MicroReaction(
                message: "Bold rearrangement! How does the room flow feel now?",
                emotion: .thinking
            )
        }

        return nil
    }
}
