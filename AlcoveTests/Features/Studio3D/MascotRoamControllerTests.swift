import Foundation
import RealityKit
import Testing
import simd
@testable import Alcove

@Suite("Mascot Roaming & Otter USDZ Tests") @MainActor
struct MascotRoamControllerTests {

    @Test func otterUSDZLoadsAndNormalizesToTargetHeight() {
        let controller = MascotRoamController()
        #expect(controller.hasLoadedModel == true)
        #expect(controller.hasEmbeddedAnimation == true)
        #expect(controller.rootEntity.name == "MascotOtterRoot")

        let bounds = controller.rootEntity.visualBounds(relativeTo: controller.rootEntity)
        #expect(abs(bounds.extents.y - MascotRoamingEngine.targetHeight) < 0.05)
        #expect(abs(bounds.min.y) < 0.03)
        #expect(!hasCollisionOrInputComponents(in: controller.rootEntity))
    }

    @Test func roamingEngineAvoidsWallsAndFurnitureObstacles() {
        let roomSize = SIMD2<Float>(4.0, 4.0)
        let rotatedDesk = MascotRoamingEngine.Obstacle(
            id: UUID(),
            center: SIMD2<Float>(0.5, 0.0),
            size: SIMD2<Float>(1.2, 0.6),
            yaw: .pi / 2.0
        )

        // Inside rotated obstacle footprint
        #expect(MascotRoamingEngine.isPointClear(SIMD2<Float>(0.5, 0.5), roomSize: roomSize, obstacles: [rotatedDesk]) == false)
        // Too close to room wall
        #expect(MascotRoamingEngine.isPointClear(SIMD2<Float>(1.85, 0.0), roomSize: roomSize, obstacles: [rotatedDesk]) == false)
        // Clear open floor spot
        #expect(MascotRoamingEngine.isPointClear(SIMD2<Float>(-0.9, -0.8), roomSize: roomSize, obstacles: [rotatedDesk]) == true)
    }

    @Test func focusOnFurnitureWalksToClearApproachSpotAndFacesItem() {
        let roomSize = SIMD2<Float>(4.5, 4.0)
        let bed = MascotRoamingEngine.Obstacle(
            id: UUID(),
            center: SIMD2<Float>(0.0, -0.8),
            size: SIMD2<Float>(1.6, 2.0),
            yaw: 0.0
        )

        let controller = MascotRoamController()
        controller.configureInitialPosition(roomSize: roomSize, obstacles: [bed])
        controller.focusOnFurniture(bed, roomSize: roomSize, obstacles: [bed])

        guard case .walking(let path, let lookAt) = controller.state.activity,
              let destination = path.last else {
            Issue.record("Expected Otter to enter .walking state after focusOnFurniture")
            return
        }
        #expect(lookAt == bed.center)
        #expect(MascotRoamingEngine.isPointClear(destination, roomSize: roomSize, obstacles: [bed]))

        // Step simulation forward until arrival at the furniture approach spot
        var rng = SystemRandomNumberGenerator()
        var state = controller.state
        var sawWaddle = false
        var arrivedLookingAtBed = false
        for _ in 0..<240 {
            MascotRoamingEngine.step(state: &state, dt: 1.0 / 30.0, roomSize: roomSize, obstacles: [bed], rng: &rng)
            if case .walking = state.activity, state.verticalOffset > 0.001 {
                sawWaddle = true
            }
            if case .idle(_, let targetLook) = state.activity, targetLook == bed.center {
                arrivedLookingAtBed = true
                break
            }
        }
        #expect(sawWaddle == true)
        #expect(arrivedLookingAtBed == true)
        #expect(simd_distance(state.position, destination) < 0.05)
    }

    @Test func triggerHappyHopAnimatesVerticalJumpAndReturnsToIdle() {
        let roomSize = SIMD2<Float>(4.0, 4.0)
        let controller = MascotRoamController()
        controller.configureInitialPosition(roomSize: roomSize, obstacles: [])
        controller.triggerHappyHop()

        guard case .hopping = controller.state.activity else {
            Issue.record("Expected Otter to enter .hopping state")
            return
        }

        controller.update(dt: 0.1, roomSize: roomSize, obstacles: [])
        #expect(controller.state.verticalOffset > 0.05)

        // Advance past hop duration (0.55s)
        for _ in 0..<8 {
            controller.update(dt: 0.1, roomSize: roomSize, obstacles: [])
        }
        if case .idle = controller.state.activity {
            // Expected
        } else {
            Issue.record("Expected Otter to return to .idle after hop finishes")
        }
    }

    @Test func otterRoutesAroundBlockingFurnitureWithoutPhasingThrough() {
        let roomSize = SIMD2<Float>(4.5, 4.0)
        let barrier = MascotRoamingEngine.Obstacle(
            id: UUID(),
            center: SIMD2<Float>(0.0, 0.0),
            size: SIMD2<Float>(0.6, 1.8),
            yaw: 0.0
        )
        let goal = SIMD2<Float>(1.2, 0.0)
        let start = SIMD2<Float>(-1.2, 0.0)

        let path = MascotRoamingEngine.findPath(
            from: start,
            to: goal,
            roomSize: roomSize,
            obstacles: [barrier]
        )
        #expect(!path.isEmpty)
        #expect(path.count >= 2)

        var state = MascotRoamingEngine.State(
            position: start,
            yaw: 0,
            activity: .walking(path: path, lookAtOnArrival: nil)
        )
        var rng = SystemRandomNumberGenerator()
        var reachedGoal = false
        for _ in 0..<360 {
            MascotRoamingEngine.step(state: &state, dt: 1.0 / 30.0, roomSize: roomSize, obstacles: [barrier], rng: &rng)
            #expect(MascotRoamingEngine.isPointClear(state.position, roomSize: roomSize, obstacles: [barrier]) == true)
            if simd_distance(state.position, goal) < 0.06 {
                reachedGoal = true
                break
            }
        }
        #expect(reachedGoal == true)
    }

    private func hasCollisionOrInputComponents(in entity: Entity) -> Bool {
        if entity.components[CollisionComponent.self] != nil ||
            entity.components[InputTargetComponent.self] != nil {
            return true
        }
        return entity.children.contains { hasCollisionOrInputComponents(in: $0) }
    }
}
