import CoreMotion
import Foundation
import Observation
import simd

/// Foreground scan companion. No location tracking or changes to the AR session are needed.
@Observable @MainActor
final class RoomCompassCapture {
    enum Status { case searching, needsCalibration, needsUpright, captured, unavailable, failed }
    private(set) var status: Status = .searching
    private(set) var orientation: RoomCompassOrientation?
    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var running = false
    @ObservationIgnored private var stabilizer = RoomCompassStabilizer()
    @ObservationIgnored private var generation = UUID()

    func start(cameraForward: (@MainActor (TimeInterval) -> SIMD3<Float>?)? = nil) {
        guard !running, orientation == nil else { return }
        guard motion.isDeviceMotionAvailable,
              CMMotionManager.availableAttitudeReferenceFrames().contains(.xMagneticNorthZVertical) else {
            status = .unavailable
            return
        }
        running = true
        stabilizer = RoomCompassStabilizer()
        generation = UUID()
        let generation = generation
        status = .searching
        motion.deviceMotionUpdateInterval = 0.1
        motion.showsDeviceMovementDisplay = true
        motion.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] update, error in
            // Pass only immutable sensor values across the callback boundary.
            let matrix = update?.attitude.rotationMatrix
            let north = matrix.map { -$0.m31 }
            let west = matrix.map { -$0.m32 }
            let calibrated = update.map { $0.magneticField.accuracy == .medium || $0.magneticField.accuracy == .high } ?? false
            let failed = error != nil
            let timestamp = update?.timestamp
            Task { @MainActor [weak self] in
                guard let self, self.generation == generation else { return }
                let forward = timestamp.flatMap { cameraForward?($0) }
                self.receive(north: north, west: west, calibrated: calibrated, failed: failed,
                             cameraForward: forward, requiresARFrame: cameraForward != nil)
            }
        }
    }

    func stop() {
        running = false
        motion.stopDeviceMotionUpdates()
        generation = UUID()
        stabilizer = RoomCompassStabilizer()
    }

    func reset() {
        stop()
        orientation = nil
        status = .searching
    }

    /// Transpose the reference-to-device matrix to project the rear camera's -Z axis.
    /// This stays independent of portrait/landscape interface orientation.
    static func cameraBearing(north: Double, west: Double) -> Double? {
        guard north.isFinite, west.isFinite, hypot(north, west) >= 0.25 else { return nil }
        return (atan2(-west, north) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Remove the camera's current yaw before stabilizing the AR world's -Z bearing.
    /// A positive RealityKit yaw turns left, opposite to clockwise compass bearings.
    static func worldBearing(cameraBearing: Double, cameraForward: SIMD3<Float>) -> Double? {
        guard cameraBearing.isFinite, cameraForward.x.isFinite, cameraForward.z.isFinite,
              hypot(cameraForward.x, cameraForward.z) >= 0.25 else { return nil }
        let cameraOffset = Double(atan2(cameraForward.x, -cameraForward.z)) * 180 / .pi
        return RoomCompassOrientation(magneticForwardBearingDegrees: cameraBearing - cameraOffset)?
            .magneticForwardBearingDegrees
    }

    private func receive(north: Double?, west: Double?, calibrated: Bool, failed: Bool,
                         cameraForward: SIMD3<Float>?, requiresARFrame: Bool) {
        guard running, orientation == nil else { return }
        if failed { status = .failed; stop(); return }
        guard calibrated else { status = .needsCalibration; stabilizer = RoomCompassStabilizer(); return }
        guard let north, let west, var bearing = Self.cameraBearing(north: north, west: west) else {
            status = .needsUpright
            stabilizer = RoomCompassStabilizer()
            return
        }
        if requiresARFrame {
            guard let cameraForward,
                  let worldBearing = Self.worldBearing(cameraBearing: bearing, cameraForward: cameraForward) else {
                status = .searching
                stabilizer = RoomCompassStabilizer()
                return
            }
            bearing = worldBearing
        }
        status = .searching
        guard let stableBearing = stabilizer.append(bearing) else { return }
        orientation = RoomCompassOrientation(magneticForwardBearingDegrees: stableBearing)
        status = .captured
        stop()
    }
}

/// Circular averaging avoids a false 180° result when samples cross north (359° / 0°).
nonisolated struct RoomCompassStabilizer: Sendable {
    private var samples: [Double] = []

    mutating func append(_ bearing: Double) -> Double? {
        guard bearing.isFinite else { samples.removeAll(); return nil }
        if let first = samples.first {
            let difference = abs((bearing - first + 540).truncatingRemainder(dividingBy: 360) - 180)
            if difference > 3 { samples.removeAll() }
        }
        samples.append(bearing)
        guard samples.count >= 3 else { return nil }
        let x = samples.reduce(0) { $0 + cos($1 * .pi / 180) }
        let y = samples.reduce(0) { $0 + sin($1 * .pi / 180) }
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
}
