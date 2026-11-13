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
            return "Welcome to \(roomName)! So glad you're here—take a cozy look around at your own pace, and we'll gently spot any tight corners or snug walkways together."
        case .rearrangement:
            return "Stage 2 unlocked—let's have fun with it! Feel free to slide and rotate pieces with zero pressure; keeping at least 76.2cm of open walkway makes moving around feel effortless."
        case .illumination:
            return "Stage 3 is all about bringing warm mood and light into your space! Slide through the daylight hours and mix ambient, task, and accent lamps—I've got your back if you want ideas."
        case .harmony:
            return "Amazing job making it to The Harmony Reveal! Drag the Before/After split slider to celebrate how thoughtfully your room has come together."
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
                dialogue: "Nice work getting started—we've mapped out your room's baseline flow together! I can already see what's working nicely and a few snug spots we can easily open up next. Ready for Stage 2 when you are!",
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
                    ? "You nailed the flow—every walkway feels spacious and comfortable (≥91.4cm)! Want to carry this great energy right into Stage 3 lighting?"
                    : (canAdvance
                        ? "You're making awesome progress and your main paths work well! Feel free to nudge any snug corners, or jump right into lighting whenever you're happy with it."
                        : "I know tight studio layouts can feel tricky, so no stress at all—a couple of walkways are just under 76.2cm right now. Let's scoot one piece slightly to give you comfy walking room!"),
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
        if q.contains("stuck") || q.contains("confused") || q.contains("overwhelmed") ||
            q.contains("unsure") || q.contains("don't know") || q.contains("dont know") ||
            q.contains("awkward") || q.contains("weird") {
            return "Totally understandable—arranging a room can feel overwhelming at first, and there's zero pressure to get it perfect in one shot! Let's start with just one anchor piece like your bed or desk, and I'll help you map out the rest step by step."
        } else if (q.contains("where") || q.contains("place") || q.contains("move") || q.contains("put")) &&
            (q.contains("bed") || q.contains("desk")) {
            return placementGuidance(for: q, room: room)
        } else if q.contains("clearance") || q.contains("walkway") || q.contains("space") {
            return "Great question! Giving yourself at least 76.2cm for main circulation paths (or 91.4cm when carrying laundry or bags, and 60cm for side paths) keeps your room feeling calm and effortless—nothing worse than bumping a hip! Would you like me to spot which path in \(room.name) to open up first?"
        } else if q.contains("light") || q.contains("window") || q.contains("sun") {
            return "Think of lighting like layering a cozy outfit: gentle overhead ambient light, focused task lamps for reading or work, and warm accent glow so corners have no harsh shadows. Pairing that with natural daylight makes a huge difference—want a tip on where your next lamp would shine best?"
        } else if q.contains("focal") || q.contains("point") || q.contains("style") || q.contains("balance") {
            return "You're already thinking like a designer! Anchoring key pieces like your bed against a solid wall, balancing visual weight across the room, and keeping clear sightlines to the window instantly makes things feel grounded—want to try anchoring one corner together?"
        } else if q.contains("bed") {
            return "Your bed is your sanctuary, so giving it cozy 66–99cm breathing room on the sides (and 91.4cm between beds) makes sheet changes and morning routines much calmer. Placing the headboard against a solid wall facing the doorway also feels super safe—want help testing a cozy bed wall?"
        } else if q.contains("desk") || q.contains("work") {
            return "Smart to think about your work comfort! Leaving about 76.2cm behind your desk lets your chair glide back smoothly, and angling a task lamp sideways keeps monitor glare away—would you like to check how your desk aligns with the window daylight?"
        } else if q.contains("harmony") || q.contains("before") || q.contains("after") {
            return "This is the best part—seeing all your thoughtful tweaks side by side against your starting scan! When easy circulation paths and layered lighting work together, your room finally feels like home—try dragging the split slider to celebrate your progress!"
        } else {
            return "I'm really glad you asked! Right now on \(currentStage.title), our goal is keeping \(room.name) comfortable, easy to walk through, and true to how you actually live—how is the space feeling to you so far, and should we look at furniture flow or lighting next?"
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
                    return "Love that you're thinking about keeping your bed and desk connected! Since \(deskZone) already holds your \(desk.name), tucking your \(bed.name) into the open \(bestOpen) zone keeps them handy to each other while preserving clear walking flow—feel free to drag it there and see how it feels!"
                }
                let swappable = furnitures.first {
                    $0.id != bed.id && $0.id != desk.id && max($0.width, $0.length) > 0.55
                }
                if let swappable {
                    let swapZone = zoneNameFor(swappable)
                    return "Makes total sense wanting your bed closer to your desk! Right now \(deskZone) holds your \(desk.name), so instead of squeezing them together, try gently swapping your \(bed.name) (\(bedZone)) with the \(swappable.name) (\(swapZone))—I think you'll love how much calmer the walkway feels!"
                }
            }
            if let openZone = openZones.first {
                return "Great instinct! Try sliding your \(bed.name) from \(bedZone) over to the open \(openZone) corner along the wall—it'll open up the center nicely, and you can always nudge it right back if you prefer!"
            }
        }

        if let openZone = openZones.first {
            return "You've got a lovely open spot in the \(openZone) corner! Sliding a piece there gives the center room to breathe and keeps your daily path super comfortable—want to give that corner a try?"
        }
        return "Studio layouts can definitely feel packed when every corner already holds something, so don't worry! Try swapping two pieces across opposite walls first so your desk and main walkway both get some breathing room."
    }
}
