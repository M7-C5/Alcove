import Foundation
import Observation

/// Programmatic camera positioning and gesture interaction state for the spatial studio canvas.
@Observable
@MainActor
public final class SpatialViewportCameraState {
    public var preset: ViewportPreset = .top
    public var zoomScale: Double = 1.0
    public var panOffsetX: Double = 0.0
    public var panOffsetY: Double = 0.0

    public init(preset: ViewportPreset = .top) {
        self.preset = preset
    }

    public var isIsometric3D: Bool {
        preset == .dollhouse
    }

    public var pitchAngleDegrees: Double {
        preset.pitchAngleDegrees
    }

    public var yawAngleDegrees: Double {
        preset.yawAngleDegrees
    }

    public func setPreset(_ newPreset: ViewportPreset) {
        self.preset = newPreset
    }

    public func applyZoom(factor: Double) {
        zoomScale = max(0.5, min(3.0, zoomScale * factor))
    }

    public func applyPan(translationX: Double, translationY: Double) {
        panOffsetX += translationX
        panOffsetY += translationY
    }

    public func resetCamera() {
        preset = .top
        zoomScale = 1.0
        panOffsetX = 0.0
        panOffsetY = 0.0
    }
}
