import Foundation

/// Placement temporarily replaces the chosen camera preset with a locked top view.
struct LightingPlacementState: Sendable {
    private(set) var isActive = false
    private var previousPreset: ViewportPreset = .dollhouse

    mutating func begin(from preset: ViewportPreset) {
        guard !isActive else { return }
        previousPreset = preset
        isActive = true
    }

    mutating func finish() -> ViewportPreset {
        isActive = false
        return previousPreset
    }
}
