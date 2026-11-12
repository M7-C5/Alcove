import Foundation

/// Anthropometric dimensions and interior space clearances derived from
/// Panero & Zelnik's *Human Dimension & Interior Space*.
///
/// All values are specified in SI meters for direct computation in 3D scene space.
public enum AnthropometricStandards {

    // MARK: - Circulation & Walkways
    /// Minimum clearance for 1-person passage (76.2 cm).
    public static let minimumCirculation: Double = 0.762

    /// Recommended clearance for comfortable circulation or carrying objects (91.4 cm).
    public static let comfortableCirculation: Double = 0.914

    // MARK: - Bedroom Ergonomics
    /// Minimum clearance between twin/multiple beds (91.4 cm).
    public static let bedToBedClearanceMin: Double = 0.914

    /// Bed side-activity and underbed access lower bound (116.8 cm).
    public static let bedUnderbedActivityMin: Double = 1.168

    /// Bed side-activity and underbed access upper bound (157.5 cm).
    public static let bedUnderbedActivityMax: Double = 1.575

    /// Minimum clearance along bed sides for comfortable bed-making (66.0 cm).
    public static let bedMakingClearanceMin: Double = 0.660

    /// Optimal clearance along bed sides for effortless bed-making (99.0 cm).
    public static let bedMakingClearanceOptimal: Double = 0.990

    // MARK: - Dining & Table Setting
    /// Minimum width allocation per dining place setting (61.0 cm).
    public static let diningPlaceSettingWidthMin: Double = 0.610

    /// Optimal width allocation per dining place setting (76.2 cm).
    public static let diningPlaceSettingWidthOptimal: Double = 0.762

    /// Minimum depth allocation per dining place setting (40.6 cm).
    public static let diningPlaceSettingDepthMin: Double = 0.406

    /// Optimal depth allocation per dining place setting (45.7 cm).
    public static let diningPlaceSettingDepthOptimal: Double = 0.457

    // MARK: - Workspace & Desk Clearances
    /// Minimum clearance behind a desk for chair egress and 1-person passage (76.2 cm).
    public static let deskRearCirculationMin: Double = 0.762

    /// Clearance behind a desk accommodating comfortable passage with carried items (91.4 cm).
    public static let deskCirculationWithCarrying: Double = 0.914

    /// Visitor seating boundary in a workspace setting (61.0 cm - 76.2 cm).
    public static let visitorSeatingZoneMin: Double = 0.610
    public static let visitorSeatingZoneMax: Double = 0.762

    /// Extended visitor seating zone for executive/spacious arrangement (76.2 cm - 106.7 cm).
    public static let extendedVisitorSeatingMin: Double = 0.762
    public static let extendedVisitorSeatingMax: Double = 1.067

    // MARK: - Ergonomic Percentile Standards
    /// 5th percentile vertical reach for frequently used shelves/storage (~1.30 m).
    public static let closetFrequentlyUsedShelfReach5thPercentile: Double = 1.300

    /// 95th percentile body breadth clearance standard for access passages.
    public static let clearanceDesign95thPercentile: Double = 0.762

    /// 5th percentile functional arm reach envelope.
    public static let reachDesign5thPercentile: Double = 0.610
}

/// Evaluation status for a spatial walkway or clearance against Panero & Zelnik thresholds
public enum ClearanceCompliance: String, Codable, Sendable {
    /// Below 76.2 cm: Impedes normal 1-person passage
    case bottleneckCritical
    /// Between 76.2 cm and 91.4 cm: Passes minimum, but tight for carrying objects
    case acceptableMinimum
    /// Above 91.4 cm: Optimal comfortable circulation
    case optimalComfort

    public var badgeLabel: String {
        switch self {
        case .bottleneckCritical: return "Bottleneck (<76.2cm)"
        case .acceptableMinimum: return "Minimum Pass (76.2-91.4cm)"
        case .optimalComfort: return "Comfortable (≥91.4cm)"
        }
    }

    public var isPassing: Bool {
        self != .bottleneckCritical
    }
}

extension AnthropometricStandards {
    /// Classifies an observed gap distance against Panero & Zelnik circulation thresholds
    public static func evaluateCirculation(clearanceInMeters: Double) -> ClearanceCompliance {
        if clearanceInMeters < minimumCirculation {
            return .bottleneckCritical
        } else if clearanceInMeters < comfortableCirculation {
            return .acceptableMinimum
        } else {
            return .optimalComfort
        }
    }

    /// Evaluates bed perimeter clearance for bed-making accessibility
    public static func evaluateBedMakingClearance(clearanceInMeters: Double) -> ClearanceCompliance {
        if clearanceInMeters < bedMakingClearanceMin {
            return .bottleneckCritical
        } else if clearanceInMeters < bedMakingClearanceOptimal {
            return .acceptableMinimum
        } else {
            return .optimalComfort
        }
    }

    /// Evaluates desk rear clearance for workspace egress
    public static func evaluateDeskRearClearance(clearanceInMeters: Double) -> ClearanceCompliance {
        if clearanceInMeters < deskRearCirculationMin {
            return .bottleneckCritical
        } else if clearanceInMeters < deskCirculationWithCarrying {
            return .acceptableMinimum
        } else {
            return .optimalComfort
        }
    }

    // MARK: - Intentional & Functional Companion Pairs
    /// Determines whether two furniture items constitute an intentional functional or companion pairing
    /// (e.g. bed + nightstand, desk + chair, lamp + seating/desk/table) that should NOT be evaluated
    /// as a pedestrian walkway circulation bottleneck.
    public static func isFunctionalCompanionPair(
        categoryA: FurnitureCategory,
        nameA: String,
        categoryB: FurnitureCategory,
        nameB: String
    ) -> Bool {
        let isLightingA = categoryA == .lighting ||
            nameA.localizedCaseInsensitiveContains("lamp") ||
            nameA.localizedCaseInsensitiveContains("light") ||
            nameA.localizedCaseInsensitiveContains("pendant") ||
            nameA.localizedCaseInsensitiveContains("sconce")
        let isLightingB = categoryB == .lighting ||
            nameB.localizedCaseInsensitiveContains("lamp") ||
            nameB.localizedCaseInsensitiveContains("light") ||
            nameB.localizedCaseInsensitiveContains("pendant") ||
            nameB.localizedCaseInsensitiveContains("sconce")

        let isSurfaceA = categoryA == .table || categoryA == .storage ||
            nameA.localizedCaseInsensitiveContains("table") ||
            nameA.localizedCaseInsensitiveContains("desk") ||
            nameA.localizedCaseInsensitiveContains("nightstand")
        let isSurfaceB = categoryB == .table || categoryB == .storage ||
            nameB.localizedCaseInsensitiveContains("table") ||
            nameB.localizedCaseInsensitiveContains("desk") ||
            nameB.localizedCaseInsensitiveContains("nightstand")

        let isSeatingA = categoryA == .seating ||
            nameA.localizedCaseInsensitiveContains("chair") ||
            nameA.localizedCaseInsensitiveContains("sofa") ||
            nameA.localizedCaseInsensitiveContains("seat")
        let isSeatingB = categoryB == .seating ||
            nameB.localizedCaseInsensitiveContains("chair") ||
            nameB.localizedCaseInsensitiveContains("sofa") ||
            nameB.localizedCaseInsensitiveContains("seat")

        // 1. Task & Accent Lighting: Lamps standing beside seating (chairs, sofas) or resting on/beside surfaces (desks, tables, nightstands)
        // Karlen & Benya (Lighting Design Basics): Task lighting belongs in direct proximity to visual tasks (reading by a chair, working at a desk).
        if isLightingA && (isSurfaceB || isSeatingB) { return true }
        if isLightingB && (isSurfaceA || isSeatingA) { return true }
        if isLightingA && isLightingB { return true }

        // 2. Bed + Nightstand
        let isBedA = categoryA == .bed || nameA.localizedCaseInsensitiveContains("bed")
        let isBedB = categoryB == .bed || nameB.localizedCaseInsensitiveContains("bed")
        let isNightstandA = nameA.localizedCaseInsensitiveContains("nightstand") || nameA.localizedCaseInsensitiveContains("bedside")
        let isNightstandB = nameB.localizedCaseInsensitiveContains("nightstand") || nameB.localizedCaseInsensitiveContains("bedside")
        if (isBedA && isNightstandB) || (isBedB && isNightstandA) {
            return true
        }

        // 3. Work/Dining Surface + Seating (Desk/Table + Chair/Sofa)
        if (isSurfaceA && isSeatingB) || (isSurfaceB && isSeatingA) {
            return true
        }

        return false
    }

    /// Convenience overload taking two Furniture model instances directly
    public static func isFunctionalCompanionPair(a: Furniture, b: Furniture) -> Bool {
        isFunctionalCompanionPair(
            categoryA: a.category,
            nameA: a.name,
            categoryB: b.category,
            nameB: b.name
        )
    }
}

