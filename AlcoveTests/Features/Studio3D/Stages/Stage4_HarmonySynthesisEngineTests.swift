import Foundation
import Testing
@testable import Alcove

@Suite("Harmony Synthesis Tests") @MainActor
struct HarmonySynthesisEngineTests {

    @Test func synthesizeHarmonyFromStarterRoom() {
        let engine = HarmonySynthesisEngine()
        let room = SampleData.createStarterRoom()

        let metrics = engine.synthesizeHarmony(room: room)

        #expect(metrics.overallHarmonyScore >= 50)
        #expect(metrics.activeItemsCount > 0)
        #expect(metrics.workingFloorUtilizationPercentage > 0)
        #expect(!metrics.summaryVerdict.isEmpty)
    }

    @Test func harmonyImprovementWhenBottlenecksCleared() {
        let engine = HarmonySynthesisEngine()
        let room = SampleData.createStarterRoom()

        // Initially move Queen Bed right next to Work Desk (< 30cm) to create a bottleneck in baseline
        if let bed = room.baselineLayout?.furnitures.first(where: { $0.name == "Queen Bed" }),
           let desk = room.baselineLayout?.furnitures.first(where: { $0.name == "Work Desk" }) {
            bed.positionX = desk.positionX + 0.2
            bed.positionZ = desk.positionZ + 0.2
        }

        // In working layout, spread them generously
        if let workingBed = room.workingLayout?.furnitures.first(where: { $0.name == "Queen Bed" }) {
            workingBed.positionX = -1.5
            workingBed.positionZ = -1.5
        }

        let metrics = engine.synthesizeHarmony(room: room)
        #expect(metrics.baselineBottlenecksCount > metrics.workingBottlenecksCount)
        #expect(metrics.clearanceImprovementPercentage > 0)
        #expect(metrics.isImprovement == true)
    }

    @Test func harmonyRevealModeProperties() {
        let modes = HarmonyRevealMode.allCases
        #expect(modes.count == 3)
        #expect(modes.contains(.splitSlider))
        #expect(modes.contains(.sideBySide))
        #expect(modes.contains(.overlayDiff))

        for mode in modes {
            #expect(!mode.id.isEmpty)
            #expect(!mode.title.isEmpty)
            #expect(!mode.icon.isEmpty)
        }
    }
}
