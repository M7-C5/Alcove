import Foundation
import Testing
@testable import Alcove

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
    }

    @Test func mascotAskContextualAnswers() async {
        let mascot = MockMascotAIService()
        let room = SampleData.createStarterRoom()

        let clearanceAnswer = await mascot.askMascot(
            question: "What is the recommended walkway clearance?",
            currentStage: .rearrangement,
            room: room
        )
        #expect(clearanceAnswer.contains("60cm"))

        let lightAnswer = await mascot.askMascot(
            question: "How should I place items near a window for natural light?",
            currentStage: .illumination,
            room: room
        )
        #expect(lightAnswer.contains("shadows") || lightAnswer.contains("daylight"))
    }
}
