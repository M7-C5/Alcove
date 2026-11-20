import Foundation
import RealityKit
import UIKit
import simd

/// Pure, deterministic spatial roaming and procedural waddle/idle/hop math for the 3D Otter mascot.
public struct MascotRoamingEngine: Sendable {
    public static let targetHeight: Float = 0.65
    public static let mascotRadius: Float = 0.26
    public static let wallMargin: Float = 0.35
    public static let furniturePadding: Float = 0.20
    public static let walkSpeed: Float = 0.62
    public static let turnSpeed: Float = 6.5

    public struct Obstacle: Sendable, Equatable {
        public let id: UUID?
        public let center: SIMD2<Float>
        public let size: SIMD2<Float>
        public let yaw: Float

        public init(id: UUID?, center: SIMD2<Float>, size: SIMD2<Float>, yaw: Float) {
            self.id = id
            self.center = center
            self.size = size
            self.yaw = yaw
        }
    }

    public enum Activity: Sendable, Equatable {
        case idle(remaining: Float, lookAt: SIMD2<Float>?)
        case walking(path: [SIMD2<Float>], lookAtOnArrival: SIMD2<Float>?)
        case hopping(elapsed: Float, duration: Float)

        public var destination: SIMD2<Float>? {
            if case .walking(let path, _) = self {
                return path.last
            }
            return nil
        }
    }

    public struct State: Sendable, Equatable {
        public var position: SIMD2<Float>
        public var yaw: Float
        public var activity: Activity
        public var phase: Float
        public var verticalOffset: Float
        public var rollAngle: Float
        public var pitchAngle: Float
        public var rerouteCooldown: Float

        public init(
            position: SIMD2<Float> = .zero,
            yaw: Float = 0,
            activity: Activity = .idle(remaining: 1.5, lookAt: nil),
            phase: Float = 0,
            verticalOffset: Float = 0,
            rollAngle: Float = 0,
            pitchAngle: Float = 0,
            rerouteCooldown: Float = 0
        ) {
            self.position = position
            self.yaw = yaw
            self.activity = activity
            self.phase = phase
            self.verticalOffset = verticalOffset
            self.rollAngle = rollAngle
            self.pitchAngle = pitchAngle
            self.rerouteCooldown = rerouteCooldown
        }
    }

    /// Returns true if `point` (X, Z) lies inside interior wall margins and outside padded furniture footprints.
    public static func isPointClear(
        _ point: SIMD2<Float>,
        roomSize: SIMD2<Float>,
        obstacles: [Obstacle]
    ) -> Bool {
        let halfW = max(0.05, roomSize.x / 2.0 - wallMargin)
        let halfL = max(0.05, roomSize.y / 2.0 - wallMargin)
        guard abs(point.x) <= halfW, abs(point.y) <= halfL else {
            return false
        }

        for obstacle in obstacles {
            let delta = point - obstacle.center
            let cosA = cos(-obstacle.yaw)
            let sinA = sin(-obstacle.yaw)
            // Transform into the obstacle's local XZ frame matching RealityKit Y rotation
            let localX = delta.x * cosA - delta.y * sinA
            let localZ = delta.x * sinA + delta.y * cosA
            if abs(localX) < (obstacle.size.x / 2.0 + furniturePadding) &&
                abs(localZ) < (obstacle.size.y / 2.0 + furniturePadding) {
                return false
            }
        }
        return true
    }

    /// Samples points along `start -> end` every 0.10m to prevent cutting through furniture corners.
    public static func isSegmentClear(
        from start: SIMD2<Float>,
        to end: SIMD2<Float>,
        roomSize: SIMD2<Float>,
        obstacles: [Obstacle]
    ) -> Bool {
        let distance = simd_distance(start, end)
        let steps = max(4, Int(ceil(distance / 0.10)))
        for i in 1...steps {
            let t = Float(i) / Float(steps)
            let sample = start + (end - start) * t
            if !isPointClear(sample, roomSize: roomSize, obstacles: obstacles) {
                return false
            }
        }
        return true
    }

    /// Finds the closest clear floor point around `point` (e.g. if furniture was dragged onto the Otter).
    public static func nearestClearPoint(
        to point: SIMD2<Float>,
        roomSize: SIMD2<Float>,
        obstacles: [Obstacle]
    ) -> SIMD2<Float> {
        if isPointClear(point, roomSize: roomSize, obstacles: obstacles) {
            return point
        }
        let halfW = max(0.05, roomSize.x / 2.0 - wallMargin)
        let halfL = max(0.05, roomSize.y / 2.0 - wallMargin)
        let clampedOrigin = SIMD2<Float>(min(max(point.x, -halfW), halfW), min(max(point.y, -halfL), halfL))
        if isPointClear(clampedOrigin, roomSize: roomSize, obstacles: obstacles) {
            return clampedOrigin
        }

        for ring in 1...12 {
            let r = Float(ring) * 0.22
            for angleStep in 0..<16 {
                let angle = Float(angleStep) * (.pi / 8.0)
                let candidate = clampedOrigin + SIMD2<Float>(cos(angle), sin(angle)) * r
                if isPointClear(candidate, roomSize: roomSize, obstacles: obstacles) {
                    return candidate
                }
            }
        }
        return clampedOrigin
    }

    /// Computes a collision-free waypoint path from `start` to `end` around furniture using a 2D A* grid.
    public static func findPath(
        from start: SIMD2<Float>,
        to end: SIMD2<Float>,
        roomSize: SIMD2<Float>,
        obstacles: [Obstacle]
    ) -> [SIMD2<Float>] {
        let safeStart = nearestClearPoint(to: start, roomSize: roomSize, obstacles: obstacles)
        let safeEnd = nearestClearPoint(to: end, roomSize: roomSize, obstacles: obstacles)

        if isSegmentClear(from: safeStart, to: safeEnd, roomSize: roomSize, obstacles: obstacles) {
            return [safeEnd]
        }

        let cellSize: Float = 0.22
        let halfW = max(0.05, roomSize.x / 2.0 - wallMargin)
        let halfL = max(0.05, roomSize.y / 2.0 - wallMargin)
        let cols = max(1, Int(floor((halfW * 2.0) / cellSize)) + 1)
        let rows = max(1, Int(floor((halfL * 2.0) / cellSize)) + 1)

        func cellCenter(_ c: Int, _ r: Int) -> SIMD2<Float> {
            SIMD2<Float>(
                min(halfW, max(-halfW, -halfW + Float(c) * cellSize)),
                min(halfL, max(-halfL, -halfL + Float(r) * cellSize))
            )
        }

        func nearestWalkableCell(to pt: SIMD2<Float>) -> (Int, Int)? {
            let baseC = min(cols - 1, max(0, Int(((pt.x + halfW) / cellSize).rounded())))
            let baseR = min(rows - 1, max(0, Int(((pt.y + halfL) / cellSize).rounded())))
            if isPointClear(cellCenter(baseC, baseR), roomSize: roomSize, obstacles: obstacles) {
                return (baseC, baseR)
            }
            var best: (Int, Int)?
            var bestDist = Float.greatestFiniteMagnitude
            for r in 0..<rows {
                for c in 0..<cols {
                    let center = cellCenter(c, r)
                    if isPointClear(center, roomSize: roomSize, obstacles: obstacles) {
                        let d = simd_distance_squared(center, pt)
                        if d < bestDist {
                            bestDist = d
                            best = (c, r)
                        }
                    }
                }
            }
            return best
        }

        guard let startCell = nearestWalkableCell(to: safeStart),
              let goalCell = nearestWalkableCell(to: safeEnd) else {
            return []
        }

        struct Node: Hashable { let c: Int; let r: Int }
        let startNode = Node(c: startCell.0, r: startCell.1)
        let goalNode = Node(c: goalCell.0, r: goalCell.1)

        var open: [Node] = [startNode]
        var cameFrom: [Node: Node] = [:]
        var gScore: [Node: Float] = [startNode: 0]
        var fScore: [Node: Float] = [startNode: hypot(Float(goalNode.c - startNode.c), Float(goalNode.r - startNode.r))]
        var closed = Set<Node>()

        let dirs = [
            (1, 0, Float(1.0)), (-1, 0, Float(1.0)), (0, 1, Float(1.0)), (0, -1, Float(1.0)),
            (1, 1, Float(1.414)), (1, -1, Float(1.414)), (-1, 1, Float(1.414)), (-1, -1, Float(1.414))
        ]

        while !open.isEmpty {
            let currentIdx = open.indices.min { (fScore[open[$0]] ?? .greatestFiniteMagnitude) < (fScore[open[$1]] ?? .greatestFiniteMagnitude) }!
            let current = open.remove(at: currentIdx)
            if current == goalNode {
                var rawPath: [SIMD2<Float>] = []
                var trace: Node? = current
                while let n = trace {
                    rawPath.append(cellCenter(n.c, n.r))
                    trace = cameFrom[n]
                }
                rawPath.reverse()
                rawPath.append(safeEnd)

                // String-pull smoothing: skip intermediate grid cells when segment is clear
                var smoothed: [SIMD2<Float>] = []
                var anchor = safeStart
                var i = 0
                while i < rawPath.count {
                    var furthest = i
                    var j = rawPath.count - 1
                    while j > i {
                        if isSegmentClear(from: anchor, to: rawPath[j], roomSize: roomSize, obstacles: obstacles) {
                            furthest = j
                            break
                        }
                        j -= 1
                    }
                    let wp = rawPath[furthest]
                    if simd_distance(anchor, wp) > 0.02 {
                        smoothed.append(wp)
                        anchor = wp
                    }
                    i = furthest + 1
                }
                return smoothed.isEmpty ? [safeEnd] : smoothed
            }

            closed.insert(current)
            for (dc, dr, cost) in dirs {
                let nc = current.c + dc
                let nr = current.r + dr
                guard nc >= 0, nc < cols, nr >= 0, nr < rows else { continue }
                let neighbor = Node(c: nc, r: nr)
                if closed.contains(neighbor) { continue }
                guard isPointClear(cellCenter(nc, nr), roomSize: roomSize, obstacles: obstacles) else { continue }

                // Prevent diagonal corner-cutting through adjacent blocked cells
                if dc != 0 && dr != 0 {
                    guard isPointClear(cellCenter(current.c + dc, current.r), roomSize: roomSize, obstacles: obstacles),
                          isPointClear(cellCenter(current.c, current.r + dr), roomSize: roomSize, obstacles: obstacles) else {
                        continue
                    }
                }

                let tentativeG = (gScore[current] ?? .greatestFiniteMagnitude) + cost
                if tentativeG < (gScore[neighbor] ?? .greatestFiniteMagnitude) {
                    cameFrom[neighbor] = current
                    gScore[neighbor] = tentativeG
                    fScore[neighbor] = tentativeG + hypot(Float(goalNode.c - nc), Float(goalNode.r - nr))
                    if !open.contains(neighbor) {
                        open.append(neighbor)
                    }
                }
            }
        }

        return []
    }

    /// Picks a clear floor waypoint, preferring unobstructed paths at least 0.45m away.
    public static func pickRandomWaypoint(
        from current: SIMD2<Float>,
        roomSize: SIMD2<Float>,
        obstacles: [Obstacle],
        rng: inout some RandomNumberGenerator
    ) -> SIMD2<Float> {
        let halfW = max(0.05, roomSize.x / 2.0 - wallMargin)
        let halfL = max(0.05, roomSize.y / 2.0 - wallMargin)

        var fallbackClear: SIMD2<Float>? = nil
        for _ in 0..<24 {
            let candidate = SIMD2<Float>(
                Float.random(in: -halfW...halfW, using: &rng),
                Float.random(in: -halfL...halfL, using: &rng)
            )
            guard isPointClear(candidate, roomSize: roomSize, obstacles: obstacles) else { continue }
            if fallbackClear == nil {
                fallbackClear = candidate
            }
            if simd_distance(current, candidate) >= 0.45 &&
                isSegmentClear(from: current, to: candidate, roomSize: roomSize, obstacles: obstacles) {
                return candidate
            }
        }

        if let fallbackClear {
            return fallbackClear
        }

        return SIMD2<Float>(
            min(max(0, -halfW), halfW),
            min(max(0, -halfL), halfL)
        )
    }

    /// Computes a clear approach spot just outside `obstacle`'s footprint and returns `(destination, lookAt)`.
    public static func approachTarget(
        for obstacle: Obstacle,
        from current: SIMD2<Float>,
        roomSize: SIMD2<Float>,
        obstacles: [Obstacle]
    ) -> (destination: SIMD2<Float>, lookAt: SIMD2<Float>) {
        let radius = max(obstacle.size.x, obstacle.size.y) / 2.0 + furniturePadding + 0.16
        let halfW = max(0.05, roomSize.x / 2.0 - wallMargin)
        let halfL = max(0.05, roomSize.y / 2.0 - wallMargin)

        var candidateDirs: [SIMD2<Float>] = []
        let towardCurrent = current - obstacle.center
        if simd_length_squared(towardCurrent) > 1e-4 {
            candidateDirs.append(simd_normalize(towardCurrent))
        }
        for step in 0..<8 {
            let angle = Float(step) * (.pi / 4.0)
            candidateDirs.append(SIMD2<Float>(cos(angle), sin(angle)))
        }

        var bestPoint: SIMD2<Float>?
        var bestDist: Float = .greatestFiniteMagnitude

        for dir in candidateDirs {
            let raw = obstacle.center + dir * radius
            let clamped = SIMD2<Float>(
                min(max(raw.x, -halfW), halfW),
                min(max(raw.y, -halfL), halfL)
            )
            if isPointClear(clamped, roomSize: roomSize, obstacles: obstacles) {
                let d = simd_distance(current, clamped)
                if d < bestDist {
                    bestDist = d
                    bestPoint = clamped
                }
            }
        }

        if let bestPoint {
            return (bestPoint, obstacle.center)
        }

        var defaultRNG = SystemRandomNumberGenerator()
        return (pickRandomWaypoint(from: current, roomSize: roomSize, obstacles: obstacles, rng: &defaultRNG), obstacle.center)
    }

    /// Advances the Otter's position, facing yaw, and procedural waddle/idle/hop pose by `dt` seconds.
    public static func step(
        state: inout State,
        dt: Float,
        roomSize: SIMD2<Float>,
        obstacles: [Obstacle],
        rng: inout some RandomNumberGenerator
    ) {
        let clampedDt = min(max(dt, 0), 0.1)
        state.phase += clampedDt

        // If furniture was moved on top of the Otter, nudge cleanly to the nearest clear spot
        if !isPointClear(state.position, roomSize: roomSize, obstacles: obstacles) {
            state.position = nearestClearPoint(to: state.position, roomSize: roomSize, obstacles: obstacles)
        }

        switch state.activity {
        case .hopping(let elapsed, let duration):
            let next = elapsed + clampedDt
            let t = min(1.0, next / max(0.01, duration))
            state.verticalOffset = 4.0 * t * (1.0 - t) * 0.14
            state.rollAngle = sin(t * .pi * 4.0) * 0.14
            state.pitchAngle = 0
            if next >= duration {
                state.verticalOffset = 0
                state.rollAngle = 0
                state.activity = .idle(remaining: 1.8, lookAt: nil)
            } else {
                state.activity = .hopping(elapsed: next, duration: duration)
            }

        case .idle(let remaining, let lookAt):
            if let lookAt {
                let delta = lookAt - state.position
                if simd_length_squared(delta) > 1e-4 {
                    let targetYaw = atan2(delta.x, delta.y)
                    state.yaw = lerpAngle(state.yaw, targetYaw, factor: min(1.0, turnSpeed * clampedDt))
                }
            }
            state.verticalOffset = (sin(state.phase * 2.4) + 1.0) * 0.008
            state.rollAngle = sin(state.phase * 1.2) * 0.03
            state.pitchAngle = 0

            let nextRemaining = remaining - clampedDt
            if nextRemaining <= 0 {
                let waypoint = pickRandomWaypoint(
                    from: state.position,
                    roomSize: roomSize,
                    obstacles: obstacles,
                    rng: &rng
                )
                let path = findPath(from: state.position, to: waypoint, roomSize: roomSize, obstacles: obstacles)
                if path.isEmpty {
                    state.activity = .idle(remaining: 1.0, lookAt: nil)
                } else {
                    state.activity = .walking(path: path, lookAtOnArrival: nil)
                }
            } else {
                state.activity = .idle(remaining: nextRemaining, lookAt: lookAt)
            }

        case .walking(var path, let lookAtOnArrival):
            guard let nextWaypoint = path.first else {
                state.pitchAngle = 0
                state.activity = .idle(remaining: 2.0, lookAt: lookAtOnArrival)
                return
            }

            // Throttle A* pathfinding reroutes so moving furniture never triggers 60-120Hz grid searches
            if state.rerouteCooldown > 0 {
                state.rerouteCooldown = max(0, state.rerouteCooldown - clampedDt)
            }

            // If an obstacle moved onto the path, recompute a clear path around it
            if !isPointClear(nextWaypoint, roomSize: roomSize, obstacles: obstacles) ||
                !isSegmentClear(from: state.position, to: nextWaypoint, roomSize: roomSize, obstacles: obstacles) {
                if state.rerouteCooldown <= 0,
                   let finalGoal = path.last,
                   isPointClear(finalGoal, roomSize: roomSize, obstacles: obstacles) {
                    state.rerouteCooldown = 0.35
                    let rerouted = findPath(from: state.position, to: finalGoal, roomSize: roomSize, obstacles: obstacles)
                    if !rerouted.isEmpty {
                        state.activity = .walking(path: rerouted, lookAtOnArrival: lookAtOnArrival)
                        return
                    }
                }
                state.activity = .idle(remaining: 0.4, lookAt: lookAtOnArrival)
                return
            }

            let delta = nextWaypoint - state.position
            let dist = simd_length(delta)
            if dist <= 0.04 {
                state.position = nextWaypoint
                path.removeFirst()
                if path.isEmpty {
                    state.pitchAngle = 0
                    if let lookAtOnArrival {
                        let faceDelta = lookAtOnArrival - state.position
                        if simd_length_squared(faceDelta) > 1e-4 {
                            state.yaw = atan2(faceDelta.x, faceDelta.y)
                        }
                        state.activity = .idle(remaining: 3.0, lookAt: lookAtOnArrival)
                    } else {
                        state.activity = .idle(remaining: Float.random(in: 2.0...4.2, using: &rng), lookAt: nil)
                    }
                } else {
                    state.activity = .walking(path: path, lookAtOnArrival: lookAtOnArrival)
                }
            } else {
                let stepDist = min(dist, walkSpeed * clampedDt)
                let candidatePos = state.position + (delta / dist) * stepDist
                guard isPointClear(candidatePos, roomSize: roomSize, obstacles: obstacles) else {
                    state.activity = .idle(remaining: 0.3, lookAt: lookAtOnArrival)
                    return
                }
                state.position = candidatePos
                let targetYaw = atan2(delta.x, delta.y)
                state.yaw = lerpAngle(state.yaw, targetYaw, factor: min(1.0, turnSpeed * clampedDt))

                state.verticalOffset = abs(sin(state.phase * 7.8)) * 0.038
                state.rollAngle = sin(state.phase * 7.8) * 0.11
                state.pitchAngle = 0.05
                state.activity = .walking(path: path, lookAtOnArrival: lookAtOnArrival)
            }
        }
    }

    private static func lerpAngle(_ current: Float, _ target: Float, factor: Float) -> Float {
        var diff = (target - current).truncatingRemainder(dividingBy: 2.0 * .pi)
        if diff > .pi { diff -= 2.0 * .pi }
        if diff < -.pi { diff += 2.0 * .pi }
        return current + diff * factor
    }
}

/// Manages the RealityKit `Otter.usdz` entity, normalization, animations, and roaming updates in the 3D Studio.
@MainActor
public final class MascotRoamController {
    public let rootEntity = Entity()
    private let visualPivot = Entity()
    public private(set) var state = MascotRoamingEngine.State()
    public private(set) var hasLoadedModel: Bool = false
    public var hasEmbeddedAnimation: Bool { !walkAnimationControllers.isEmpty }

    private var rng = SystemRandomNumberGenerator()
    private var walkAnimationControllers: [AnimationPlaybackController] = []
    private var isWalkAnimationPlaying: Bool = false
    private static var cachedPrototype: Entity?

    public init() {
        rootEntity.name = "MascotOtterRoot"
        visualPivot.name = "MascotVisualPivot"
        rootEntity.addChild(visualPivot)

        if let model = Self.instantiateNormalizedOtter() {
            visualPivot.addChild(model)
            hasLoadedModel = true
            walkAnimationControllers = Self.startPausedWalkAnimations(on: model)
        }
    }

    /// Places the Otter on a clear initial floor spot and begins wandering.
    public func configureInitialPosition(
        roomSize: SIMD2<Float>,
        obstacles: [MascotRoamingEngine.Obstacle]
    ) {
        let spawn = MascotRoamingEngine.pickRandomWaypoint(
            from: .zero,
            roomSize: roomSize,
            obstacles: obstacles,
            rng: &rng
        )
        let firstTarget = MascotRoamingEngine.pickRandomWaypoint(
            from: spawn,
            roomSize: roomSize,
            obstacles: obstacles,
            rng: &rng
        )
        state = MascotRoamingEngine.State(
            position: spawn,
            yaw: atan2(firstTarget.x - spawn.x, firstTarget.y - spawn.y),
            activity: .idle(remaining: 0.9, lookAt: firstTarget)
        )
        applyTransform()
    }

    /// Per-frame update called from `SceneEvents.Update`.
    public func update(
        dt: Float,
        roomSize: SIMD2<Float>,
        obstacles: [MascotRoamingEngine.Obstacle]
    ) {
        MascotRoamingEngine.step(
            state: &state,
            dt: dt,
            roomSize: roomSize,
            obstacles: obstacles,
            rng: &rng
        )
        applyTransform()
    }

    /// Directs the Otter to walk around obstacles to `obstacle` and face it.
    public func focusOnFurniture(
        _ obstacle: MascotRoamingEngine.Obstacle,
        roomSize: SIMD2<Float>,
        obstacles: [MascotRoamingEngine.Obstacle]
    ) {
        let (destination, lookAt) = MascotRoamingEngine.approachTarget(
            for: obstacle,
            from: state.position,
            roomSize: roomSize,
            obstacles: obstacles
        )
        let path = MascotRoamingEngine.findPath(
            from: state.position,
            to: destination,
            roomSize: roomSize,
            obstacles: obstacles
        )
        if path.isEmpty {
            state.activity = .idle(remaining: 2.0, lookAt: lookAt)
        } else {
            state.activity = .walking(path: path, lookAtOnArrival: lookAt)
        }
    }

    /// Triggers an immediate happy hop animation on the Otter.
    public func triggerHappyHop() {
        state.activity = .hopping(elapsed: 0, duration: 0.55)
        applyTransform()
    }

    /// Checks a screen tap via 2D projection so the Otter stays pass-through for 3D furniture & light gestures.
    @discardableResult
    public func handleScreenTap(at point: CGPoint, in arView: ARView) -> Bool {
        let worldCenter = rootEntity.position(relativeTo: nil) + SIMD3<Float>(0, MascotRoamingEngine.targetHeight * 0.5, 0)
        guard let projected = arView.project(worldCenter) else { return false }
        let dist = hypot(projected.x - point.x, projected.y - point.y)
        guard dist <= 44.0 else { return false }

        triggerHappyHop()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        return true
    }

    private func applyTransform() {
        rootEntity.position = SIMD3<Float>(state.position.x, 0, state.position.y)
        rootEntity.orientation = simd_quatf(angle: state.yaw, axis: SIMD3<Float>(0, 1, 0))

        visualPivot.position = SIMD3<Float>(0, state.verticalOffset, 0)
        let pitchQuat = simd_quatf(angle: state.pitchAngle, axis: SIMD3<Float>(1, 0, 0))
        let rollQuat = simd_quatf(angle: state.rollAngle, axis: SIMD3<Float>(0, 0, 1))
        visualPivot.orientation = rollQuat * pitchQuat

        let shouldAnimateWalk: Bool
        if case .walking = state.activity {
            shouldAnimateWalk = true
        } else {
            shouldAnimateWalk = false
        }
        if shouldAnimateWalk != isWalkAnimationPlaying {
            isWalkAnimationPlaying = shouldAnimateWalk
            for controller in walkAnimationControllers {
                if shouldAnimateWalk {
                    controller.speed = 2.1
                    controller.resume()
                } else {
                    controller.pause()
                    controller.time = 0
                }
            }
        }
    }

    private static func startPausedWalkAnimations(on entity: Entity) -> [AnimationPlaybackController] {
        var controllers: [AnimationPlaybackController] = []
        if !entity.availableAnimations.isEmpty {
            for animation in entity.availableAnimations {
                let controller = entity.playAnimation(animation.repeat())
                controller.pause()
                controller.time = 0
                controllers.append(controller)
            }
        } else {
            for child in entity.children {
                controllers.append(contentsOf: startPausedWalkAnimations(on: child))
            }
        }
        return controllers
    }

    // MARK: - USDZ Loading & Normalization

    private static func instantiateNormalizedOtter() -> Entity? {
        if let cached = cachedPrototype {
            return cached.clone(recursive: true)
        }

        let bundleURL = Bundle.main.url(forResource: "Otter", withExtension: "usdz")
            ?? Bundle(for: MascotRoamController.self).url(forResource: "Otter", withExtension: "usdz")
        guard let url = bundleURL,
              let rawModel = try? Entity.load(contentsOf: url) else {
            return nil
        }

        let holder = Entity()
        holder.name = "NormalizedOtter"
        holder.addChild(rawModel)

        // If Blender Z-up was not converted by USD loader, rotate upright into RealityKit Y-up
        var bounds = rawModel.visualBounds(relativeTo: holder)
        if bounds.extents.z > bounds.extents.y * 1.4 {
            rawModel.orientation = simd_quatf(angle: -.pi / 2.0, axis: SIMD3<Float>(1, 0, 0))
            bounds = rawModel.visualBounds(relativeTo: holder)
        }

        let height = max(0.05, bounds.extents.y)
        let scale = MascotRoamingEngine.targetHeight / height
        rawModel.scale = SIMD3<Float>(repeating: scale)

        // Recompute bounds after scale and ground feet at y = 0 centered at (0, 0)
        let scaledBounds = rawModel.visualBounds(relativeTo: holder)
        rawModel.position = SIMD3<Float>(
            -scaledBounds.center.x,
            -scaledBounds.min.y,
            -scaledBounds.center.z
        )

        stripInteractionComponents(in: holder)
        cachedPrototype = holder
        return holder.clone(recursive: true)
    }

    private static func stripInteractionComponents(in entity: Entity) {
        entity.components.remove(CollisionComponent.self)
        entity.components.remove(InputTargetComponent.self)
        for child in entity.children {
            stripInteractionComponents(in: child)
        }
    }
}
