import Foundation

/// Deterministic mock implementation of MascotAIServiceProtocol for offline development, previews, and tests
@MainActor
public final class MockMascotAIService: MascotAIServiceProtocol {
    private let rulebook = FastPathRulebook()
    private let illuminationEngine = IlluminationSimulationEngine()
    private let harmonyEngine = HarmonySynthesisEngine()

    public init() {}

    public func stageGreeting(stage: StageType, roomName: String) -> String {
        switch stage {
        case .audit:
            return "Welcome to \(roomName)! Let's begin by assessing your current space. Look around and spot any tight corners or obstructed paths."
        case .rearrangement:
            return "Stage 2 unlocked! Now you can grab, slide, and rotate furniture. Aim for at least 76.2cm of open walkway clearance (Panero & Zelnik standard)."
        case .illumination:
            return "Stage 3 is all about light! Scrub through daylight hours to observe sun angles, and balance ambient, task, and accent lighting layers."
        case .harmony:
            return "Congratulations! You've reached The Harmony Reveal. Drag the Before/After split slider to admire your spatial transformation!"
        }
    }

    public func microReact(
        event: FurnitureMoveEvent,
        roomDimensions: (width: Double, length: Double),
        allFurnitures: [Furniture]
    ) -> MicroReaction? {
        rulebook.evaluateMicroMove(
            event: event,
            roomDimensions: roomDimensions,
            allFurnitures: allFurnitures
        )
    }

    public func daylightMicroReact(
        hour: Double,
        room: Room
    ) -> MicroReaction? {
        let furnitures = room.workingLayout?.furnitures ?? []
        let fixtures = room.workingLayout?.lightFixtures ?? []
        return rulebook.evaluateDaylightChange(
            hour: hour,
            furnitures: furnitures,
            fixtures: fixtures
        )
    }

    public func evaluateStage(
        stage: StageType,
        room: Room
    ) async -> StageEvaluationResult {
        let furnitures = room.workingLayout?.furnitures.filter { !$0.isArchived } ?? []

        switch stage {
        case .audit:
            var bottlenecks: [SpatialBottleneck] = []
            if furnitures.count > 5 {
                bottlenecks.append(SpatialBottleneck(
                    title: "High Density Space",
                    detail: "The room currently contains \(furnitures.count) active pieces in the baseline layout.",
                    severity: .notice
                ))
            }

            let auditRecs = generateContextualRecommendations(stage: .audit, room: room, bottlenecks: bottlenecks)
            return StageEvaluationResult(
                canAdvance: true,
                score: 100,
                title: "Baseline Audit Captured",
                dialogue: "We've mapped out the baseline flow of your room! Notice where the main pathways feel open and where pieces cluster together. When you're ready, let's move to Stage 2 to start rearranging.",
                bottlenecks: bottlenecks,
                recommendations: auditRecs,
                praise: ["Baseline room scan captured cleanly", "Room boundaries and furniture mapped"]
            )

        case .rearrangement:
            var bottlenecks: [SpatialBottleneck] = []
            var score = 90

            // Check clearances between all pairs using Panero & Zelnik anthropometric standards
            for i in 0..<furnitures.count {
                for j in (i + 1)..<furnitures.count {
                    let a = furnitures[i]
                    let b = furnitures[j]
                    let dx = a.positionX - b.positionX
                    let dz = a.positionZ - b.positionZ
                    let centerDist = sqrt(dx * dx + dz * dz)
                    let footprintRadiusSum = (a.width + a.length) / 4.0 + (b.width + b.length) / 4.0
                    let clearance = max(0.0, centerDist - footprintRadiusSum)

                    // Ignore functional pairs (bed + nightstand, desk + chair, lamp + seating/desk/bed)
                    if AnthropometricStandards.isFunctionalCompanionPair(a: a, b: b) {
                        continue
                    }

                    // Check Bed-to-Bed clearance (91.4 cm min)
                    if a.category == .bed && b.category == .bed {
                        if clearance < AnthropometricStandards.bedToBedClearanceMin {
                            bottlenecks.append(SpatialBottleneck(
                                title: "Bed-to-Bed Clearance Too Tight",
                                detail: "Clearance between \(a.name) and \(b.name) is ~\(Int(clearance * 100))cm. Standard requires at least 91.4cm.",
                                severity: .critical,
                                affectedFurnitureName: a.name
                            ))
                            score -= 15
                            continue
                        }
                    }

                    // Check General Circulation (76.2 cm min, 91.4 cm recommended)
                    let compliance = AnthropometricStandards.evaluateCirculation(clearanceInMeters: clearance)
                    switch compliance {
                    case .bottleneckCritical:
                        bottlenecks.append(SpatialBottleneck(
                            title: "Critical Bottleneck Between \(a.name) & \(b.name)",
                            detail: "Current clearance is ~\(Int(clearance * 100))cm. Below minimum 1-person passage of 76.2cm.",
                            severity: .critical,
                            affectedFurnitureName: a.name
                        ))
                        score -= 15
                    case .acceptableMinimum:
                        bottlenecks.append(SpatialBottleneck(
                            title: "Tight Walkway Between \(a.name) & \(b.name)",
                            detail: "Current clearance is ~\(Int(clearance * 100))cm. Meets minimum 76.2cm, but 91.4cm is recommended for carrying items.",
                            severity: .warning,
                            affectedFurnitureName: a.name
                        ))
                        score -= 5
                    case .optimalComfort:
                        break
                    }
                }
            }

            let canAdvance = bottlenecks.filter { $0.severity == .critical }.isEmpty
            let rearrangeRecs = generateContextualRecommendations(stage: .rearrangement, room: room, bottlenecks: bottlenecks)
            return StageEvaluationResult(
                canAdvance: canAdvance,
                score: max(score, 50),
                title: bottlenecks.isEmpty ? "Flawless Layout!" : (canAdvance ? "Good Progress!" : "Clearance Issues"),
                dialogue: bottlenecks.isEmpty
                    ? "Incredible circulation! All walkways adhere to comfortable circulation standards (≥91.4cm)."
                    : (canAdvance
                        ? "Circulation meets baseline standards. You can tweak tighter spots or proceed to lighting!"
                        : "There are critical bottlenecks below 76.2cm that block natural 1-person passage. Please widen the pathways."),
                bottlenecks: bottlenecks,
                recommendations: rearrangeRecs,
                praise: ["Focal points established", "Proportions balanced"]
            )

        case .illumination:
            let fixtures = room.workingLayout?.lightFixtures ?? []
            let report = illuminationEngine.evaluateIllumination(
                fixtures: fixtures,
                roomWidth: room.dimensionsWidth,
                roomLength: room.dimensionsLength,
                furnitures: furnitures,
                hourOfDay: 12.0
            )

            var bottlenecks: [SpatialBottleneck] = []
            if !report.isAmbientAdequate && fixtures.isEmpty {
                bottlenecks.append(SpatialBottleneck(
                    title: "Missing Artificial Lighting Layers",
                    detail: "The room currently relies primarily on daylight. Add ceiling ambient fixtures or task lamps for evening hours.",
                    severity: .notice
                ))
            }

            let score = max(report.balanceScore, fixtures.isEmpty ? 80 : report.balanceScore)
            return StageEvaluationResult(
                canAdvance: score >= 70,
                score: score,
                title: report.isPassingScore ? "Illumination Balanced!" : "Lighting Needs Refinement",
                dialogue: "We evaluated daylight, ambient, task, and accent lighting layers. Your space has \(report.taskZonesCoveredCount) of \(max(1, report.totalTaskZonesCount)) task zones illuminated.",
                bottlenecks: bottlenecks,
                recommendations: report.recommendations.isEmpty ? ["Add subtle accent lighting on art or headboard"] : report.recommendations,
                praise: ["Natural daylight orientation mapped", "Glare angles minimized"]
            )

        case .harmony:
            let metrics = harmonyEngine.synthesizeHarmony(room: room)
            let harmonyRecs = generateContextualRecommendations(stage: .harmony, room: room, bottlenecks: [])

            return StageEvaluationResult(
                canAdvance: true,
                score: metrics.overallHarmonyScore,
                title: "Spatial Harmony Achieved!",
                dialogue: "\(metrics.summaryVerdict) Walkway clearance improved by \(metrics.clearanceImprovementPercentage)% over baseline scan.",
                bottlenecks: [],
                recommendations: harmonyRecs,
                praise: [
                    "Floor space optimized at \(metrics.workingFloorUtilizationPercentage)% utilization",
                    "Clearance bottlenecks reduced to \(metrics.workingBottlenecksCount)"
                ]
            )
        }
    }

    private func generateContextualRecommendations(
        stage: StageType,
        room: Room,
        bottlenecks: [SpatialBottleneck]
    ) -> [String] {
        let furnitures = (room.workingLayout?.furnitures ?? []).filter { !$0.isArchived }
        var recs: [String] = []

        switch stage {
        case .audit:
            // 1. Daylight & Workspace Orientation
            if let desk = furnitures.first(where: { $0.category == .table || $0.name.localizedCaseInsensitiveContains("desk") }) {
                recs.append("Position your \(desk.name) perpendicular to the window so daylight illuminates your workspace without harsh screen glare.")
            } else {
                recs.append("Notice where natural south daylight reaches deepest into the room to guide your active daytime zoning.")
            }

            // 2. Bed Anchoring & Spatial Security
            if let bed = furnitures.first(where: { $0.category == .bed }) {
                let halfW = room.dimensionsWidth / 2.0
                let halfL = room.dimensionsLength / 2.0
                let isWallBound = (halfW - abs(bed.positionX) < 0.65) || (halfL - abs(bed.positionZ) < 0.65)
                if isWallBound {
                    recs.append("Anchoring the \(bed.name) against perimeter walls preserves open central floor area and defines a quiet, dedicated sleeping zone.")
                } else {
                    recs.append("Anchoring the \(bed.name)'s headboard against a solid perimeter wall will ground the room and open up continuous walking lanes.")
                }
            } else if let chair = furnitures.first(where: { $0.category == .seating }),
                      let desk = furnitures.first(where: { $0.category == .table || $0.name.localizedCaseInsensitiveContains("desk") }) {
                recs.append("Ensure at least 75 cm of pushback clearance behind the \(desk.name) so the \(chair.name) can slide back easily without clipping walkways.")
            } else {
                recs.append("Primary walking paths comfortably meet the 76–90 cm clearance standard, keeping transit between zones fluid.")
            }

        case .rearrangement:
            if !bottlenecks.isEmpty {
                for b in bottlenecks.prefix(2) {
                    let itemName = b.affectedFurnitureName ?? "furniture"
                    recs.append("Scoot the \(itemName) slightly to widen the walkway to at least 76 cm so you can walk through without a squeeze.")
                }
            } else {
                if let chair = furnitures.first(where: { $0.category == .seating }),
                   let desk = furnitures.first(where: { $0.category == .table || $0.name.localizedCaseInsensitiveContains("desk") }) {
                    recs.append("Maintain at least 75 cm of pushback clearance behind the \(desk.name) so the \(chair.name) slides out smoothly without hitting walkways.")
                } else if let mainItem = furnitures.first(where: { $0.category == .bed || $0.category == .table }) {
                    recs.append("Circulation around the \(mainItem.name) is spacious and exceeds comfortable 76–90 cm walking standards.")
                }
                recs.append("Group sleeping and working areas into two distinct zones to keep your studio feeling balanced and uncluttered.")
            }

        case .illumination:
            if let desk = furnitures.first(where: { $0.category == .table || $0.name.localizedCaseInsensitiveContains("desk") }) {
                recs.append("Pair a targeted task lamp at the \(desk.name) to eliminate keyboard shadows and reduce evening eye strain.")
            } else {
                recs.append("Add dedicated task lamps beside your primary focus zones to reduce eye strain during evening activities.")
            }
            recs.append("Combine overhead ambient lighting with 2–3 eye-level lamps to eliminate harsh shadows and create warm vertical depth.")

        case .harmony:
            let metrics = harmonyEngine.synthesizeHarmony(room: room)
            if metrics.clearanceImprovementPercentage > 0 {
                recs.append("Your rearrangement expanded walkway clearance by +\(metrics.clearanceImprovementPercentage)% over the original room scan, clearing primary bottlenecks.")
            } else {
                recs.append("Your room layout maintains an open, clutter-free spatial flow adhering to 76–90 cm circulation standards.")
            }
            recs.append("Step into the 1:1 Life-Size AR Walkthrough to test your newly designed clearances and walkways in physical space.")
        }

        return recs
    }

    public func askMascot(
        question: String,
        currentStage: StageType,
        room: Room,
        history: [ChatMessage] = []
    ) async -> String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let followUpTriggers = ["but where", "where", "how", "which wall", "which corner", "why"]
        let isShortFollowUp = trimmed.split(whereSeparator: \.isWhitespace).count <= 4 &&
            followUpTriggers.contains { lower.contains($0) }

        let effectiveQuestion: String
        if isShortFollowUp, let lastUserPrompt = history.last(where: { $0.isUser })?.text {
            effectiveQuestion = "\(lastUserPrompt) \(trimmed)"
        } else {
            effectiveQuestion = trimmed
        }

        let q = effectiveQuestion.lowercased()
        if (q.contains("where") || q.contains("place") || q.contains("move") || q.contains("put")) &&
            (q.contains("bed") || q.contains("desk")) {
            return placementGuidance(for: q, room: room)
        } else if q.contains("clearance") || q.contains("walkway") || q.contains("space") {
            return "For room walkways, minimum 1-person passage requires at least 76.2cm (secondary paths need at least 60cm), while comfortable circulation with carrying objects needs 91.4cm. A bed-making perimeter needs 66–99cm of open space."
        } else if q.contains("light") || q.contains("window") || q.contains("sun") {
            return "A balanced room coordinates 3 essential layers: Ambient (general fill), Task (focused reading/desk lights), and Accent (visual interest). Aim for 5 to 7 light points per room to achieve balanced warmth and eliminate harsh shadows."
        } else if q.contains("focal") || q.contains("point") || q.contains("style") || q.contains("balance") {
            return "A room feels harmonious when key pieces like the bed or sofa are firmly anchored against solid walls, visual weight is distributed evenly across the room, and clear sightlines are preserved toward windows."
        } else if q.contains("bed") {
            return "Bed-to-bed clearance should be at least 91.4cm, and the bed perimeter needs 66–99cm for easily making sheets. Placing the headboard facing the entry door also helps you feel psychologically secure."
        } else if q.contains("desk") || q.contains("work") {
            return "Leave at least 76.2cm behind a desk for chair egress (91.4cm if someone walks behind). Also, angle desk lamps to avoid computer monitor glare."
        } else if q.contains("harmony") || q.contains("before") || q.contains("after") {
            return "The Harmony stage compares your new design against your baseline scan. True harmony happens when circulation paths and layered light points work together effortlessly."
        } else {
            return "Great design question! On \(currentStage.title), we focus on comfortable spatial clearances, layered lighting, and visual balance. How does the arrangement feel to you right now?"
        }
    }

    private func placementGuidance(for question: String, room: Room) -> String {
        let furnitures = room.workingLayout?.furnitures.filter { !$0.isArchived } ?? []
        let halfW = room.dimensionsWidth / 2.0
        let halfL = room.dimensionsLength / 2.0
        let zones: [(name: String, minX: Double, maxX: Double, minZ: Double, maxZ: Double)] = [
            ("Back-Left", -halfW, 0, -halfL, 0),
            ("Back-Right", 0, halfW, -halfL, 0),
            ("Front-Left", -halfW, 0, 0, halfL),
            ("Front-Right", 0, halfW, 0, halfL)
        ]

        let overlapMargin = 0.05
        var largeOccupantsByZone: [String: [Furniture]] = [:]
        for zone in zones {
            let largeItems = furnitures.filter { f in
                let absCos = abs(cos(f.rotationYaw))
                let absSin = abs(sin(f.rotationYaw))
                let extentX = (absCos * f.width + absSin * f.length) / 2.0
                let extentZ = (absSin * f.width + absCos * f.length) / 2.0
                let overlaps = (f.positionX + extentX) > (zone.minX + overlapMargin) &&
                    (f.positionX - extentX) < (zone.maxX - overlapMargin) &&
                    (f.positionZ + extentZ) > (zone.minZ + overlapMargin) &&
                    (f.positionZ - extentZ) < (zone.maxZ - overlapMargin)
                return overlaps && max(f.width, f.length) > 0.55
            }
            largeOccupantsByZone[zone.name] = largeItems
        }

        let openZones = zones.map(\.name).filter { (largeOccupantsByZone[$0] ?? []).isEmpty }
        let bed = furnitures.first { $0.category == .bed || $0.name.lowercased().contains("bed") }
        let desk = furnitures.first { $0.name.lowercased().contains("desk") } ?? furnitures.first { $0.category == .table }

        let zoneNameFor: (Furniture) -> String = { f in
            let depth = f.positionZ < 0 ? "Back" : "Front"
            let side = f.positionX < 0 ? "Left" : "Right"
            return "\(depth)-\(side)"
        }

        if question.contains("bed"), let bed {
            let bedZone = zoneNameFor(bed)
            if let desk {
                let deskZone = zoneNameFor(desk)
                if let bestOpen = openZones.first(where: { $0 != bedZone && $0 != deskZone }) {
                    return "Since \(deskZone) is occupied by your \(desk.name), place your \(bed.name) in the open \(bestOpen) zone (moving it from \(bedZone)). That puts the bed within easy reach of your desk while keeping the Back-Right work corner and central walkway clear!"
                }
                let swappable = furnitures.first {
                    $0.id != bed.id && $0.id != desk.id && max($0.width, $0.length) > 0.55
                }
                if let swappable {
                    let swapZone = zoneNameFor(swappable)
                    return "\(deskZone) is already occupied by your \(desk.name), so avoid sliding the bed straight into that corner. Instead, swap your \(bed.name) (\(bedZone)) with the \(swappable.name) (\(swapZone)), keeping clear circulation between sleep and work areas."
                }
            }
            if let openZone = openZones.first {
                return "Try moving your \(bed.name) from \(bedZone) into the open \(openZone) corner, anchored along the perimeter wall so the center stays open."
            }
        }

        if let openZone = openZones.first {
            return "Look at the open \(openZone) corner — anchoring there avoids colliding with occupied zones and keeps a comfortable walkway through the center."
        }
        return "All four perimeter zones currently hold large furniture. Try swapping two pieces across opposite corners so walkways stay clear without crowding the desk."
    }
}
