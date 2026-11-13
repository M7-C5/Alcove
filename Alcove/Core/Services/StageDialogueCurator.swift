import Foundation

/// Curates stage progression dialogues using a 2-phase pedagogical structure:
/// Phase 1: Static welcoming intro introducing stage concepts.
/// Phase 2: Dynamic, personalized "what you need" guidance tailored to the room's current state.
public struct StageDialogueCurator: Sendable {
    private let harmonyEngine = HarmonySynthesisEngine()

    public init() {}

    public func buildSteps(for stage: StageType, room: Room) -> [WalkthroughStep] {
        var steps: [WalkthroughStep] = []
        steps.append(contentsOf: staticIntroSteps(for: stage))
        if let need = dynamicNeedStep(for: stage, room: room) {
            steps.append(need)
        }
        return steps
    }

    // MARK: - Phase 1: Static Introductions
    public func staticIntroSteps(for stage: StageType) -> [WalkthroughStep] {
        switch stage {
        case .audit:
            return [
                WalkthroughStep(
                    text: "Hey there, welcome in! Are you excited to start rearranging your room together?",
                    emotion: .happy
                ),
                WalkthroughStep(
                    text: "First, let's take a gentle look at your baseline condition and natural pathways—zero pressure, we're just getting to know your space.",
                    emotion: .neutral
                )
            ]
        case .rearrangement:
            return [
                WalkthroughStep(
                    text: "Stage 2: The Rearrangement! Let's get hands-on and experiment freely.",
                    emotion: .curious
                ),
                WalkthroughStep(
                    text: "Drag pieces across the floor or tap to rotate them until it feels just right—nothing is permanent, and small nudges go a long way!",
                    emotion: .happy
                )
            ]
        case .illumination:
            return [
                WalkthroughStep(
                    text: "Stage 3: Let's bring warm, inviting light into your space!",
                    emotion: .happy
                ),
                WalkthroughStep(
                    text: "Blending gentle overhead ambient fill with cozy task lamps helps your room feel calm and layered at every hour.",
                    emotion: .neutral
                )
            ]
        case .harmony:
            return [
                WalkthroughStep(
                    text: "Amazing work—you've made it to The Harmony Reveal!",
                    emotion: .celebrating
                ),
                WalkthroughStep(
                    text: "Take a moment to enjoy how thoughtfully your new layout opens up the space compared to where we started.",
                    emotion: .happy
                )
            ]
        }
    }

    // MARK: - Phase 2: Dynamic Room-Specific Needs
    public func dynamicNeedStep(for stage: StageType, room: Room) -> WalkthroughStep? {
        let furnitures = room.workingLayout?.furnitures.filter { !$0.isArchived } ?? []
        let fixtures = room.workingLayout?.lightFixtures ?? []

        switch stage {
        case .audit:
            // 1. Check for physical circulation bottlenecks
            for i in 0..<furnitures.count {
                for j in (i + 1)..<furnitures.count {
                    let a = furnitures[i]
                    let b = furnitures[j]

                    if AnthropometricStandards.isFunctionalCompanionPair(a: a, b: b) {
                        continue
                    }

                    let dist = sqrt(pow(a.positionX - b.positionX, 2) + pow(a.positionZ - b.positionZ, 2))
                    let radiusSum = (a.width + a.length) / 4.0 + (b.width + b.length) / 4.0
                    let clearance = max(0.0, dist - radiusSum)

                    if clearance < AnthropometricStandards.minimumCirculation {
                        return WalkthroughStep(
                            text: "Gentle heads-up: the pathway between '\(a.name)' & '\(b.name)' feels a little too tight right now—totally normal in cozy rooms! Let's spot what's pinching the path so we can ease it next.",
                            emotion: .warning,
                            highlightedFurnitureName: a.name
                        )
                    }
                }
            }

            // 2. Check for heavy clutter
            if furnitures.count > 5 {
                return WalkthroughStep(
                    text: "You have \(furnitures.count) active pieces in here! For this audit, check if any unused furniture could be archived to inventory.",
                    emotion: .curious
                )
            }

            // 3. Open baseline
            return WalkthroughStep(
                text: "Your pathways look open and comfortable! Pay attention to where natural sunlight enters the space.",
                emotion: .happy
            )

        case .rearrangement:
            // 1. Identify bottleneck to solve
            for i in 0..<furnitures.count {
                for j in (i + 1)..<furnitures.count {
                    let a = furnitures[i]
                    let b = furnitures[j]

                    if AnthropometricStandards.isFunctionalCompanionPair(a: a, b: b) {
                        continue
                    }

                    let dist = sqrt(pow(a.positionX - b.positionX, 2) + pow(a.positionZ - b.positionZ, 2))
                    let radiusSum = (a.width + a.length) / 4.0 + (b.width + b.length) / 4.0
                    let clearance = max(0.0, dist - radiusSum)

                    if clearance < AnthropometricStandards.minimumCirculation {
                        return WalkthroughStep(
                            text: "Your main mission: try scooting '\(a.name)' slightly to give '\(b.name)' extra breathing room—just a gentle nudge will make walking through feel effortless!",
                            emotion: .thinking,
                            highlightedFurnitureName: a.name
                        )
                    }
                }
            }

            // 2. Check bed anchoring
            if let bed = furnitures.first(where: { $0.category == .bed }) {
                let halfW = room.dimensionsWidth / 2.0
                let halfL = room.dimensionsLength / 2.0
                let wallDist = min(halfW - abs(bed.positionX), halfL - abs(bed.positionZ))
                if wallDist > 0.8 {
                    return WalkthroughStep(
                        text: "Design tip: Try anchoring your \(bed.name)'s headboard against a solid wall for a grounded, secure feel.",
                        emotion: .curious,
                        highlightedFurnitureName: bed.name
                    )
                }
            }

            // 3. Good circulation
            return WalkthroughStep(
                text: "Great spacing! Try creating two distinct zones: one for resting, and one for working.",
                emotion: .happy
            )

        case .illumination:
            let activeFixtures = fixtures.filter { $0.isOn }

            // 1. Task lighting on desks
            let hasDesk = furnitures.contains(where: { $0.name.localizedCaseInsensitiveContains("desk") || $0.category == .table })
            let hasTaskLight = activeFixtures.contains(where: { $0.layer == .task })
            if hasDesk && !hasTaskLight {
                return WalkthroughStep(
                    text: "I noticed you have a cozy work spot set up, so adding a Desk Lamp for focused task light will make working way easier on your eyes—want to try placing one?",
                    emotion: .curious
                )
            }

            // 2. Fixture count guideline
            if activeFixtures.count < 3 {
                return WalkthroughStep(
                    text: "You currently have \(activeFixtures.count) active light source. Try adding lamps at different heights so corners don't feel shadowy!",
                    emotion: .thinking
                )
            }

            // 3. Balanced lighting
            return WalkthroughStep(
                text: "Great lighting balance! Scrub the daylight slider at the bottom to see how the room shifts from morning to golden hour.",
                emotion: .happy
            )

        case .harmony:
            let metrics = harmonyEngine.synthesizeHarmony(room: room)
            if metrics.clearanceImprovementPercentage > 0 {
                return WalkthroughStep(
                    text: "You cleared those tight spots and boosted room flow by \(metrics.clearanceImprovementPercentage)%—seriously impressive! Tap 'View in AR' whenever you want to walk through your new space at real life size!",
                    emotion: .celebrating
                )
            } else {
                return WalkthroughStep(
                    text: "I love how balanced your room weight and layered lighting feel now. Tap 'View in AR' to step inside your space in real life!",
                    emotion: .happy
                )
            }
        }
    }
}

