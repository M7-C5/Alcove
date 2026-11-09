import Foundation

/// Calculated atmospheric state of natural daylight.
public struct DaylightState: Sendable, Equatable {
    public let hour: Double
    public let elevationAngleRadians: Double
    public let azimuthAngleRadians: Double
    public let intensityLux: Double
    public let kelvin: Int
    public let normalizedWarmth: Double // 0.0 (noon cool) to 1.0 (golden sunrise/sunset)
}

/// Comprehensive report analyzing the 4 interior lighting layers.
public struct IlluminationReport: Sendable {
    public let daylightState: DaylightState
    public let ambientLux: Double
    public let isAmbientAdequate: Bool
    public let taskZonesCoveredCount: Int
    public let totalTaskZonesCount: Int
    public let hasAccentLighting: Bool
    public let balanceScore: Int
    public let recommendations: [String]

    public var isPassingScore: Bool {
        balanceScore >= 70
    }
}

/// Simulation engine evaluating daylight, ambient, task, and accent lighting contracts.
public struct IlluminationSimulationEngine: Sendable {

    public init() {}

    /// Calculates natural daylight parameters based on hour of day (8.0 AM to 8.0 PM).
    public func calculateDaylight(hourOfDay: Double) -> DaylightState {
        let clampedHour = max(8.0, min(20.0, hourOfDay))

        // Solar arc: 8:00 (0 rad) -> 14:00 (peak pi/2 rad) -> 20:00 (0 rad)
        let normalizedProgress = (clampedHour - 8.0) / 12.0 // 0.0 ... 1.0
        let elevation = sin(normalizedProgress * .pi) * (.pi / 2.5) // Peak ~72° at 14:00
        let azimuth = (normalizedProgress - 0.5) * .pi // -90° (East) to +90° (West)

        // Sunlight intensity (lux)
        let peakLux = 10000.0
        let intensityLux = max(500.0, peakLux * sin(normalizedProgress * .pi))

        // Color temperature in Kelvin: 2500K (golden hour) -> 5800K (midday) -> 2400K (dusk)
        let middayFactor = sin(normalizedProgress * .pi)
        let kelvin = Int(2400.0 + (3400.0 * middayFactor))
        let normalizedWarmth = 1.0 - middayFactor

        return DaylightState(
            hour: clampedHour,
            elevationAngleRadians: elevation,
            azimuthAngleRadians: azimuth,
            intensityLux: intensityLux,
            kelvin: kelvin,
            normalizedWarmth: normalizedWarmth
        )
    }

    /// Evaluates the balance across all four layers against architectural interior guidelines.
    public func evaluateIllumination(
        fixtures: [LightFixture],
        roomWidth: Double,
        roomLength: Double,
        furnitures: [Furniture],
        hourOfDay: Double
    ) -> IlluminationReport {
        let roomArea = max(1.0, roomWidth * roomLength)
        let daylight = calculateDaylight(hourOfDay: hourOfDay)
        let activeFixtures = fixtures.filter { $0.isOn }

        // 1. Ambient Layer Check (Residential living space target: 60 - 150 lux)
        let ambientLumens = activeFixtures
            .filter { $0.layer == .ambient }
            .reduce(0.0) { $0 + $1.lumens }
        let ambientLux = ambientLumens / roomArea
        let isAmbientAdequate = ambientLux >= 60.0

        // 2. Task Layer Check (Identify desk / seating / bed zones needing focused task light)
        let taskItems = furnitures.filter { item in
            !item.isArchived && (item.category == .table || item.category == .seating || item.category == .bed)
        }
        let totalTaskZones = taskItems.count
        var coveredTaskZones = 0

        let taskFixtures = activeFixtures.filter { $0.layer == .task }
        for item in taskItems {
            let hasNearbyTaskLight = taskFixtures.contains { fixture in
                let dx = fixture.positionX - item.positionX
                let dz = fixture.positionZ - item.positionZ
                let distance = sqrt(dx * dx + dz * dz)
                return distance <= 1.8 // within 1.8m
            }
            if hasNearbyTaskLight {
                coveredTaskZones += 1
            }
        }

        // 3. Accent Layer Check
        let hasAccent = activeFixtures.contains { $0.layer == .accent }

        // 4. Score Synthesis (0 - 100)
        var score = 0
        var recommendations: [String] = []

        // Daylight utilization (25 pts)
        if daylight.intensityLux > 1000.0 {
            score += 25
        } else {
            score += 15
        }

        // Ambient coverage (25 pts)
        if isAmbientAdequate {
            score += 25
        } else {
            score += max(0, Int((ambientLux / 150.0) * 20.0))
            recommendations.append("Ambient illumination is low (\(Int(ambientLux)) lux). Add ceiling fixtures to reach 150+ lux.")
        }

        // Task lighting coverage (30 pts)
        if totalTaskZones > 0 {
            let taskRatio = Double(coveredTaskZones) / Double(totalTaskZones)
            score += Int(taskRatio * 30.0)
            if coveredTaskZones < totalTaskZones {
                recommendations.append("Place dedicated task lamps near your desk or reading seating to avoid eye strain.")
            }
        } else {
            score += 30
        }

        // Accent lighting presence (20 pts)
        if hasAccent {
            score += 20
        } else {
            recommendations.append("Incorporate accent sconces or LED strip lights to add visual depth to focal walls.")
        }

        return IlluminationReport(
            daylightState: daylight,
            ambientLux: ambientLux,
            isAmbientAdequate: isAmbientAdequate,
            taskZonesCoveredCount: coveredTaskZones,
            totalTaskZonesCount: totalTaskZones,
            hasAccentLighting: hasAccent,
            balanceScore: min(100, max(0, score)),
            recommendations: recommendations
        )
    }

    /// Approximate RGB double components for blackbody color temperature in Kelvin.
    public func blackbodyRGB(kelvin: Int) -> (red: Double, green: Double, blue: Double) {
        let temp = Double(max(1000, min(40000, kelvin))) / 100.0
        var red: Double
        var green: Double
        var blue: Double

        // Red
        if temp <= 66.0 {
            red = 255.0
        } else {
            red = 329.698727446 * pow(temp - 60.0, -0.1332047592)
            red = max(0, min(255, red))
        }

        // Green
        if temp <= 66.0 {
            green = 99.4708025861 * log(temp) - 161.1195681661
            green = max(0, min(255, green))
        } else {
            green = 288.1221695283 * pow(temp - 60.0, -0.0755148492)
            green = max(0, min(255, green))
        }

        // Blue
        if temp >= 66.0 {
            blue = 255.0
        } else if temp <= 19.0 {
            blue = 0.0
        } else {
            blue = 138.5177312231 * log(temp - 10.0) - 305.0447927307
            blue = max(0, min(255, blue))
        }

        return (red / 255.0, green / 255.0, blue / 255.0)
    }
}
