import Foundation
import Testing
import simd
@testable import Alcove

@Suite("AR Walkthrough ViewModel Tests") @MainActor
struct ARWalkthroughViewModelTests {

    @Test func initializationAndStateTransitions() {
        let room = SampleData.createStarterRoom()
        let vm = ARWalkthroughViewModel(room: room)

        #expect(!vm.isPlaced)
        #expect(vm.placementState == .detectingPlanes)
        #expect(vm.instructionMessage.contains("Point iPad at the floor"))

        // Candidate plane hit detected
        let candidatePos = SIMD3<Float>(0.0, -0.5, -2.0)
        vm.updateCandidateHit(position: candidatePos)

        #expect(!vm.isPlaced)
        #expect(vm.instructionMessage.contains("Tap screen to place room"))

        // User taps to anchor room
        vm.anchorRoom()
        #expect(vm.isPlaced)
        #expect(vm.instructionMessage.contains("Walk inside"))

        // User steps inside room
        vm.updateCameraPresence(localCameraPosition: SIMD3<Float>(0, 1.5, 0))
        #expect(vm.isCameraInsideRoom)
        #expect(vm.instructionMessage.contains("You are inside"))

        // User steps outside room
        vm.updateCameraPresence(localCameraPosition: SIMD3<Float>(0, 1.5, 5.0))
        #expect(!vm.isCameraInsideRoom)

        // User repositions room
        vm.repositionRoom()
        #expect(!vm.isPlaced)
        #expect(vm.placementState == .detectingPlanes)
    }

    @Test func rotationAdjustments() {
        let room = SampleData.createStarterRoom()
        let vm = ARWalkthroughViewModel(room: room)

        let initialYaw = vm.roomRotationYaw
        vm.rotateRoom(by: .pi / 4.0)
        #expect(abs(vm.roomRotationYaw - (initialYaw + (.pi / 4.0))) < 0.001)
    }
}
