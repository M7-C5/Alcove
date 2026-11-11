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
        for f in furnitures {
            lines.append("• \(f.name) [\(f.category.rawValue)]: Position(x: \(String(format: "%.2f", f.positionX))m, z: \(String(format: "%.2f", f.positionZ))m), Size(\(String(format: "%.2f", f.width))m × \(String(format: "%.2f", f.length))m), Rotation: \(Int(f.rotationYaw * 180 / .pi))°")
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

                let isCompanionPair = (a.category == .bed && b.name.localizedCaseInsensitiveContains("nightstand")) ||
                                      (b.category == .bed && a.name.localizedCaseInsensitiveContains("nightstand")) ||
                                      (a.category == .table && b.category == .seating) ||
                                      (b.category == .table && a.category == .seating) ||
                                      (a.category == .seating && b.category == .table) ||
                                      (b.category == .seating && a.category == .table)

                if isCompanionPair {
                    lines.append("• [FUNCTIONAL PAIR] '\(a.name)' & '\(b.name)' are adjacent (~\(Int(clearance * 100))cm) — Natural functional proximity (intentional companion pieces).")
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
