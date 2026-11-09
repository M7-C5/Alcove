import Foundation
import Testing
@testable import Alcove

@Suite("Stages Slice Tests") @MainActor
struct StageListViewModelTests {

    @Test func stageProgressionAndProgressCalculation() {
        let room = SampleData.createStarterRoom()
        let vm = StageListViewModel(room: room)

        #expect(vm.totalStagesCount == 4)
        #expect(vm.completedStagesCount == 0)
        #expect(vm.progressRatio == 0.0)

        // Complete Stage 1 (Audit)
        room.completeStage(.audit, score: 90, feedback: "Great flow")
        #expect(vm.completedStagesCount == 1)
        #expect(vm.progressRatio == 0.25)

        // Complete Stage 2 (Rearrangement)
        room.completeStage(.rearrangement, score: 85, feedback: "Comfortable pathways")
        #expect(vm.completedStagesCount == 2)
        #expect(vm.progressRatio == 0.50)

        // Complete Stage 3 (Illumination) & 4 (Harmony)
        room.completeStage(.illumination, score: 90, feedback: "Bright")
        room.completeStage(.harmony, score: 95, feedback: "Perfect")
        #expect(vm.completedStagesCount == 4)
        #expect(vm.progressRatio == 1.0)
    }

    @Test func resetWorkingLayoutRestoresBaseline() {
        let room = SampleData.createStarterRoom()
        let vm = StageListViewModel(room: room)

        // Mutate working layout
        if let first = room.workingLayout?.furnitures.first {
            first.positionX = 99.0
            first.positionZ = 99.0
        }

        vm.resetWorkingLayoutToBaseline()

        let resetFirst = room.workingLayout?.furnitures.first
        let baselineFirst = room.baselineLayout?.furnitures.first
        #expect(resetFirst?.positionX == baselineFirst?.positionX)
        #expect(resetFirst?.positionZ == baselineFirst?.positionZ)
        #expect(room.workingLayout?.room === room)
    }
}
