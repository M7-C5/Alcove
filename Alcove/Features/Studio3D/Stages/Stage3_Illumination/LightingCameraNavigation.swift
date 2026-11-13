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
        let target = target(in: geometry)
        // Use the same preset angles as the primary Studio3D viewport.
        let azimuth = preset.targetYaw + yaw
        let elevation = min(.pi / 2 - 0.02, max(0.1, preset.targetPitch + pitch))
        let distance = span * 2.2 / zoom
        return target + SIMD3<Float>(sin(azimuth) * cos(elevation), sin(elevation), cos(azimuth) * cos(elevation)) * distance
    }
}
