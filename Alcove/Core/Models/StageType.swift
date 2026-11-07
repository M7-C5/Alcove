import Foundation

/// Represents the progressive stages of the interior design curriculum.
public enum StageType: String, Codable, CaseIterable, Sendable, Identifiable {
    case audit
    case rearrangement
    case illumination
    case harmony

    public var id: String { rawValue }

    public var stageNumber: Int {
        switch self {
        case .audit: return 1
        case .rearrangement: return 2
        case .illumination: return 3
        case .harmony: return 4
        }
    }

    public var title: String {
        switch self {
        case .audit: return "The Audit"
        case .rearrangement: return "The Rearrangement"
        case .illumination: return "The Illumination"
        case .harmony: return "The Harmony Reveal"
        }
    }

    public var subtitle: String {
        switch self {
        case .audit: return "Understand your space & bottlenecks"
        case .rearrangement: return "Circulation, clearance & focal points"
        case .illumination: return "Daylight simulation & lighting layers"
        case .harmony: return "Before/After synthesis & final score"
        }
    }

    public var icon: String {
        switch self {
        case .audit: return "magnifyingglass.circle.fill"
        case .rearrangement: return "arrow.up.and.down.and.arrow.left.and.right"
        case .illumination: return "sun.max.fill"
        case .harmony: return "sparkles.rectangle.stack.fill"
        }
    }

    public var nextStage: StageType? {
        switch self {
        case .audit: return .rearrangement
        case .rearrangement: return .illumination
        case .illumination: return .harmony
        case .harmony: return nil
        }
    }
}

/// Tools enabled based on current stage
public enum StudioTool: String, Codable, CaseIterable, Sendable {
    case inspectCamera
    case dragFurniture
    case rotateFurniture
    case inventoryArchive
    case sunScrubber
    case addLightFixture
    case splitBeforeAfter
    case arWalkthrough
}

extension StageType {
    /// Features unlocked at this stage
    public var unlockedTools: Set<StudioTool> {
        switch self {
        case .audit:
            return [.inspectCamera]
        case .rearrangement:
            return [.inspectCamera, .dragFurniture, .rotateFurniture, .inventoryArchive]
        case .illumination:
            return [.inspectCamera, .dragFurniture, .rotateFurniture, .inventoryArchive, .sunScrubber, .addLightFixture]
        case .harmony:
            return Set(StudioTool.allCases)
        }
    }
}
