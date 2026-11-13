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

            // Functional Pairs & Task Lighting Check
            if AnthropometricStandards.isFunctionalCompanionPair(
                categoryA: event.category,
                nameA: event.furnitureName,
                categoryB: item.category,
                nameB: item.name
            ) {
                let isLighting = event.category == .lighting ||
                                 event.furnitureName.localizedCaseInsensitiveContains("lamp") ||
                                 event.furnitureName.localizedCaseInsensitiveContains("light") ||
                                 item.category == .lighting ||
                                 item.name.localizedCaseInsensitiveContains("lamp") ||
                                 item.name.localizedCaseInsensitiveContains("light")

                if isLighting {
                    let isSurface = item.category == .table ||
                                    item.category == .storage ||
                                    item.name.localizedCaseInsensitiveContains("table") ||
                                    item.name.localizedCaseInsensitiveContains("desk") ||
                                    item.name.localizedCaseInsensitiveContains("nightstand") ||
                                    event.category == .table ||
                                    event.furnitureName.localizedCaseInsensitiveContains("table") ||
                                    event.furnitureName.localizedCaseInsensitiveContains("desk")

                    // Tabletop lamps resting on surfaces (desk, nightstand) naturally share (x, z) coordinates
                    if isSurface {
                        continue
                    }

                    // Floor lamps positioned beside seating for task lighting
                    if dist >= 0.30 {
                        if event.category == .lighting || event.furnitureName.localizedCaseInsensitiveContains("lamp") {
                            return MicroReaction(
                                message: "Task lighting placed! Positioning light beside \(item.name) creates a well-lit, comfortable activity zone.",
                                emotion: .happy
                            )
                        }
                        continue
                    }
                }

                // Bed + Nightstand
                let isNightstandBedPair = (event.category == .bed && item.name.localizedCaseInsensitiveContains("nightstand")) ||
                                          (item.category == .bed && event.furnitureName.localizedCaseInsensitiveContains("nightstand"))
                if isNightstandBedPair && dist >= 0.30 { continue }

                // Table/Desk + Chair/Seating
                let isDeskChairPair = (event.category == .table && item.category == .seating) ||
                                      (item.category == .table && event.category == .seating)
                if isDeskChairPair && dist >= 0.35 { continue }
            }

            let isSuspendedOrMounted = event.furnitureName.localizedCaseInsensitiveContains("ceiling") ||
                                       event.furnitureName.localizedCaseInsensitiveContains("pendant") ||
                                       event.furnitureName.localizedCaseInsensitiveContains("sconce") ||
                                       item.name.localizedCaseInsensitiveContains("ceiling") ||
                                       item.name.localizedCaseInsensitiveContains("pendant") ||
                                       item.name.localizedCaseInsensitiveContains("sconce")
            if isSuspendedOrMounted {
                continue
            }

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

    // MARK: - Live Spatial Warnings (Red Collisions & Yellow Improvements)

    /// Evaluates the full active layout for real-time collisions (red) and ergonomic improvements (yellow).
    public func evaluateSpatialWarnings(
        furnitures: [Furniture],
        roomDimensions: (width: Double, length: Double)
    ) -> [SpatialWarning] {
        let active = furnitures.filter { !$0.isArchived }
        guard !active.isEmpty else { return [] }

        let halfW = roomDimensions.width / 2.0
        let halfL = roomDimensions.length / 2.0
        var warnings: [SpatialWarning] = []

        // 1. Pairwise collision & tight-walkway checks
        for i in 0..<active.count {
            let a = active[i]
            if isSuspendedOrWallMounted(a) { continue }
            let extA = halfExtents(for: a)

            for j in (i + 1)..<active.count {
                let b = active[j]
                if isSuspendedOrWallMounted(b) { continue }
                if isTabletopLampOnSurface(a: a, b: b) || isTabletopLampOnSurface(a: b, b: a) {
                    continue
                }

                let extB = halfExtents(for: b)
                let gapX = abs(a.positionX - b.positionX) - (extA.x + extB.x)
                let gapZ = abs(a.positionZ - b.positionZ) - (extA.z + extB.z)
                let edgeGap = hypot(max(0.0, gapX), max(0.0, gapZ))

                if AnthropometricStandards.isFunctionalCompanionPair(a: a, b: b) {
                    let isDeskChair = (a.category == .table && b.category == .seating) ||
                        (b.category == .table && a.category == .seating)
                    let tolerance = isDeskChair ? 0.22 : 0.06
                    if gapX < -tolerance && gapZ < -tolerance {
                        warnings.append(
                            SpatialWarning(
                                id: "overlap_\(a.id.uuidString)_\(b.id.uuidString)",
                                severity: .collision,
                                furnitureIDs: [a.id, b.id],
                                title: "Collision",
                                message: "\(a.name) is overlapping \(b.name) — nudge one slightly aside so both fit cleanly."
                            )
                        )
                    }
                    continue
                }

                if gapX < -0.02 && gapZ < -0.02 {
                    warnings.append(
                        SpatialWarning(
                            id: "collision_\(a.id.uuidString)_\(b.id.uuidString)",
                            severity: .collision,
                            furnitureIDs: [a.id, b.id],
                            title: "Collision",
                            message: "\(a.name) and \(b.name) are colliding! Slide them apart so they don't overlap."
                        )
                    )
                } else if edgeGap < AnthropometricStandards.minimumCirculation {
                    warnings.append(
                        SpatialWarning(
                            id: "tight_\(a.id.uuidString)_\(b.id.uuidString)",
                            severity: .caution,
                            furnitureIDs: [a.id, b.id],
                            title: "Can Be Better",
                            message: "Tight walkway between \(a.name) and \(b.name) — leave a bit more breathing room for easy flow."
                        )
                    )
                }
            }
        }

        // 2. Single-piece architectural & ergonomic checks
        let doorX = -halfW * 0.35
        for f in active {
            if isSuspendedOrWallMounted(f) { continue }
            let ext = halfExtents(for: f)

            // Red: Entrance door blocked on Front-Left wall
            if (f.positionZ + ext.z) > (halfL - 0.55) &&
                (f.positionX + ext.x) > (doorX - 0.42) &&
                (f.positionX - ext.x) < (doorX + 0.42) {
                warnings.append(
                    SpatialWarning(
                        id: "door_\(f.id.uuidString)",
                        severity: .collision,
                        furnitureIDs: [f.id],
                        title: "Door Blocked",
                        message: "\(f.name) is blocking the front-left entrance door — slide it clear of the doorway."
                    )
                )
            }

            // Yellow: Bed floating away from all perimeter walls
            if f.category == .bed {
                let distLeft = (f.positionX - ext.x) - (-halfW)
                let distRight = halfW - (f.positionX + ext.x)
                let distBack = (f.positionZ - ext.z) - (-halfL)
                let distFront = halfL - (f.positionZ + ext.z)
                if min(distLeft, distRight, distBack, distFront) > 0.45 {
                    warnings.append(
                        SpatialWarning(
                            id: "floating_\(f.id.uuidString)",
                            severity: .caution,
                            furnitureIDs: [f.id],
                            title: "Can Be Better",
                            message: "\(f.name) is floating away from the walls — anchor it against a wall to open up the center floor."
                        )
                    )
                }
            }

            // Yellow: Tall storage blocking the centered back wall window
            if f.category == .storage && f.height >= 1.35 {
                if (f.positionZ - ext.z) < (-halfL + 0.40) &&
                    (f.positionX + ext.x) > -0.80 &&
                    (f.positionX - ext.x) < 0.80 {
                    warnings.append(
                        SpatialWarning(
                            id: "window_\(f.id.uuidString)",
                            severity: .caution,
                            furnitureIDs: [f.id],
                            title: "Can Be Better",
                            message: "\(f.name) is blocking the back window — move it to a side wall to let natural daylight in."
                        )
                    )
                }
            }
        }

        // Sort collisions first so Red always takes priority over Yellow
        return warnings.sorted { $0.severity > $1.severity }
    }

    /// Maps each furniture ID to its highest-severity active warning.
    public static func warningSeverityMap(from warnings: [SpatialWarning]) -> [UUID: SpatialWarningSeverity] {
        var map: [UUID: SpatialWarningSeverity] = [:]
        for warning in warnings {
            for id in warning.furnitureIDs {
                if let existing = map[id] {
                    map[id] = max(existing, warning.severity)
                } else {
                    map[id] = warning.severity
                }
            }
        }
        return map
    }

    /// Evaluates spatial warnings and returns the highest severity keyed by furniture ID.
    public func warningSeverityByFurnitureID(
        furnitures: [Furniture],
        roomDimensions: (width: Double, length: Double)
    ) -> [UUID: SpatialWarningSeverity] {
        let warnings = evaluateSpatialWarnings(furnitures: furnitures, roomDimensions: roomDimensions)
        return Self.warningSeverityMap(from: warnings)
    }

    private func halfExtents(for f: Furniture) -> (x: Double, z: Double) {
        let absCos = abs(cos(f.rotationYaw))
        let absSin = abs(sin(f.rotationYaw))
        return (
            x: (absCos * f.width + absSin * f.length) / 2.0,
            z: (absSin * f.width + absCos * f.length) / 2.0
        )
    }

    private func isSuspendedOrWallMounted(_ f: Furniture) -> Bool {
        f.name.localizedCaseInsensitiveContains("ceiling") ||
        f.name.localizedCaseInsensitiveContains("pendant") ||
        f.name.localizedCaseInsensitiveContains("sconce")
    }

    private func isTabletopLampOnSurface(a: Furniture, b: Furniture) -> Bool {
        let isSurface = b.category == .table || b.category == .storage ||
            b.name.localizedCaseInsensitiveContains("desk") ||
            b.name.localizedCaseInsensitiveContains("table") ||
            b.name.localizedCaseInsensitiveContains("nightstand")
        guard isSurface else { return false }

        let isDeskOrTableLamp = a.name.localizedCaseInsensitiveContains("desk lamp") ||
            a.name.localizedCaseInsensitiveContains("table lamp") ||
            (a.category == .lighting && !a.name.localizedCaseInsensitiveContains("floor"))
        return isDeskOrTableLamp
    }
}
