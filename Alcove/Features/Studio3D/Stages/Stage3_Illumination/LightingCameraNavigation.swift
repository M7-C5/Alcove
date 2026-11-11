import Foundation
import simd

/// Camera gestures change the viewpoint without touching the room or lighting state.
struct LightingCameraNavigation: Sendable {
    private(set) var yaw: Float = 0
    private(set) var pitch: Float = 0
    private(set) var zoom: Float = 1
    private(set) var isLocked = false

    mutating func setLocked(_ locked: Bool) {
        if locked && !isLocked { reset() }
        isLocked = locked
    }

    mutating func orbit(deltaX: Double, deltaY: Double) {
        guard !isLocked, deltaX.isFinite, deltaY.isFinite else { return }
        // Drag the room with the finger: moving the camera left makes the room turn right.
        yaw = (yaw - Float(deltaX) * 0.008).truncatingRemainder(dividingBy: 2 * .pi)
        pitch = min(.pi / 3, max(-.pi / 3, pitch + Float(deltaY) * 0.008))
    }

    mutating func magnify(by factor: Double) {
        guard !isLocked, factor.isFinite, factor > 0 else { return }
        zoom = min(3, max(0.5, zoom * Float(factor)))
    }

    mutating func reset() {
        guard !isLocked else { return }
        self = LightingCameraNavigation()
    }

    func target(in geometry: LightingRoomGeometry) -> SIMD3<Float> {
        [0, Float(geometry.height) / 3, 0]
    }

    func position(preset: ViewportPreset, geometry: LightingRoomGeometry) -> SIMD3<Float> {
        let span = Float(max(geometry.width, geometry.length, geometry.height))
        if isLocked { return [0, span * 1.9, 0] }
        let base: SIMD3<Float>
        switch preset {
        case .top: base = [0, span * 1.9, 0.01]
        case .dollhouse: base = [span * 1.2, span, span * 1.4]
        case .front: base = [0, span * 0.5, span * 2]
        case .back: base = [0, span * 0.5, -span * 2]
        case .left: base = [-span * 2, span * 0.5, 0]
        case .right: base = [span * 2, span * 0.5, 0]
        }
        let target = target(in: geometry)
        let offset = base - target
        let azimuth = atan2(offset.x, offset.z) + yaw
        let elevation = min(.pi / 2 - 0.02, max(0.1, atan2(offset.y, hypot(offset.x, offset.z)) + pitch))
        let distance = simd_length(offset) / zoom
        return target + SIMD3<Float>(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation)) * distance
    }
}
