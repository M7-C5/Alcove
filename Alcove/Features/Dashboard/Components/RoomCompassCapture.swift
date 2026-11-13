import CoreMotion
import Foundation
import Observation

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

    func start() {
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
            Task { @MainActor [weak self] in
                guard let self, self.generation == generation else { return }
                self.receive(north: north, west: west, calibrated: calibrated, failed: failed)
            }
        }
    }

    func stop() {
        running = false
        motion.stopDeviceMotionUpdates()
        generation = UUID()
        stabilizer = RoomCompassStabilizer()
    }

    /// Transpose the reference-to-device matrix to project the rear camera's -Z axis.
    /// This stays independent of portrait/landscape interface orientation.
    static func cameraBearing(north: Double, west: Double) -> Double? {
        guard north.isFinite, west.isFinite, hypot(north, west) >= 0.25 else { return nil }
        return (atan2(-west, north) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private func receive(north: Double?, west: Double?, calibrated: Bool, failed: Bool) {
        guard running, orientation == nil else { return }
        if failed { status = .failed; stop(); return }
        guard calibrated else { status = .needsCalibration; stabilizer = RoomCompassStabilizer(); return }
        guard let north, let west, let bearing = Self.cameraBearing(north: north, west: west) else {
            status = .needsUpright
            stabilizer = RoomCompassStabilizer()
            return
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
