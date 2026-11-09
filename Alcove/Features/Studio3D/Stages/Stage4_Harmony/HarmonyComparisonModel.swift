import Foundation

/// Calculated spatial comparison metrics between baseline scan and optimized working layout.
public struct HarmonyComparisonMetrics: Sendable, Equatable {
    public let baselineBottlenecksCount: Int
    public let workingBottlenecksCount: Int
    public let clearanceImprovementPercentage: Int
    public let baselineFloorUtilizationPercentage: Int
    public let workingFloorUtilizationPercentage: Int
    public let archivedItemsCount: Int
    public let activeItemsCount: Int
    public let illuminationScore: Int
    public let overallHarmonyScore: Int
    public let summaryVerdict: String

    public var isImprovement: Bool {
        clearanceImprovementPercentage > 0 || workingBottlenecksCount < baselineBottlenecksCount
    }
}

/// Visual presentation modes for Stage 4 Harmony Reveal comparison.
public enum HarmonyRevealMode: String, Codable, CaseIterable, Sendable, Identifiable {
    case splitSlider
    case sideBySide
    case overlayDiff

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .splitSlider: return "Split Curtain"
        case .sideBySide: return "Side-by-Side"
        case .overlayDiff: return "Overlay Diff"
        }
    }

    public var icon: String {
        switch self {
        case .splitSlider: return "slider.horizontal.2"
        case .sideBySide: return "square.split.2x1"
        case .overlayDiff: return "square.2.layers.3d"
        }
    }
}
