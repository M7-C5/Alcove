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
        #expect(steps.count == 3)
        #expect(steps[0].text.contains("excited to start rearranging"))
        #expect(steps[1].text.contains("baseline condition"))
        #expect(steps[2].emotion == .warning)
        #expect(steps[2].text.contains("tight"))
    }

    @Test @MainActor func stage2RearrangementProvidesActionableGoal() {
        let room = SampleData.createStarterRoom()
        let curator = StageDialogueCurator()

        let steps = curator.buildSteps(for: .rearrangement, room: room)
        #expect(steps.count == 3)
        #expect(steps[0].text.contains("Stage 2"))
        #expect(steps[2].text.contains("mission") || steps[2].text.contains("breathing room") || steps[2].text.contains("Scoot"))
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

