import Foundation
import Testing
@testable import Alcove

@Suite("Harmony Synthesis Tests") @MainActor
struct HarmonySynthesisEngineTests {

    @Test func synthesizeHarmonyFromStarterRoom() {
        let engine = HarmonySynthesisEngine()
        let room = SampleData.createStarterRoom()

        let metrics = engine.synthesizeHarmony(room: room)

        #expect(metrics.overallHarmonyScore >= 50)
        #expect(metrics.activeItemsCount > 0)
        #expect(metrics.workingFloorUtilizationPercentage > 0)
        #expect(!metrics.summaryVerdict.isEmpty)
    }

    @Test func harmonyImprovementWhenBottlenecksCleared() {
        let engine = HarmonySynthesisEngine()
        let room = SampleData.createStarterRoom()

        // Initially move Queen Bed right next to Work Desk (< 30cm) to create a bottleneck in baseline
        if let bed = room.baselineLayout?.furnitures.first(where: { $0.name == "Queen Bed" }),
           let desk = room.baselineLayout?.furnitures.first(where: { $0.name == "Work Desk" }) {
            bed.positionX = desk.positionX + 0.2
            bed.positionZ = desk.positionZ + 0.2
        }

        // In working layout, spread them generously
        if let workingBed = room.workingLayout?.furnitures.first(where: { $0.name == "Queen Bed" }) {
            workingBed.positionX = -1.5
            workingBed.positionZ = -1.5
        }

        let metrics = engine.synthesizeHarmony(room: room)
        #expect(metrics.baselineBottlenecksCount > metrics.workingBottlenecksCount)
        #expect(metrics.clearanceImprovementPercentage > 0)
        #expect(metrics.isImprovement == true)
    }

    @Test func harmonyRevealModeProperties() {
        let modes = HarmonyRevealMode.allCases
        #expect(modes.count == 3)
        #expect(modes.contains(.splitSlider))
        #expect(modes.contains(.sideBySide))
        #expect(modes.contains(.overlayDiff))

        for mode in modes {
            #expect(!mode.id.isEmpty)
            #expect(!mode.title.isEmpty)
            #expect(!mode.icon.isEmpty)
        }
    }

    @Test func tightestWalkwayCalculation() {
        let engine = HarmonySynthesisEngine()
        let room = SampleData.createStarterRoom()

        let metrics = engine.synthesizeHarmony(room: room)

        #expect(metrics.baselineTightestWalkwayMeters >= 0.20)
        #expect(metrics.workingTightestWalkwayMeters >= 0.20)
        #expect(metrics.baselineTightestWalkwayMeters <= 2.50)
        #expect(metrics.workingTightestWalkwayMeters <= 2.50)
    }

    @Test func studio3DViewModelHarmonyTourAndScorecard() async {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .harmony)

        #expect(vm.currentStage == .harmony)
        #expect(vm.showingScorecardSheet == false)
        #expect(vm.isTouringCinematicWalkthrough == false)

        vm.openScorecardSheet()
        #expect(vm.showingScorecardSheet == true)

        var lastPreset: ViewportPreset?
        vm.snapToViewport = { preset in
            lastPreset = preset
        }

        vm.startCinematicWalkthroughTour()
        #expect(vm.isTouringCinematicWalkthrough == true)
        #expect(lastPreset == .dollhouse)

        vm.stopCinematicWalkthroughTour()
        #expect(vm.isTouringCinematicWalkthrough == false)
        #expect(lastPreset == .dollhouse)

        vm.completeHarmonyCurriculum()
        #expect(room.isCompleted(.harmony) == true)
        #expect(vm.mascotEmotion == .celebrating)
    }
}
