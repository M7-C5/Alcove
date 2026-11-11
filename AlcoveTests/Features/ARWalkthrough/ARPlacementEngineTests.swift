import Foundation
import Testing
import simd
@testable import Alcove

@Suite("AR Placement Engine Tests")
struct ARPlacementEngineTests {

    @Test func worldToLocalAndBackTransformation() {
        let roomOrigin = SIMD3<Float>(1.5, -0.4, -2.0)
        let roomYaw: Float = .pi / 4.0 // 45 degrees

        let worldPoint = SIMD3<Float>(2.0, 1.2, -1.0)
        let localPoint = ARPlacementEngine.worldToLocal(
            worldPoint: worldPoint,
            roomWorldPosition: roomOrigin,
            roomRotationYaw: roomYaw
        )

        let reconstructedWorld = ARPlacementEngine.localToWorld(
            localPoint: localPoint,
            roomWorldPosition: roomOrigin,
            roomRotationYaw: roomYaw
        )

        #expect(abs(reconstructedWorld.x - worldPoint.x) < 0.001)
        #expect(abs(reconstructedWorld.y - worldPoint.y) < 0.001)
        #expect(abs(reconstructedWorld.z - worldPoint.z) < 0.001)
    }

    @Test func placementDistanceValidation() {
        let camera = SIMD3<Float>(0, 1.5, 0)

        // Valid floor point 2 meters in front
        let validFloor = SIMD3<Float>(0, 0, -2.0)
        #expect(ARPlacementEngine.isValidPlacementDistance(cameraPosition: camera, hitPosition: validFloor))

        // Too close (e.g. 0.2m)
        let tooClose = SIMD3<Float>(0, 1.4, -0.1)
        #expect(!ARPlacementEngine.isValidPlacementDistance(cameraPosition: camera, hitPosition: tooClose))

        // Too far (e.g. 10m away)
        let tooFar = SIMD3<Float>(0, 0, -10.0)
        #expect(!ARPlacementEngine.isValidPlacementDistance(cameraPosition: camera, hitPosition: tooFar))

        // Higher than camera (ceiling or sky hit)
        let aboveCamera = SIMD3<Float>(0, 2.5, -1.0)
        #expect(!ARPlacementEngine.isValidPlacementDistance(cameraPosition: camera, hitPosition: aboveCamera))
    }

    @Test func angleNormalization() {
        #expect(abs(ARPlacementEngine.normalizeAngle(0.0) - 0.0) < 0.001)
        #expect(abs(ARPlacementEngine.normalizeAngle(.pi / 2.0) - (.pi / 2.0)) < 0.001)
        #expect(abs(ARPlacementEngine.normalizeAngle(-.pi / 2.0) - (-.pi / 2.0)) < 0.001)
        #expect(abs(cos(ARPlacementEngine.normalizeAngle(.pi * 3)) - cos(Float.pi)) < 0.001)
        #expect(abs(cos(ARPlacementEngine.normalizeAngle(-.pi * 3)) - cos(-Float.pi)) < 0.001)
    }
}
