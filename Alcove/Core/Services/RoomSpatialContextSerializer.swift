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
        lines.append("- Room Name: \(room.name)")
        lines.append("- Stage: \(stage.stageNumber) (\(stage.title) — \(stage.subtitle))")
        lines.append("- Dimensions: \(String(format: "%.1f", room.dimensionsWidth))m wide × \(String(format: "%.1f", room.dimensionsLength))m long (Area: ~\(String(format: "%.1f", room.dimensionsWidth * room.dimensionsLength)) m²)")
        lines.append("- Daylight Orientation: South-facing window exposure (standard daylight simulation)")

        lines.append("\n### ACTIVE FURNITURE (\(furnitures.count) items):")
        let halfW = room.dimensionsWidth / 2.0
        let halfL = room.dimensionsLength / 2.0

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

            var placementContext: [String] = []
            if f.positionX < -halfW + 0.6 {
                placementContext.append("Anchored at Left Wall")
            } else if f.positionX > halfW - 0.6 {
                placementContext.append("Anchored at Right Wall")
            }
            if f.positionZ < -halfL + 0.6 {
                placementContext.append("Anchored at Back Wall")
            } else if f.positionZ > halfL - 0.6 {
                placementContext.append("Anchored at Front Wall")
            }
            if placementContext.isEmpty {
                placementContext.append("Central room floor")
            }

            let wallStr = placementContext.joined(separator: ", ")
            lines.append("• \(f.name) [\(f.category.rawValue)]: Position(x: \(String(format: "%.2f", f.positionX))m, z: \(String(format: "%.2f", f.positionZ))m), Size(\(String(format: "%.2f", f.width))m × \(String(format: "%.2f", f.length))m), Facing: \(facingDescription), Placement: \(wallStr)")
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
}
