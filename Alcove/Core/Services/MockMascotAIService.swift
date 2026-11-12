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
            if let tight = bottlenecks.first {
                let itemName = tight.affectedFurnitureName ?? "furniture"
                recs.append("Notice the snug corridor by the \(itemName)—this will be your top priority to open up in Stage 2.")
            } else {
                recs.append("Your main walking pathways feel naturally open and uncluttered.")
            }

            if let desk = furnitures.first(where: { $0.category == .table || $0.name.localizedCaseInsensitiveContains("desk") }) {
                recs.append("The \(desk.name) setup has clear sightlines; notice how daylight enters across its workspace.")
            } else if let bed = furnitures.first(where: { $0.category == .bed }) {
                recs.append("The \(bed.name) anchors the room; check that walking around it feels effortless.")
            } else {
                recs.append("Take note of where natural daylight creates the brightest zones across your floor.")
            }

        case .rearrangement:
            if !bottlenecks.isEmpty {
                for b in bottlenecks.prefix(2) {
                    let itemName = b.affectedFurnitureName ?? "furniture"
                    recs.append("Nudge the \(itemName) slightly to widen the pathway and give you comfortable walking clearance.")
                }
            } else {
                if let mainItem = furnitures.first(where: { $0.category == .bed || $0.category == .table }) {
                    recs.append("Circulation around the \(mainItem.name) is spacious and exceeds comfortable walking standards.")
                }
                if let chair = furnitures.first(where: { $0.category == .seating }),
                   let desk = furnitures.first(where: { $0.category == .table }) {
                    recs.append("Your \(chair.name) has plenty of pushback room behind the \(desk.name) for easy sit-to-stand movement.")
                } else {
                    recs.append("All primary pathways are wide and inviting—great spatial balance!")
                }
            }

        case .illumination:
            break

        case .harmony:
            let metrics = harmonyEngine.synthesizeHarmony(room: room)
            if metrics.clearanceImprovementPercentage > 0 {
                recs.append("Your rearrangement increased walkway clearance by +\(metrics.clearanceImprovementPercentage)% over the original room scan.")
            } else {
                recs.append("Your room layout maintains an open, clutter-free spatial flow.")
            }
            recs.append("Step into the 1:1 Life-Size AR Walkthrough to test your new pathways in physical space.")
        }

        return recs
    }

    public func askMascot(
        question: String,
        currentStage: StageType,
        room: Room
    ) async -> String {
        let q = question.lowercased()
        if q.contains("clearance") || q.contains("walkway") || q.contains("space") {
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
}
