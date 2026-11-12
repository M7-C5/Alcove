import Foundation
import Testing
@testable import Alcove

@Suite @MainActor
struct AlcoveCoreTests {

    @Test func stageTypeProgressionAndTools() {
        let stage1 = StageType.audit
        let stage2 = StageType.rearrangement
        let stage3 = StageType.illumination
        let stage4 = StageType.harmony

        #expect(stage1.nextStage == .rearrangement)
        #expect(stage2.nextStage == .illumination)
        #expect(stage3.nextStage == .harmony)
        #expect(stage4.nextStage == nil)

        // Verify tool gating progression
        #expect(stage1.unlockedTools.contains(.inspectCamera))
        #expect(!stage1.unlockedTools.contains(.dragFurniture))

        #expect(stage2.unlockedTools.contains(.dragFurniture))
        #expect(stage2.unlockedTools.contains(.rotateFurniture))
        #expect(!stage2.unlockedTools.contains(.sunScrubber))

        #expect(stage3.unlockedTools.contains(.sunScrubber))
        #expect(stage3.unlockedTools.contains(.addLightFixture))
        #expect(!stage3.unlockedTools.contains(.splitBeforeAfter))

        #expect(stage4.unlockedTools.contains(.splitBeforeAfter))
        #expect(stage4.unlockedTools.contains(.arWalkthrough))
    }

    @Test func dualLayoutPreservationAndReset() {
        let room = SampleData.createStarterRoom()
        let initialWorkingCount = room.workingLayout?.furnitures.count ?? 0
        let baselineCount = room.baselineLayout?.furnitures.count ?? 0

        #expect(initialWorkingCount == baselineCount)
        #expect(room.baselineLayout?.isBaseline == true)
        #expect(room.workingLayout?.isBaseline == false)

        // Mutate working layout: move the Queen Bed
        if let bed = room.workingLayout?.furnitures.first(where: { $0.name == "Queen Bed" }) {
            bed.positionX = 0.5
            bed.positionZ = 0.5
        }

        // Verify baseline bed remained untouched at -1.2, -1.5
        let baselineBed = room.baselineLayout?.furnitures.first(where: { $0.name == "Queen Bed" })
        #expect(baselineBed?.positionX == -1.2)
        #expect(baselineBed?.positionZ == -1.5)

        // Reset working layout to baseline
        room.resetWorkingLayoutToBaseline()
        let resetBed = room.workingLayout?.furnitures.first(where: { $0.name == "Queen Bed" })
        #expect(resetBed?.positionX == -1.2)
        #expect(resetBed?.positionZ == -1.5)
    }

    @Test func fastPathClearanceMicroReaction() {
        let rulebook = FastPathRulebook()
        let otherItem = Furniture(
            name: "Desk",
            category: .table,
            positionX: 0.0,
            positionY: 0.0,
            positionZ: 0.0,
            width: 1.0,
            length: 1.0
        )

        // Move chair dangerously close (< 30cm) to Desk
        let event = FurnitureMoveEvent(
            furnitureName: "Chair",
            category: .seating,
            oldPosition: (x: 2.0, z: 2.0),
            newPosition: (x: 0.2, z: 0.2),
            rotationYaw: 0.0
        )

        let reaction = rulebook.evaluateMicroMove(
            event: event,
            roomDimensions: (width: 4.0, length: 5.0),
            allFurnitures: [otherItem]
        )

        #expect(reaction != nil)
        #expect(reaction?.emotion == .warning)
        #expect(reaction?.message.contains("Desk") == true)
    }

    @Test func lampOverlappingTableDoesNotTriggerCrowdingWarning() {
        let rulebook = FastPathRulebook()
        let desk = Furniture(
            name: "Work Desk",
            category: .table,
            positionX: 0.0,
            positionY: 0.0,
            positionZ: 0.0,
            width: 1.2,
            length: 0.8
        )

        // Move a Desk Lamp directly on top of the Work Desk (overlap at 0, 0)
        let lampEvent = FurnitureMoveEvent(
            furnitureName: "Desk Lamp",
            category: .lighting,
            oldPosition: (x: 1.0, z: 1.0),
            newPosition: (x: 0.0, z: 0.0),
            rotationYaw: 0.0
        )

        let reaction = rulebook.evaluateMicroMove(
            event: lampEvent,
            roomDimensions: (width: 4.0, length: 5.0),
            allFurnitures: [desk]
        )

        // A lamp sitting on or near a desk must NEVER trigger a crowding/bottleneck warning
        #expect(reaction?.emotion != .warning)
    }

    @Test func floorLampBesideChairAndDeskRecognizedAsTaskLighting() async {
        let rulebook = FastPathRulebook()
        let chair = Furniture(
            name: "Ergonomic Chair",
            category: .seating,
            positionX: 1.3,
            positionY: 0.0,
            positionZ: -0.3,
            width: 0.6,
            length: 0.6
        )

        // Move a Floor Lamp right beside the chair (~40cm away)
        let lampEvent = FurnitureMoveEvent(
            furnitureName: "Floor Lamp",
            category: .lighting,
            oldPosition: (x: -1.8, z: -2.0),
            newPosition: (x: 1.3, z: 0.1),
            rotationYaw: 0.0
        )

        let reaction = rulebook.evaluateMicroMove(
            event: lampEvent,
            roomDimensions: (width: 4.5, length: 5.0),
            allFurnitures: [chair]
        )

        // Must recognize intentional task lighting with happy emotion, never a warning
        #expect(reaction?.emotion == .happy)
        #expect(reaction?.message.contains("Task lighting") == true)

        // Stage 1 Audit evaluation should NOT flag this pairing as a bottleneck
        let service = MockMascotAIService()
        let room = SampleData.createStarterRoom()
        if let lamp = room.workingLayout?.furnitures.first(where: { $0.name == "Floor Lamp" }),
           let deskChair = room.workingLayout?.furnitures.first(where: { $0.name == "Ergonomic Chair" }) {
            lamp.positionX = deskChair.positionX
            lamp.positionZ = deskChair.positionZ + 0.4
        }

        let evalResult = await service.evaluateStage(stage: .audit, room: room)
        let lampChairBottleneck = evalResult.bottlenecks.first(where: {
            $0.title.contains("Floor Lamp") && $0.title.contains("Ergonomic Chair")
        })
        #expect(lampChairBottleneck == nil)
    }

    @Test func fastPathDaylightMicroReactions() {
        let rulebook = FastPathRulebook()
        let desk = Furniture(
            name: "Work Desk",
            category: .table,
            positionX: 0.0,
            positionY: 0.0,
            positionZ: 0.0,
            width: 1.2,
            length: 0.8
        )

        // 1. Morning (9:00 AM) with desk -> soft rays & work angle
        let morningReaction = rulebook.evaluateDaylightChange(
            hour: 9.0,
            furnitures: [desk],
            fixtures: []
        )
        #expect(morningReaction != nil)
        #expect(morningReaction?.emotion == .happy)
        #expect(morningReaction?.message.contains("morning") == true)

        // 2. Midday (13:00 PM) -> glare warning
        let middayReaction = rulebook.evaluateDaylightChange(
            hour: 13.0,
            furnitures: [desk],
            fixtures: []
        )
        #expect(middayReaction != nil)
        #expect(middayReaction?.emotion == .thinking)
        #expect(middayReaction?.message.contains("glare") == true)

        // 3. Golden Hour (17:00 PM) -> warm mood
        let goldenReaction = rulebook.evaluateDaylightChange(
            hour: 17.0,
            furnitures: [desk],
            fixtures: []
        )
        #expect(goldenReaction != nil)
        #expect(goldenReaction?.emotion == .happy)
        #expect(goldenReaction?.message.contains("Golden hour") == true)

        // 4. Evening (20:00 PM) without lights -> warning to turn on lamps
        let eveningDimReaction = rulebook.evaluateDaylightChange(
            hour: 20.0,
            furnitures: [desk],
            fixtures: []
        )
        #expect(eveningDimReaction != nil)
        #expect(eveningDimReaction?.emotion == .warning)

        // 5. Evening (20:00 PM) with active lamps -> warm cozy approval
        let lamp = LightFixture(name: "Floor Lamp", layer: .ambient, lumens: 800, isOn: true)
        let eveningLitReaction = rulebook.evaluateDaylightChange(
            hour: 20.0,
            furnitures: [desk],
            fixtures: [lamp]
        )
        #expect(eveningLitReaction != nil)
        #expect(eveningLitReaction?.emotion == .happy)
    }

    @Test func mockMascotEvaluationStageGates() async {
        let mascot = MockMascotAIService()
        let room = SampleData.createStarterRoom()

        // Stage 1 Audit evaluation
        let auditResult = await mascot.evaluateStage(stage: .audit, room: room)
        #expect(auditResult.canAdvance == true)
        #expect(auditResult.score >= 80)
        #expect(!auditResult.dialogue.isEmpty)

        // Stage 2 Rearrangement evaluation
        let rearrangeResult = await mascot.evaluateStage(stage: .rearrangement, room: room)
        #expect(rearrangeResult.score >= 50)
        #expect(!rearrangeResult.recommendations.isEmpty)

        // Complete Stage 1 and unlock Stage 2
        room.completeStage(.audit, score: auditResult.score, feedback: auditResult.dialogue)
        #expect(room.isCompleted(.audit) == true)
        #expect(room.isUnlocked(.rearrangement) == true)
        #expect(room.isUnlocked(.illumination) == false)

        // Stage 3 Illumination evaluation
        let illumResult = await mascot.evaluateStage(stage: .illumination, room: room)
        #expect(illumResult.canAdvance == true)
        #expect(illumResult.score >= 70)

        // Stage 4 Harmony evaluation
        let harmonyResult = await mascot.evaluateStage(stage: .harmony, room: room)
        #expect(harmonyResult.canAdvance == true)
        #expect(harmonyResult.score >= 50)
    }

    @Test func mascotAskContextualAnswers() async {
        let mascot = MockMascotAIService()
        let room = SampleData.createStarterRoom()

        let clearanceAnswer = await mascot.askMascot(
            question: "What is the recommended walkway clearance?",
            currentStage: .rearrangement,
            room: room
        )
        #expect(clearanceAnswer.contains("76.2cm") || clearanceAnswer.contains("60cm"))
        #expect(clearanceAnswer.contains("circulation") || clearanceAnswer.contains("passage") || clearanceAnswer.contains("Panero & Zelnik"))

        let lightAnswer = await mascot.askMascot(
            question: "How should I place items near a window for natural light?",
            currentStage: .illumination,
            room: room
        )
        #expect(lightAnswer.contains("shadows") || lightAnswer.contains("daylight"))
    }

    @Test func mockRoomGeneratorBedroomOfficeCombo() {
        let room = MockRoomGenerator.generateBedroomOfficeCombo()

        #expect(room.name == "Bedroom & Office Combo")
        #expect(room.dimensionsWidth == 4.5)
        #expect(room.dimensionsLength == 4.0)
        #expect(room.dimensionsHeight == 2.6)

        guard let furnitures = room.workingLayout?.furnitures else {
            Issue.record("Working layout furnitures should exist")
            return
        }

        #expect(furnitures.count == 6)
        #expect(furnitures.contains(where: { $0.name == "Queen Bed" && $0.category == .bed }))
        #expect(furnitures.contains(where: { $0.name == "Bedside Nightstand" && $0.category == .table }))
        #expect(furnitures.contains(where: { $0.name == "Double Wardrobe Cupboard" && $0.category == .storage }))
        #expect(furnitures.contains(where: { $0.name == "Home Office Desk" && $0.category == .table }))
        #expect(furnitures.contains(where: { $0.name == "Ergonomic Desk Chair" && $0.category == .seating }))
        #expect(furnitures.contains(where: { $0.name == "Corner Floor Lamp" && $0.category == .lighting }))

        // Ensure baseline layout was also populated
        #expect(room.baselineLayout?.furnitures.count == 6)
    }
}
