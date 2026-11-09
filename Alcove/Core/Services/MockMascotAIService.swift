import Foundation

/// Deterministic mock implementation of MascotAIServiceProtocol for offline development, previews, and tests
@MainActor
public final class MockMascotAIService: MascotAIServiceProtocol {
    private let rulebook = FastPathRulebook()

    public init() {}

    public func stageGreeting(stage: StageType, roomName: String) -> String {
        switch stage {
        case .audit:
            return "Welcome to \(roomName)! Let's begin by assessing your current space. Look around and spot any tight corners or obstructed paths."
        case .rearrangement:
            return "Stage 2 unlocked! Now you can grab, slide, and rotate furniture. Aim for at least 60cm of open walkway clearance."
        case .illumination:
            return "Stage 3 is all about light! Scrub through daylight hours to observe sun angles, and add ambient or accent lighting where shadows pool."
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
            return StageEvaluationResult(
                canAdvance: true,
                score: 88,
                title: "Illumination Balanced",
                dialogue: "Warm ambient fill with clean daylight interplay. Your space feels inviting morning through evening.",
                bottlenecks: [],
                recommendations: ["Add a small reading lamp near the bedside or desk"],
                praise: ["Natural light unobstructed", "Balanced illumination gradient"]
            )

        case .harmony:
            return StageEvaluationResult(
                canAdvance: true,
                score: 95,
                title: "Spatial Harmony Achieved!",
                dialogue: "You've successfully reimagined your room! Look how much more functional and aesthetic your living space is now.",
                bottlenecks: [],
                recommendations: ["Export room summary report", "Test in real world"],
                praise: ["Mastered 4 design principles", "Created open, flowing space"]
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
            return "Always avoid placing tall bookshelves or bulky wardrobes directly beside windows—they cast harsh shadows and cut off natural daylight bounce."
        } else if q.contains("focal") || q.contains("point") {
            return "Every room needs a strong anchor. Whether it's a large window, artwork, or your bed/desk, orient key seating towards it to create visual harmony."
        } else {
            return "Great question! On \(currentStage.title), focus on creating open breathing room. Small changes in furniture angle or lighting can completely transform how large the room feels."
        }
    }
}
