import Testing
import Foundation
@testable import Alcove

@Suite("Stage Dialogue Curator Tests")
struct StageDialogueCuratorTests {

    @Test @MainActor func allStagesHaveStaticIntroAndDynamicNeed() {
        let room = SampleData.createStarterRoom()
        let curator = StageDialogueCurator()

        for stage in StageType.allCases {
            let steps = curator.buildSteps(for: stage, room: room)
            #expect(steps.count >= 3, "Stage \(stage) should have at least 2 static intro steps + 1 dynamic need step")
        }
    }

    @Test @MainActor func stage1AuditDetectsTightPathwayNeed() {
        let room = SampleData.createStarterRoom()
        let curator = StageDialogueCurator()

        let steps = curator.buildSteps(for: .audit, room: room)
        #expect(steps.count == 4)
        #expect(steps[0].text == "Hey there! Are you excited to start rearranging your room?")
        #expect(steps[0].requiredAction == nil)
        #expect(steps[1].text == "But first, take a look at your scanned room!")
        #expect(steps[1].requiredAction == nil)
        #expect(steps[2].text == "Then, try to rotate, zoom in, or zoom out to get a better room view!")
        #expect(steps[2].requiredAction == .inspectCamera)
        #expect(steps[3].emotion == .warning)
        #expect(steps[3].text.contains("tight"))
        #expect(steps[3].requiredAction == nil)
    }

    @Test @MainActor func stage2RearrangementProvidesActionableGoal() {
        let room = SampleData.createStarterRoom()
        let curator = StageDialogueCurator()

        let steps = curator.buildSteps(for: .rearrangement, room: room)
        #expect(steps.count == 4)
        #expect(steps[0].text == "Drag a furniture to move it around!")
        #expect(steps[0].requiredAction == .dragFurniture)
        #expect(steps[1].text.contains("rotate, archive, or change"))
        #expect(steps[1].text.contains("swapping a lamp for a bed"))
        #expect(steps[1].requiredAction == .transformFurniture)
        #expect(steps[2].text.contains("'+' button at the top right"))
        #expect(steps[2].requiredAction == .addFurniture)
        #expect(steps[3].text.contains("mission") || steps[3].text.contains("breathing room") || steps[3].text.contains("Scoot"))
        #expect(steps[3].requiredAction == nil)
    }

    @Test @MainActor func stage3IlluminationRecommendsLightingNeed() {
        let room = SampleData.createStarterRoom()
        let curator = StageDialogueCurator()

        let steps = curator.buildSteps(for: .illumination, room: room)
        #expect(steps.count == 3)
        #expect(steps[0].text.contains("Stage 3"))
        #expect(steps[2].text.contains("task") || steps[2].text.contains("Lamp") || steps[2].text.contains("light"))
    }

    @Test @MainActor func stage4HarmonyCelebratesAndInvitesAR() {
        let room = SampleData.createStarterRoom()
        let curator = StageDialogueCurator()

        let steps = curator.buildSteps(for: .harmony, room: room)
        #expect(steps.count == 3)
        #expect(steps[0].text.contains("Harmony Reveal"))
        #expect(steps[2].text.contains("AR"))
    }
}

