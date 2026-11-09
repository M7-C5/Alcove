import Foundation

/// Viewport angle presets for spatial canvas inspection.
public enum ViewportPreset: String, CaseIterable, Identifiable, Sendable {
    case topDown
    case dollhouseIsometric
    case frontElevation
    case sideElevation

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .topDown: return "2D Plan"
        case .dollhouseIsometric: return "3D Dollhouse"
        case .frontElevation: return "Front"
        case .sideElevation: return "Side"
        }
    }

    public var icon: String {
        switch self {
        case .topDown: return "square.topthird.inset.filled"
        case .dollhouseIsometric: return "cube.transparent"
        case .frontElevation: return "rectangle.portrait.and.arrow.forward"
        case .sideElevation: return "arrow.left.to.line"
        }
    }

    public var pitchAngleDegrees: Double {
        switch self {
        case .topDown: return 0.0
        case .dollhouseIsometric: return 40.0
        case .frontElevation: return 75.0
        case .sideElevation: return 75.0
        }
    }

    public var yawAngleDegrees: Double {
        switch self {
        case .topDown: return 0.0
        case .dollhouseIsometric: return -35.0
        case .frontElevation: return 0.0
        case .sideElevation: return -90.0
        }
    }
}
