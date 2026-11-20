import Foundation
import QuartzCore
import RealityKit
import simd

/// The Audit camera behavior, shared by every non-AR studio viewport.
@MainActor
final class StudioOrbitCameraController {
    var yaw: Float = 0
    var pitch: Float = 0.62
    var distance: Float
    var target: SIMD3<Float>
    let defaultTarget: SIMD3<Float>
    let span: Float
    let roomHeight: Float
    let initialDistance: Float
    private(set) var animationTask: Task<Void, Never>?

    init(width: Double, length: Double, height: Double) {
        span = Float(max(width, length, 3))
        roomHeight = Float(max(height, 2.0))
        initialDistance = min(20, max(5, span * 1.5))
        distance = initialDistance
        defaultTarget = [0, Float(height) * 0.35, 0]
        target = defaultTarget
    }

    var position: SIMD3<Float> {
        target + [distance * cos(pitch) * sin(yaw), distance * sin(pitch),
                  distance * cos(pitch) * cos(yaw)]
    }

    func configure(_ camera: PerspectiveCamera) {
        camera.camera.fieldOfViewInDegrees = 40
        camera.camera.near = 0.1
        camera.camera.far = 60
    }

    func apply(to camera: PerspectiveCamera, relativeTo reference: Entity? = nil) {
        camera.look(at: target, from: position, relativeTo: reference)
    }

    func cancelAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }

    static let minOrbitPitch: Float = 0.12
    static let maxOrbitPitch: Float = 1.55

    func orbit(fromYaw startYaw: Float, pitch startPitch: Float, deltaX: Double, deltaY: Double) {
        guard deltaX.isFinite, deltaY.isFinite else { return }
        cancelAnimation()
        yaw = startYaw - Float(deltaX) * 0.007
        pitch = min(Self.maxOrbitPitch, max(Self.minOrbitPitch, startPitch + Float(deltaY) * 0.007))
    }

    func magnify(from startDistance: Float, scale: Float) {
        guard scale.isFinite, scale > 0.05 else { return }
        cancelAnimation()
        distance = min(span * 3.5, max(span * 0.6, startDistance / scale))
    }

    /// Shifts the camera orbit anchor horizontally and vertically in camera screen space (two-finger pan).
    func panAnchor(from startTarget: SIMD3<Float>, deltaX: Double, deltaY: Double) {
        guard deltaX.isFinite, deltaY.isFinite else { return }
        cancelAnimation()
        let scale = distance * 0.0022
        let right = SIMD3<Float>(cos(yaw), 0, -sin(yaw))
        let up = SIMD3<Float>(-sin(pitch) * sin(yaw), cos(pitch), -sin(pitch) * cos(yaw))
        let rawTarget = startTarget - right * Float(deltaX) * scale + up * Float(deltaY) * scale
        let maxHoriz = span * 0.9
        let maxY = max(roomHeight * 1.2, 3.0)
        target = SIMD3<Float>(
            min(maxHoriz, max(-maxHoriz, rawTarget.x)),
            min(maxY, max(0, rawTarget.y)),
            min(maxHoriz, max(-maxHoriz, rawTarget.z))
        )
    }

    /// Preserve Audit's 350 ms easing and shortest yaw path; presets preserve zoom and re-center the anchor.
    func snap(to preset: ViewportPreset, animated: Bool = true, onUpdate: @escaping @MainActor () -> Void) {
        let startYaw = yaw
        let startPitch = pitch
        let startTarget = target
        let targetYaw = preset.targetYaw
        let targetPitch = preset.targetPitch
        cancelAnimation()
        guard animated else {
            yaw = targetYaw
            pitch = targetPitch
            target = defaultTarget
            onUpdate()
            return
        }
        animationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let startTime = CACurrentMediaTime()
            var deltaYaw = (targetYaw - startYaw).truncatingRemainder(dividingBy: .pi * 2)
            if deltaYaw > .pi { deltaYaw -= .pi * 2 }
            if deltaYaw < -.pi { deltaYaw += .pi * 2 }
            while !Task.isCancelled {
                let progress = min(1, (CACurrentMediaTime() - startTime) / 0.35)
                let t = Float(progress < 0.5 ? 2 * progress * progress : 1 - pow(-2 * progress + 2, 2) / 2)
                yaw = startYaw + deltaYaw * t
                pitch = startPitch + (targetPitch - startPitch) * t
                target = startTarget + (defaultTarget - startTarget) * t
                onUpdate()
                if progress >= 1 { break }
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }
}
