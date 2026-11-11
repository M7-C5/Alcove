import Foundation

/// Explicit column budgets keep inspectors out of the room viewport.
struct LightingWorkspaceLayout: Sendable {
    let usesColumns: Bool
    let inset: Double
    let spacing: Double
    let sourceWidth: Double
    let inspectorWidth: Double
    let viewportWidth: Double

    init(width: Double, accessibilityText: Bool = false) {
        usesColumns = width >= 900 && !accessibilityText
        inset = width >= 1100 ? 24 : 16
        spacing = width >= 1100 ? 24 : 16
        sourceWidth = min(232, max(184, width * 0.19))
        inspectorWidth = min(288, max(240, width * 0.235))
        viewportWidth = max(0, width - 2 * inset - 2 * spacing - sourceWidth - inspectorWidth)
    }
}
