import Foundation
import simd

/// Magnetic bearing of the room's forward (-Z) axis, frozen when capture starts.
/// The current manual scan uses the rear camera's initial horizontal direction as -Z.
nonisolated public struct RoomCompassOrientation: Codable, Equatable, Sendable {
    public let magneticForwardBearingDegrees: Double
    public let capturedAt: Date

    public init?(magneticForwardBearingDegrees: Double, capturedAt: Date = Date()) {
        guard magneticForwardBearingDegrees.isFinite else { return nil }
        self.magneticForwardBearingDegrees = (magneticForwardBearingDegrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        self.capturedAt = capturedAt
    }

    public var isValid: Bool {
        magneticForwardBearingDegrees.isFinite && (0..<360).contains(magneticForwardBearingDegrees)
    }

    /// Clockwise compass bearings become RealityKit directions (+Y up, -Z forward).
    public func direction(forBearingDegrees bearing: Double, elevationRadians: Double = 0) -> SIMD3<Float> {
        let angle = (bearing - magneticForwardBearingDegrees) * .pi / 180
        return [Float(sin(angle) * cos(elevationRadians)), Float(sin(elevationRadians)),
                Float(-cos(angle) * cos(elevationRadians))]
    }
}
