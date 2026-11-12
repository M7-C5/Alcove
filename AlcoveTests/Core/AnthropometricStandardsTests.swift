import Testing
import Foundation
@testable import Alcove

@Suite("Panero & Zelnik Anthropometric Standards Tests")
struct AnthropometricStandardsTests {

    @Test func verifyCirculationComplianceThresholds() {
        // Less than 76.2 cm (0.762m) -> critical bottleneck
        #expect(AnthropometricStandards.evaluateCirculation(clearanceInMeters: 0.60) == .bottleneckCritical)
        #expect(AnthropometricStandards.evaluateCirculation(clearanceInMeters: 0.75) == .bottleneckCritical)

        // Between 76.2 cm and 91.4 cm -> acceptable minimum
        #expect(AnthropometricStandards.evaluateCirculation(clearanceInMeters: 0.762) == .acceptableMinimum)
        #expect(AnthropometricStandards.evaluateCirculation(clearanceInMeters: 0.85) == .acceptableMinimum)

        // Greater than or equal to 91.4 cm (0.914m) -> optimal comfort
        #expect(AnthropometricStandards.evaluateCirculation(clearanceInMeters: 0.914) == .optimalComfort)
        #expect(AnthropometricStandards.evaluateCirculation(clearanceInMeters: 1.20) == .optimalComfort)
    }

    @Test func verifyBedMakingClearanceThresholds() {
        // Less than 66 cm (0.66m) -> critical
        #expect(AnthropometricStandards.evaluateBedMakingClearance(clearanceInMeters: 0.50) == .bottleneckCritical)

        // Between 66 cm and 99 cm -> acceptable minimum
        #expect(AnthropometricStandards.evaluateBedMakingClearance(clearanceInMeters: 0.70) == .acceptableMinimum)

        // Above 99 cm -> optimal
        #expect(AnthropometricStandards.evaluateBedMakingClearance(clearanceInMeters: 1.05) == .optimalComfort)
    }

    @Test func verifyDeskRearClearanceThresholds() {
        // Less than 76.2 cm -> critical
        #expect(AnthropometricStandards.evaluateDeskRearClearance(clearanceInMeters: 0.60) == .bottleneckCritical)

        // Between 76.2 cm and 91.4 cm -> acceptable minimum
        #expect(AnthropometricStandards.evaluateDeskRearClearance(clearanceInMeters: 0.80) == .acceptableMinimum)

        // Above 91.4 cm -> optimal
        #expect(AnthropometricStandards.evaluateDeskRearClearance(clearanceInMeters: 0.95) == .optimalComfort)
    }

    @Test func verifyPaneroZelnikValuesAccuracy() {
        // Verify key numeric values match the user reference specification
        #expect(AnthropometricStandards.minimumCirculation == 0.762)
        #expect(AnthropometricStandards.comfortableCirculation == 0.914)
        #expect(AnthropometricStandards.bedToBedClearanceMin == 0.914)
        #expect(AnthropometricStandards.bedUnderbedActivityMin == 1.168)
        #expect(AnthropometricStandards.bedUnderbedActivityMax == 1.575)
        #expect(AnthropometricStandards.bedMakingClearanceMin == 0.660)
        #expect(AnthropometricStandards.bedMakingClearanceOptimal == 0.990)
        #expect(AnthropometricStandards.diningPlaceSettingWidthMin == 0.610)
        #expect(AnthropometricStandards.diningPlaceSettingWidthOptimal == 0.762)
        #expect(AnthropometricStandards.diningPlaceSettingDepthMin == 0.406)
        #expect(AnthropometricStandards.diningPlaceSettingDepthOptimal == 0.457)
        #expect(AnthropometricStandards.deskRearCirculationMin == 0.762)
        #expect(AnthropometricStandards.deskCirculationWithCarrying == 0.914)
        #expect(AnthropometricStandards.visitorSeatingZoneMin == 0.610)
        #expect(AnthropometricStandards.visitorSeatingZoneMax == 0.762)
        #expect(AnthropometricStandards.extendedVisitorSeatingMin == 0.762)
        #expect(AnthropometricStandards.extendedVisitorSeatingMax == 1.067)
    }

    @Test func verifyFunctionalCompanionPairings() {
        // Floor Lamp + Ergonomic Chair (seating task lighting)
        #expect(AnthropometricStandards.isFunctionalCompanionPair(
            categoryA: .lighting,
            nameA: "Floor Lamp",
            categoryB: .seating,
            nameB: "Ergonomic Chair"
        ))

        // Floor Lamp + Work Desk (desk task lighting)
        #expect(AnthropometricStandards.isFunctionalCompanionPair(
            categoryA: .lighting,
            nameA: "Floor Lamp",
            categoryB: .table,
            nameB: "Work Desk"
        ))

        // Bed + Nightstand
        #expect(AnthropometricStandards.isFunctionalCompanionPair(
            categoryA: .bed,
            nameA: "Queen Bed",
            categoryB: .storage,
            nameB: "Nightstand"
        ))

        // Desk + Chair
        #expect(AnthropometricStandards.isFunctionalCompanionPair(
            categoryA: .table,
            nameA: "Work Desk",
            categoryB: .seating,
            nameB: "Office Chair"
        ))

        // Unrelated heavy pieces (e.g. Bed + Desk) must NOT be companion pairs
        #expect(!AnthropometricStandards.isFunctionalCompanionPair(
            categoryA: .bed,
            nameA: "Queen Bed",
            categoryB: .table,
            nameB: "Work Desk"
        ))
    }
}

