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

    /// Evaluates natural daylight time scrubbing in Stage 3 (Illumination)
    public func evaluateDaylightChange(
        hour: Double,
        furnitures: [Furniture],
        fixtures: [LightFixture]
    ) -> MicroReaction? {
        let hasDesk = furnitures.contains { !$0.isArchived && ($0.category == .table || $0.name.localizedCaseInsensitiveContains("desk")) }
        let activeFixtures = fixtures.filter { $0.isOn }
        let activeAmbientOrTask = activeFixtures.filter { $0.layer == .ambient || $0.layer == .task }

        if hour >= 8.0 && hour < 11.0 {
            // Morning
            if hasDesk {
                return MicroReaction(
                    message: "Soft morning rays! If you work early, angle your desk toward this gentle natural light.",
                    emotion: .happy
                )
            } else {
                return MicroReaction(
                    message: "Gentle morning sun! A calm time to let natural light brighten up your seating area.",
                    emotion: .happy
                )
            }
        } else if hour >= 11.0 && hour < 15.0 {
            // Midday
            return MicroReaction(
                message: "High midday sun! Watch out for harsh glare on screens and shiny work surfaces.",
                emotion: .thinking
            )
        } else if hour >= 15.0 && hour < 18.5 {
            // Golden hour
            return MicroReaction(
                message: "Golden hour! Warm, low sunlight cuts deep into the room. Super cozy vibe for reading.",
                emotion: .happy
            )
        } else if hour >= 18.5 {
            // Evening / Dusk
            if activeAmbientOrTask.isEmpty {
                return MicroReaction(
                    message: "The sun is down! Without natural light, the room feels dim. Try turning on ambient or task lamps!",
                    emotion: .warning
                )
            } else {
                return MicroReaction(
                    message: "Dusk has settled in! Your warm artificial lamps are stepping up nicely to keep things inviting.",
                    emotion: .happy
                )
            }
        }

        return nil
    }
}
