import Foundation

/// Serializes live 3D room state into structured spatial context for LLM prompts.
public struct RoomSpatialContextSerializer: Sendable {

    public init() {}

    /// Formats the room's physical layout, anthropometric clearances, and lighting layers into an AI context prompt.
    public func serialize(room: Room, stage: StageType) -> String {
        let furnitures = room.workingLayout?.furnitures.filter { !$0.isArchived } ?? []
        let fixtures = room.workingLayout?.lightFixtures ?? []

        var lines: [String] = []
        lines.append("### CURRENT ROOM STATE")
        let halfW = room.dimensionsWidth / 2.0
        let halfL = room.dimensionsLength / 2.0
        lines.append("- Room Name: \(room.name)")
        lines.append("- Stage: \(stage.stageNumber) (\(stage.title) — \(stage.subtitle))")
        lines.append("- Dimensions: \(String(format: "%.1f", room.dimensionsWidth))m wide × \(String(format: "%.1f", room.dimensionsLength))m long (Area: ~\(String(format: "%.1f", room.dimensionsWidth * room.dimensionsLength)) m²)")
        lines.append("- Window Location: Back Wall (z = -\(String(format: "%.2f", halfL))m, centered along the top wall)")
        lines.append("- Entrance Door Location: Front Wall Front-Left (z = +\(String(format: "%.2f", halfL))m, x ≈ -\(String(format: "%.2f", halfW * 0.35))m, bottom-left)")
        lines.append("- Daylight Orientation: South-facing window exposure at the Back Wall (standard daylight simulation)")

        lines.append("\n### ACTIVE FURNITURE (\(furnitures.count) items):")

        struct PlacedExtent {
            let furniture: Furniture
            let extentX: Double
            let extentZ: Double
        }
        var placedExtents: [PlacedExtent] = []

        for f in furnitures {
            let facingX = sin(f.rotationYaw)
            let facingZ = cos(f.rotationYaw)
            let toCenterX = -f.positionX
            let toCenterZ = -f.positionZ
            let dotCenter = facingX * toCenterX + facingZ * toCenterZ

            let facingDescription: String
            if dotCenter > 0.15 {
                facingDescription = "INWARD into the room (toward center)"
            } else if dotCenter < -0.15 {
                facingDescription = "OUTWARD toward perimeter wall"
            } else {
                facingDescription = "Parallel to wall"
            }

            // Outer footprint extents accounting for orientation
            let absCos = abs(cos(f.rotationYaw))
            let absSin = abs(sin(f.rotationYaw))
            let extentX = (absCos * f.width + absSin * f.length) / 2.0
            let extentZ = (absSin * f.width + absCos * f.length) / 2.0

            let distToLeftWall = (f.positionX - extentX) - (-halfW)
            let distToRightWall = halfW - (f.positionX + extentX)
            let distToBackWall = (f.positionZ - extentZ) - (-halfL)
            let distToFrontWall = halfL - (f.positionZ + extentZ)

            var placementContext: [String] = []
            if distToLeftWall < 0.45 {
                placementContext.append("Anchored at Left Wall")
            } else if distToRightWall < 0.45 {
                placementContext.append("Anchored at Right Wall")
            }
            if distToBackWall < 0.45 {
                placementContext.append("Anchored at Back Wall")
            } else if distToFrontWall < 0.45 {
                placementContext.append("Anchored at Front Wall")
            }

            if placementContext.isEmpty {
                let distToCenter = sqrt(f.positionX * f.positionX + f.positionZ * f.positionZ)
                if distToCenter < 0.70 {
                    placementContext.append("Standing in open center of room")
                } else {
                    placementContext.append("Mid-floor offset from walls")
                }
            }

            let wallStr = placementContext.joined(separator: ", ")
            let zoneLabel = Self.quadrantLabel(x: f.positionX, z: f.positionZ)
            placedExtents.append(PlacedExtent(furniture: f, extentX: extentX, extentZ: extentZ))
            lines.append("• \(f.name) [\(f.category.rawValue)]: Zone: \(zoneLabel), Position(x: \(String(format: "%.2f", f.positionX))m, z: \(String(format: "%.2f", f.positionZ))m), Size(\(String(format: "%.2f", f.width))m × \(String(format: "%.2f", f.length))m), Facing: \(facingDescription), Placement: \(wallStr)")
        }

        // Summarize 2D quadrant occupancy so advice never tells the user to move large furniture into an occupied corner
        lines.append("\n### ROOM ZONE OCCUPANCY & PLACEMENT GUIDE:")
        let zones: [(name: String, minX: Double, maxX: Double, minZ: Double, maxZ: Double)] = [
            ("Back-Left", -halfW, 0, -halfL, 0),
            ("Back-Right", 0, halfW, -halfL, 0),
            ("Front-Left", -halfW, 0, 0, halfL),
            ("Front-Right", 0, halfW, 0, halfL)
        ]
        let overlapMargin = 0.05
        for zone in zones {
            let occupants = placedExtents.filter { item in
                let f = item.furniture
                return (f.positionX + item.extentX) > (zone.minX + overlapMargin) &&
                    (f.positionX - item.extentX) < (zone.maxX - overlapMargin) &&
                    (f.positionZ + item.extentZ) > (zone.minZ + overlapMargin) &&
                    (f.positionZ - item.extentZ) < (zone.maxZ - overlapMargin)
            }.map(\.furniture)

            if occupants.isEmpty {
                lines.append("• \(zone.name): OPEN (available for placing large furniture)")
            } else {
                let names = occupants.map(\.name).joined(separator: ", ")
                let hasLargeItem = occupants.contains { max($0.width, $0.length) > 0.55 }
                if hasLargeItem {
                    lines.append("• \(zone.name): OCCUPIED by \(names) (do NOT place another large piece here without proposing a swap or relocation)")
                } else {
                    lines.append("• \(zone.name): AVAILABLE FOR LARGE FURNITURE (only small item(s): \(names))")
                }
            }
        }

        // Compute anthropometric clearances using Panero & Zelnik standards
        lines.append("\n### PANERO & ZELNIK CLEARANCE AUDIT:")
        var bottlenecksFound = 0
        for i in 0..<furnitures.count {
            for j in (i + 1)..<furnitures.count {
                let a = furnitures[i]
                let b = furnitures[j]
                let dx = a.positionX - b.positionX
                let dz = a.positionZ - b.positionZ
                let centerDist = sqrt(dx * dx + dz * dz)
                let footprintRadiusSum = (a.width + a.length) / 4.0 + (b.width + b.length) / 4.0
                let clearance = max(0.0, centerDist - footprintRadiusSum)

                if AnthropometricStandards.isFunctionalCompanionPair(a: a, b: b) {
                    let isLighting = a.category == .lighting || b.category == .lighting ||
                                     a.name.localizedCaseInsensitiveContains("lamp") || b.name.localizedCaseInsensitiveContains("lamp")
                    if isLighting {
                        lines.append("• [TASK LIGHTING] '\(a.name)' & '\(b.name)' are intentionally paired (~\(Int(clearance * 100))cm) — Focused task/reading illumination.")
                    } else {
                        lines.append("• [FUNCTIONAL PAIR] '\(a.name)' & '\(b.name)' are adjacent (~\(Int(clearance * 100))cm) — Natural functional proximity (intentional companion pieces).")
                    }
                } else if a.category == .bed && b.category == .bed && clearance < AnthropometricStandards.bedToBedClearanceMin {
                    bottlenecksFound += 1
                    lines.append("⚠️ [CRITICAL] Bed-to-Bed gap between '\(a.name)' & '\(b.name)': \(Int(clearance * 100))cm (Minimum required: 91.4cm)")
                } else if clearance < AnthropometricStandards.minimumCirculation {
                    bottlenecksFound += 1
                    lines.append("⚠️ [CRITICAL] Walkway between '\(a.name)' & '\(b.name)': \(Int(clearance * 100))cm (Below standard 1-person passage: 76.2cm)")
                } else if clearance < AnthropometricStandards.comfortableCirculation {
                    lines.append("ℹ️ [PASSABLE BUT TIGHT] Walkway between '\(a.name)' & '\(b.name)': \(Int(clearance * 100))cm (Meets 76.2cm minimum, but below 91.4cm recommended for carrying)")
                }
            }
        }
        if bottlenecksFound == 0 {
            lines.append("✅ All evaluated pathways meet or exceed Panero & Zelnik circulation thresholds.")
        }

        // Lighting Summary based on Karlen & Benya and Frida Ramstedt (only active in Stages 3 & 4)
        if stage == .illumination || stage == .harmony {
            lines.append("\n### LIGHTING & FIXTURE AUDIT (Karlen & Benya + Frida Ramstedt):")
            let ambientCount = fixtures.filter { $0.layer == .ambient }.count
            let taskCount = fixtures.filter { $0.layer == .task }.count
            let accentCount = fixtures.filter { $0.layer == .accent }.count
            lines.append("- Total Installed Fixtures: \(fixtures.count) (Frida Ramstedt guideline: 5–7 light sources per room)")
            lines.append("- Layer Breakdown: Ambient (\(ambientCount)), Task (\(taskCount)), Accent (\(accentCount))")
        } else if stage == .audit {
            lines.append("\n### STAGE 1 CURRENT SITUATION & INTAKE:")
            lines.append("- Diagnosis Mode: Observational baseline intake only.")
            lines.append("- Rule: Do NOT score or recommend adding artificial lighting in Stage 1. Focus entirely on room scale, current pieces, pathway flow, and daylight.")
        }

        return lines.joined(separator: "\n")
    }

    private static func quadrantLabel(x: Double, z: Double) -> String {
        let depth: String
        if z < -0.35 {
            depth = "Back"
        } else if z > 0.35 {
            depth = "Front"
        } else {
            depth = "Mid"
        }

        let side: String
        if x < -0.35 {
            side = "Left"
        } else if x > 0.35 {
            side = "Right"
        } else {
            side = "Center"
        }

        if depth == "Mid" && side == "Center" {
            return "Center"
        }
        return "\(depth)-\(side)"
    }
}
