import Foundation
import Testing
@testable import Alcove

@Suite("Illumination Simulation Tests") @MainActor
struct IlluminationSimulationEngineTests {

    @Test func daylightCalculationAcrossHours() {
        let engine = IlluminationSimulationEngine()

        let morning = engine.calculateDaylight(hourOfDay: 8.0)
        #expect(morning.hour == 8.0)
        #expect(morning.normalizedWarmth > 0.8) // Golden hour warmth
        #expect(morning.kelvin < 3000)

        let noon = engine.calculateDaylight(hourOfDay: 14.0)
        #expect(noon.hour == 14.0)
        #expect(noon.intensityLux > 8000)
        #expect(noon.kelvin > 5000) // Cool noon light

        let dusk = engine.calculateDaylight(hourOfDay: 20.0)
        #expect(dusk.hour == 20.0)
        #expect(dusk.normalizedWarmth > 0.8)
    }

    @Test func blackbodyColorMapping() {
        let engine = IlluminationSimulationEngine()

        let warm = engine.blackbodyRGB(kelvin: 2500)
        #expect(warm.red > 0.9)
        #expect(warm.blue < 0.6) // Warm light has lower blue component

        let daylight = engine.blackbodyRGB(kelvin: 6000)
        #expect(daylight.red > 0.8)
        #expect(daylight.blue > 0.8) // Daylight has higher blue component
    }

    @Test func evaluateIlluminationBalanceWithFixtures() {
        let engine = IlluminationSimulationEngine()
        let room = SampleData.createCozyBedroom()
        let fixtures = room.workingLayout?.lightFixtures ?? []
        let furnitures = room.workingLayout?.furnitures ?? []

        let report = engine.evaluateIllumination(
            fixtures: fixtures,
            roomWidth: room.dimensionsWidth,
            roomLength: room.dimensionsLength,
            furnitures: furnitures,
            hourOfDay: 14.0
        )

        #expect(report.isAmbientAdequate == true)
        #expect(report.hasAccentLighting == true)
        #expect(report.taskZonesCoveredCount >= 1)
        #expect(report.balanceScore >= 70)
        #expect(report.isPassingScore == true)
    }

    @Test func evaluateIlluminationWhenRoomHasNoFixtures() {
        let engine = IlluminationSimulationEngine()
        let room = SampleData.createStarterRoom()

        let report = engine.evaluateIllumination(
            fixtures: [],
            roomWidth: room.dimensionsWidth,
            roomLength: room.dimensionsLength,
            furnitures: room.workingLayout?.furnitures ?? [],
            hourOfDay: 12.0
        )

        #expect(report.isAmbientAdequate == false)
        #expect(report.hasAccentLighting == false)
        #expect(!report.recommendations.isEmpty)
    }
}
