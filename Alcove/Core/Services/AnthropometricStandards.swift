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
            nameA.localizedCaseInsensitiveContains("seat") ||
            nameA.localizedCaseInsensitiveContains("stool") ||
            nameA.localizedCaseInsensitiveContains("bench")
        let isSeatingB = categoryB == .seating ||
            nameB.localizedCaseInsensitiveContains("chair") ||
            nameB.localizedCaseInsensitiveContains("sofa") ||
            nameB.localizedCaseInsensitiveContains("seat") ||
            nameB.localizedCaseInsensitiveContains("stool") ||
            nameB.localizedCaseInsensitiveContains("bench")

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
        let isWorkSurfaceA = categoryA == .table ||
            nameA.localizedCaseInsensitiveContains("table") ||
            nameA.localizedCaseInsensitiveContains("desk")
        let isWorkSurfaceB = categoryB == .table ||
            nameB.localizedCaseInsensitiveContains("table") ||
            nameB.localizedCaseInsensitiveContains("desk")
        if (isWorkSurfaceA && isSeatingB) || (isWorkSurfaceB && isSeatingA) {
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

    // MARK: - Rotated Footprint & Opening / Side-by-Side Geometry

    /// Returns world-space rotated axis-aligned half extents for a furniture piece.
    public static func halfExtents(for f: Furniture) -> (x: Double, z: Double) {
        let absCos = abs(cos(f.rotationYaw))
        let absSin = abs(sin(f.rotationYaw))
        return (
            x: (absCos * f.width + absSin * f.length) / 2.0,
            z: (absSin * f.width + absCos * f.length) / 2.0
        )
    }

    private static func localProjectionGaps(
        from target: Furniture,
        to obstacle: Furniture
    ) -> (projForward: Double, targetHalfForward: Double, forwardGap: Double, backwardGap: Double, lateralGap: Double) {
        let forwardX = sin(target.rotationYaw)
        let forwardZ = cos(target.rotationYaw)
        let rightX = cos(target.rotationYaw)
        let rightZ = -sin(target.rotationYaw)

        let dx = obstacle.positionX - target.positionX
        let dz = obstacle.positionZ - target.positionZ
        let projForward = dx * forwardX + dz * forwardZ
        let projRight = dx * rightX + dz * rightZ

        let targetHalfForward = target.length / 2.0
        let targetHalfRight = target.width / 2.0

        let relYaw = obstacle.rotationYaw - target.rotationYaw
        let absCos = abs(cos(relYaw))
        let absSin = abs(sin(relYaw))
        let obsHalfForward = (absSin * obstacle.width + absCos * obstacle.length) / 2.0
        let obsHalfRight = (absCos * obstacle.width + absSin * obstacle.length) / 2.0

        let sumForward = targetHalfForward + obsHalfForward
        let forwardGap = projForward - sumForward
        let backwardGap = -projForward - sumForward
        let lateralGap = abs(projRight) - (targetHalfRight + obsHalfRight)
        return (projForward, targetHalfForward, forwardGap, backwardGap, lateralGap)
    }

    /// True when `obstacle` sits directly in front of `target`'s functional front opening/access side
    /// within `minOpeningClearance` meters.
    public static func blocksFrontOpening(
        of target: Furniture,
        by obstacle: Furniture,
        minOpeningClearance: Double = minimumCirculation
    ) -> Bool {
        let gaps = localProjectionGaps(from: target, to: obstacle)
        return gaps.projForward > gaps.targetHalfForward * 0.25 &&
            gaps.lateralGap < -0.08 &&
            gaps.forwardGap >= -0.05 &&
            gaps.forwardGap < minOpeningClearance
    }

    /// True when `obstacle` blocks a chair/seating piece's rear pull-out egress clearance.
    public static func blocksSeatingRearEgress(
        of seat: Furniture,
        by obstacle: Furniture,
        minClearance: Double = deskRearCirculationMin
    ) -> Bool {
        let isSeat = seat.category == .seating ||
            seat.name.localizedCaseInsensitiveContains("chair") ||
            seat.name.localizedCaseInsensitiveContains("stool")
        guard isSeat else { return false }
        let gaps = localProjectionGaps(from: seat, to: obstacle)
        return gaps.projForward < -gaps.targetHalfForward * 0.25 &&
            gaps.lateralGap < -0.08 &&
            gaps.backwardGap >= -0.05 &&
            gaps.backwardGap < minClearance
    }

    /// True when two furniture items sit cleanly side-by-side (non-colliding) such that no pedestrian
    /// walkway is needed between their touching/adjacent sides (e.g. a wardrobe beside a desk + chair),
    /// and neither blocks the other's front opening or seating pull-out clearance.
    public static func isSideBySideNonBlocking(a: Furniture, b: Furniture) -> Bool {
        let extA = halfExtents(for: a)
        let extB = halfExtents(for: b)
        let gapX = abs(a.positionX - b.positionX) - (extA.x + extB.x)
        let gapZ = abs(a.positionZ - b.positionZ) - (extA.z + extB.z)

        // Interpenetrating on both axes means physical collision, never side-by-side
        guard gapX >= -0.02 || gapZ >= -0.02 else { return false }

        let isStorage: (Furniture) -> Bool = { f in
            f.category == .storage ||
            f.name.localizedCaseInsensitiveContains("wardrobe") ||
            f.name.localizedCaseInsensitiveContains("bookshelf") ||
            f.name.localizedCaseInsensitiveContains("cabinet") ||
            f.name.localizedCaseInsensitiveContains("cupboard") ||
            f.name.localizedCaseInsensitiveContains("dresser") ||
            f.name.localizedCaseInsensitiveContains("nightstand")
        }
        let isTableOrDesk: (Furniture) -> Bool = { f in
            f.category == .table ||
            f.name.localizedCaseInsensitiveContains("desk") ||
            f.name.localizedCaseInsensitiveContains("table")
        }
        let isSeating: (Furniture) -> Bool = { f in
            f.category == .seating ||
            f.name.localizedCaseInsensitiveContains("chair") ||
            f.name.localizedCaseInsensitiveContains("stool")
        }

        let eligiblePair = (isStorage(a) && (isTableOrDesk(b) || isStorage(b) || isSeating(b))) ||
                           (isStorage(b) && (isTableOrDesk(a) || isStorage(a) || isSeating(a)))
        guard eligiblePair else { return false }

        return !blocksFrontOpening(of: a, by: b) &&
            !blocksFrontOpening(of: b, by: a) &&
            !blocksSeatingRearEgress(of: a, by: b) &&
            !blocksSeatingRearEgress(of: b, by: a)
    }
}

