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
            return "Stage 2 unlocked! Now you can grab, slide, and rotate furniture. Aim for at least 60cm of open walkway clearance."
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
                    title: "High Density Clutter",
                    detail: "The room contains \(furnitures.count) active pieces. Consider archiving or spacing them out.",
                    severity: .notice
                ))
            }

            return StageEvaluationResult(
                canAdvance: true,
                score: 85,
                title: "Audit Complete",
                dialogue: "You've thoroughly inspected the space! Notice the high-traffic pathways. When you're ready, let's move to Stage 2 to rearrange.",
                bottlenecks: bottlenecks,
                recommendations: ["Review clearances near entry door", "Identify natural light focal wall"],
                praise: ["Baseline scan captured cleanly", "Room boundaries well defined"]
            )

        case .rearrangement:
            var bottlenecks: [SpatialBottleneck] = []
            var score = 90

            // Check clearances between all pairs
            for i in 0..<furnitures.count {
                for j in (i + 1)..<furnitures.count {
                    let a = furnitures[i]
                    let b = furnitures[j]
                    let dx = a.positionX - b.positionX
                    let dz = a.positionZ - b.positionZ
                    let dist = sqrt(dx * dx + dz * dz)
                    let minAllowed = (a.width + b.width) / 2.0 + 0.50

                    if dist < minAllowed {
                        bottlenecks.append(SpatialBottleneck(
                            title: "Tight Walkway Between \(a.name) & \(b.name)",
                            detail: "Current clearance is ~\(String(format: "%.0f", dist * 100))cm. Standard interior design recommends at least 60cm.",
                            severity: .warning,
                            affectedFurnitureName: a.name
                        ))
                        score -= 10
                    }
                }
            }

            let canAdvance = bottlenecks.filter { $0.severity == .critical }.isEmpty
            return StageEvaluationResult(
                canAdvance: canAdvance,
                score: max(score, 50),
                title: bottlenecks.isEmpty ? "Flawless Layout!" : "Good Progress!",
                dialogue: bottlenecks.isEmpty
                    ? "Incredible circulation! All walkways are spacious and inviting."
                    : "I spotted a few tight spots. You can tweak them or proceed anyway if you like this intimate layout!",
                bottlenecks: bottlenecks,
                recommendations: ["Ensure minimum 60cm circulation", "Keep main doorway unimpeded"],
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

            return StageEvaluationResult(
                canAdvance: true,
                score: metrics.overallHarmonyScore,
                title: "Spatial Harmony Achieved!",
                dialogue: "\(metrics.summaryVerdict) Walkway clearance improved by \(metrics.clearanceImprovementPercentage)% over baseline scan.",
                bottlenecks: [],
                recommendations: ["Export room summary report", "Test layout with real furniture placement"],
                praise: [
                    "Floor space optimized at \(metrics.workingFloorUtilizationPercentage)% utilization",
                    "Clearance bottlenecks reduced to \(metrics.workingBottlenecksCount)"
                ]
            )
        }
    }

    public func askMascot(
        question: String,
        currentStage: StageType,
        room: Room
    ) async -> String {
        let q = question.lowercased()
        if q.contains("clearance") || q.contains("walkway") || q.contains("space") {
            return "In interior design, secondary walkways need at least 60cm (24 inches), while primary paths (like from the door to the bed) feel best with 90cm (36 inches) of unobstructed flow."
        } else if q.contains("light") || q.contains("window") || q.contains("sun") {
            return "Always balance your 4 lighting layers: daylight from windows without harsh shadows, ambient overhead fill (150-300 lux), task lamps on desks/beds, and accent lighting to add visual depth."
        } else if q.contains("focal") || q.contains("point") {
            return "Every room needs a strong anchor. Whether it's a large window, artwork, or your bed/desk, orient key seating towards it to create visual harmony."
        } else if q.contains("harmony") || q.contains("before") || q.contains("after") {
            return "The Harmony stage compares your new design directly against your initial LiDAR scan. Notice how removing bottlenecks and decluttering opens up natural sightlines."
        } else {
            return "Great question! On \(currentStage.title), focus on creating open breathing room. Small changes in furniture angle or lighting can completely transform how large the room feels."
        }
    }
}
