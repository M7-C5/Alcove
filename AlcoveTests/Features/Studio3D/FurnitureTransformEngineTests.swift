import Foundation
import Testing
import simd
import CoreGraphics
@testable import Alcove

@Suite("Furniture Transform Engine Tests")
struct FurnitureTransformEngineTests {

    private func makeOrientation(yaw: Float, pitch: Float) -> simd_quatf {
        let yawQuat = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        let pitchQuat = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
        return pitchQuat * yawQuat
    }

    @Test func testProjectScreenDragToFloorDirectFacing() {
        let orientation = makeOrientation(yaw: 0.0, pitch: 0.62)

        // Dragging right on screen
        let dragRight = FurnitureTransformEngine.projectScreenDragToFloor(
            translation: CGSize(width: 100, height: 0),
            orientation: orientation,
            sensitivity: 0.01
        )
        #expect(dragRight.x > 0.9)
        #expect(abs(dragRight.y) < 0.001)
        #expect(abs(dragRight.z) < 0.05)

        // Dragging up on screen (should move deeper into room, negative Z)
        let dragUp = FurnitureTransformEngine.projectScreenDragToFloor(
            translation: CGSize(width: 0, height: -100),
            orientation: orientation,
            sensitivity: 0.01
        )
        #expect(abs(dragUp.x) < 0.05)
        #expect(abs(dragUp.y) < 0.001)
        #expect(dragUp.z < -0.4) // Moving towards back wall
    }

    @Test func testClampPositionUnrotated() {
        let roomW: Float = 4.0
        let roomL: Float = 5.0
        let bedW: Float = 1.6
        let bedL: Float = 2.0
        let margin: Float = 0.05

        // Expected max X: 2.0 - 0.8 - 0.05 = 1.15
        // Expected max Z: 2.5 - 1.0 - 0.05 = 1.45
        let clampedFar = FurnitureTransformEngine.clampPosition(
            position: SIMD3<Float>(5.0, 0.0, 5.0),
            furnitureWidth: bedW,
            furnitureLength: bedL,
            rotationYaw: 0.0,
            roomWidth: roomW,
            roomLength: roomL,
            margin: margin
        )
        #expect(abs(clampedFar.x - 1.15) < 0.001)
        #expect(abs(clampedFar.z - 1.45) < 0.001)

        let clampedNeg = FurnitureTransformEngine.clampPosition(
            position: SIMD3<Float>(-5.0, 0.0, -5.0),
            furnitureWidth: bedW,
            furnitureLength: bedL,
            rotationYaw: 0.0,
            roomWidth: roomW,
            roomLength: roomL,
            margin: margin
        )
        #expect(abs(clampedNeg.x - (-1.15)) < 0.001)
        #expect(abs(clampedNeg.z - (-1.45)) < 0.001)

        // Inside bounds remains unchanged
        let inside = FurnitureTransformEngine.clampPosition(
            position: SIMD3<Float>(0.2, 0.0, -0.3),
            furnitureWidth: bedW,
            furnitureLength: bedL,
            rotationYaw: 0.0,
            roomWidth: roomW,
            roomLength: roomL,
            margin: margin
        )
        #expect(abs(inside.x - 0.2) < 0.001)
        #expect(abs(inside.z - (-0.3)) < 0.001)
    }

    @Test func testClampPositionRotated90Degrees() {
        let roomW: Float = 4.0
        let roomL: Float = 5.0
        let bedW: Float = 1.6
        let bedL: Float = 2.0
        let margin: Float = 0.05

        // When rotated 90°, effective width is 2.0, effective length is 1.6
        // Expected max X: 2.0 - 1.0 - 0.05 = 0.95
        // Expected max Z: 2.5 - 0.8 - 0.05 = 1.65
        let clampedRotated = FurnitureTransformEngine.clampPosition(
            position: SIMD3<Float>(5.0, 0.0, 5.0),
            furnitureWidth: bedW,
            furnitureLength: bedL,
            rotationYaw: Float.pi / 2.0,
            roomWidth: roomW,
            roomLength: roomL,
            margin: margin
        )
        #expect(abs(clampedRotated.x - 0.95) < 0.001)
        #expect(abs(clampedRotated.z - 1.65) < 0.001)
    }

    @Test func testNormalizeYaw() {
        #expect(abs(FurnitureTransformEngine.normalizeYaw(0.0) - 0.0) < 0.001)
        #expect(abs(FurnitureTransformEngine.normalizeYaw(2.0 * .pi) - 0.0) < 0.001)
        #expect(abs(FurnitureTransformEngine.normalizeYaw(3.0 * .pi) - .pi) < 0.001)
        #expect(abs(FurnitureTransformEngine.normalizeYaw(-.pi / 2.0) - (1.5 * .pi)) < 0.001)
    }

    @Test func testYawToDegrees() {
        #expect(FurnitureTransformEngine.yawToDegrees(0.0) == 0)
        #expect(FurnitureTransformEngine.yawToDegrees(.pi / 2.0) == 90)
        #expect(FurnitureTransformEngine.yawToDegrees(.pi) == 180)
        #expect(FurnitureTransformEngine.yawToDegrees(1.5 * .pi) == 270)
        #expect(FurnitureTransformEngine.yawToDegrees(-.pi / 2.0) == 270)
    }

    @Test func testSnapToNearest45Degrees() {
        let step = Double.pi / 4.0
        #expect(abs(FurnitureTransformEngine.snapToNearest45Degrees(0.1) - 0.0) < 0.001)
        #expect(abs(FurnitureTransformEngine.snapToNearest45Degrees(step + 0.05) - step) < 0.001)
        #expect(abs(FurnitureTransformEngine.snapToNearest45Degrees(0.7) - step) < 0.001)
    }

    @Test func testSnapYawResignMatching() {
        // Within threshold of 0: snaps to 0
        let snapZero = FurnitureTransformEngine.snapYaw(rawYaw: 0.08, step: .pi / 2.0, threshold: 0.14)
        #expect(snapZero.didSnap == true)
        #expect(abs(snapZero.yaw - 0.0) < 0.001)

        // Within threshold of π/2: snaps to π/2
        let snapNinety = FurnitureTransformEngine.snapYaw(rawYaw: Float.pi / 2.0 + 0.06, step: .pi / 2.0, threshold: 0.14)
        #expect(snapNinety.didSnap == true)
        #expect(abs(snapNinety.yaw - Float.pi / 2.0) < 0.001)

        // Outside threshold (e.g. ~25° = 0.44 rad): does NOT snap, follows smooth angle
        let freeRotate = FurnitureTransformEngine.snapYaw(rawYaw: 0.44, step: .pi / 2.0, threshold: 0.14)
        #expect(freeRotate.didSnap == false)
        #expect(abs(freeRotate.yaw - 0.44) < 0.001)
    }

    @Test func testCircularAngleDelta() {
        let center = CGPoint(x: 100, y: 100)
        let top = CGPoint(x: 100, y: 50)
        let right = CGPoint(x: 150, y: 100)
        let left = CGPoint(x: 50, y: 100)

        // Clockwise from top to right: +pi / 2
        let deltaCW = FurnitureTransformEngine.circularAngleDelta(center: center, previous: top, current: right)
        #expect(abs(deltaCW - (Float.pi / 2.0)) < 0.001)

        // Counter-clockwise from top to left: -pi / 2
        let deltaCCW = FurnitureTransformEngine.circularAngleDelta(center: center, previous: top, current: left)
        #expect(abs(deltaCCW - (-Float.pi / 2.0)) < 0.001)

        // Micro movement below threshold: 0
        let microDelta = FurnitureTransformEngine.circularAngleDelta(center: center, previous: center, current: CGPoint(x: 101, y: 101))
        #expect(microDelta == 0)
    }

    @Test @MainActor func testResetSelectedFurnitureInViewModel() {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .rearrangement)

        let bed = room.workingLayout?.furnitures.first { $0.name == "Queen Bed" }
        #expect(bed != nil)
        guard let bed else { return }

        let originalX = bed.positionX
        let originalZ = bed.positionZ
        let originalYaw = bed.rotationYaw

        vm.selectFurniture(id: bed.id)

        // Move and rotate bed
        bed.positionX += 0.5
        bed.positionZ -= 0.4
        bed.rotationYaw += .pi / 2

        #expect(bed.positionX != originalX)
        #expect(bed.rotationYaw != originalYaw)

        // Trigger reset
        vm.resetSelectedFurniture()

        #expect(abs(bed.positionX - originalX) < 0.001)
        #expect(abs(bed.positionZ - originalZ) < 0.001)
        #expect(abs(bed.rotationYaw - originalYaw) < 0.001)
        #expect(vm.mascotMessage.contains("Reset Queen Bed"))
    }
}
