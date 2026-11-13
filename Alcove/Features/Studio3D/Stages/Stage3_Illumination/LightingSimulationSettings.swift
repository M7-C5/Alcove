import Foundation

/// Preview choices belong to the studio session, independently of saved fixture switches.
struct LightingSimulationSettings: Equatable, Sendable {
    var artificialLightsOn = true
    var sunlightOn = true
    var minuteOfDay = 12 * 60
    var layoutOnly = false

    var clampedMinute: Int { min(1439, max(0, minuteOfDay)) }
    var hourOfDay: Double { Double(clampedMinute) / 60 }
    var timeLabel: String {
        String(format: "%02d:%02d", clampedMinute / 60, clampedMinute % 60)
    }

    func output(for fixture: LightFixture) -> Double {
        guard artificialLightsOn, fixture.isOn, !layoutOnly, fixture.lumens.isFinite else { return 0 }
        return max(0, fixture.lumens)
    }

    /// RealityKit supports eight dynamic lights; reserve one for the illustrative sun.
    func renderedFixtureIDs(in fixtures: [LightFixture]) -> Set<UUID> {
        Set(fixtures.filter { output(for: $0) > 0 }.sorted {
            if $0.lumens == $1.lumens { return $0.id.uuidString < $1.id.uuidString }
            return $0.lumens > $1.lumens
        }.prefix(7).map(\.id))
    }
}

/// The same meter-based bounds drive the plan editor and the rendered room.
struct LightingRoomGeometry: Equatable, Sendable {
    static let placementGridSpacing = 0.05 // 5 cm, independent of the displayed plan size.

    let width: Double
    let length: Double
    let height: Double

    init(width: Double, length: Double, height: Double) {
        self.width = width.isFinite ? max(0.5, width) : 4
        self.length = length.isFinite ? max(0.5, length) : 5
        self.height = height.isFinite ? max(0.5, height) : 2.6
    }

    func position(unitX: Double, unitZ: Double) -> (x: Double, z: Double) {
        (placementCoordinate(unit: unitX, extent: width), placementCoordinate(unit: unitZ, extent: length))
    }

    func unitPosition(floorX: Double, floorZ: Double) -> SIMD2<Float>? {
        guard floorX.isFinite, floorZ.isFinite,
              abs(floorX) <= width / 2, abs(floorZ) <= length / 2 else { return nil }
        return SIMD2<Float>(Float(floorX / width + 0.5), Float(floorZ / length + 0.5))
    }

    private func placementCoordinate(unit: Double, extent: Double) -> Double {
        let unit = unit.isFinite ? min(1, max(0, unit)) : 0.5
        let spacing = Self.placementGridSpacing
        // Map the actual tapped location, then snap within the 15 cm wall setback.
        let step = (((unit - 0.5) * extent) / spacing).rounded()
        let lastInteriorStep = floor(((extent - 0.3) / 2) / spacing + 1e-9)
        return min(lastInteriorStep, max(-lastInteriorStep, step)) * spacing
    }

    func clamped(_ fixture: LightFixture) -> LightFixture {
        var value = fixture
        let halfWidth = (width - 0.3) / 2
        let halfLength = (length - 0.3) / 2
        value.positionX = fixture.positionX.isFinite ? min(halfWidth, max(-halfWidth, fixture.positionX)) : 0
        value.positionZ = fixture.positionZ.isFinite ? min(halfLength, max(-halfLength, fixture.positionZ)) : 0
        value.elevationY = fixture.elevationY.isFinite ? min(height - 0.08, max(0.05, fixture.elevationY)) : height - 0.08
        value.lumens = fixture.lumens.isFinite ? min(3000, max(0, fixture.lumens)) : 800
        value.colorTemperatureKelvin = min(6500, max(2200, fixture.colorTemperatureKelvin))
        return value
    }
}
