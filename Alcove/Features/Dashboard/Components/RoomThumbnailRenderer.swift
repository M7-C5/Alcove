import Foundation
import UIKit
import simd

/// Renders a crisp isometric 3D dollhouse PNG thumbnail of a `Room` with its preloaded furniture
/// for `DashboardView` room cards—using pure CoreGraphics so it never blocks or contends with
/// RealityKit/RoomPlan Metal sessions.
@MainActor
public enum RoomThumbnailRenderer {

    /// Captures an isometric 3D dollhouse PNG preview of the room floor, cutaway walls, and furniture.
    public static func renderThumbnailData(
        for room: Room,
        size: CGSize = CGSize(width: 640, height: 420)
    ) async -> Data? {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let bg = UIColor(named: "AlcoveSurfaceElevated") ?? UIColor(red: 0.996, green: 0.965, blue: 0.929, alpha: 1.0)
            bg.setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            let w = max(1.5, room.dimensionsWidth)
            let l = max(1.5, room.dimensionsLength)
            let h = max(2.0, min(3.4, room.dimensionsHeight))
            let halfW = w / 2.0
            let halfL = l / 2.0

            // Isometric projection parameters
            let cosA = cos(Double.pi / 6.0) // ~0.866
            let sinA = sin(Double.pi / 6.0) // 0.5
            let rawSpanX = (w + l) * cosA
            let rawSpanY = (w + l) * sinA + h
            let scale = min((Double(size.width) * 0.78) / rawSpanX, (Double(size.height) * 0.78) / rawSpanY)

            let centerX = Double(size.width) * 0.5
            let centerY = Double(size.height) * 0.58

            func project(_ x: Double, _ y: Double, _ z: Double) -> CGPoint {
                let isoX = (x - z) * cosA * scale
                let isoY = ((x + z) * sinA - y) * scale
                return CGPoint(x: centerX + isoX, y: centerY + isoY)
            }

            // 1. Floor polygon
            let floorPts = [
                project(-halfW, 0, -halfL),
                project(halfW, 0, -halfL),
                project(halfW, 0, halfL),
                project(-halfW, 0, halfL)
            ]
            fillPolygon(cg, points: floorPts, fill: UIColor(red: 0.93, green: 0.87, blue: 0.78, alpha: 1.0), stroke: UIColor(red: 0.43, green: 0.27, blue: 0.19, alpha: 0.45), lineWidth: 1.5)

            // 2. Back & Left cutaway walls (facing camera cleanly)
            let backWallPts = [
                project(-halfW, 0, -halfL),
                project(halfW, 0, -halfL),
                project(halfW, h, -halfL),
                project(-halfW, h, -halfL)
            ]
            fillPolygon(cg, points: backWallPts, fill: UIColor(red: 0.98, green: 0.95, blue: 0.91, alpha: 1.0), stroke: UIColor(red: 0.43, green: 0.27, blue: 0.19, alpha: 0.4), lineWidth: 1.5)

            let leftWallPts = [
                project(-halfW, 0, -halfL),
                project(-halfW, 0, halfL),
                project(-halfW, h, halfL),
                project(-halfW, h, -halfL)
            ]
            fillPolygon(cg, points: leftWallPts, fill: UIColor(red: 0.95, green: 0.91, blue: 0.85, alpha: 1.0), stroke: UIColor(red: 0.43, green: 0.27, blue: 0.19, alpha: 0.4), lineWidth: 1.5)

            // 3. Active furniture sorted back-to-front by (x + z) for painter's order
            let layout = room.workingLayout ?? room.baselineLayout
            let items = (layout?.furnitures ?? [])
                .filter { !$0.isArchived }
                .sorted { ($0.positionX + $0.positionZ) < ($1.positionX + $1.positionZ) }

            for item in items {
                drawIsometricBox(cg, item: item, project: project)
            }
        }
        return image.pngData()
    }

    private static func drawIsometricBox(
        _ cg: CGContext,
        item: Furniture,
        project: (Double, Double, Double) -> CGPoint
    ) {
        let hw = max(0.12, item.width / 2.0)
        let hl = max(0.12, item.length / 2.0)
        let baseY = max(0.0, item.positionY)
        let topY = baseY + max(0.18, item.height)

        let cosY = cos(item.rotationYaw)
        let sinY = sin(item.rotationYaw)

        func worldCorner(_ lx: Double, _ y: Double, _ lz: Double) -> CGPoint {
            let wx = item.positionX + (lx * cosY + lz * sinY)
            let wz = item.positionZ + (-lx * sinY + lz * cosY)
            return project(wx, y, wz)
        }

        let b0 = worldCorner(-hw, baseY, -hl)
        let b1 = worldCorner(hw, baseY, -hl)
        let b2 = worldCorner(hw, baseY, hl)
        let b3 = worldCorner(-hw, baseY, hl)

        let t0 = worldCorner(-hw, topY, -hl)
        let t1 = worldCorner(hw, topY, -hl)
        let t2 = worldCorner(hw, topY, hl)
        let t3 = worldCorner(-hw, topY, hl)

        let (topColor, rightColor, frontColor) = palette(for: item.category)
        let inkStroke = UIColor(red: 0.43, green: 0.27, blue: 0.19, alpha: 0.65)

        // Right face (+X)
        fillPolygon(cg, points: [b1, b2, t2, t1], fill: rightColor, stroke: inkStroke, lineWidth: 1.2)
        // Front face (+Z)
        fillPolygon(cg, points: [b3, b2, t2, t3], fill: frontColor, stroke: inkStroke, lineWidth: 1.2)
        // Top face (+Y)
        fillPolygon(cg, points: [t0, t1, t2, t3], fill: topColor, stroke: inkStroke, lineWidth: 1.2)
        _ = b0
    }

    private static func fillPolygon(
        _ cg: CGContext,
        points: [CGPoint],
        fill: UIColor,
        stroke: UIColor,
        lineWidth: CGFloat
    ) {
        guard let first = points.first else { return }
        cg.beginPath()
        cg.move(to: first)
        for pt in points.dropFirst() {
            cg.addLine(to: pt)
        }
        cg.closePath()
        fill.setFill()
        stroke.setStroke()
        cg.setLineWidth(lineWidth)
        cg.setLineJoin(.round)
        cg.drawPath(using: .fillStroke)
    }

    private static func palette(for category: FurnitureCategory) -> (top: UIColor, right: UIColor, front: UIColor) {
        switch category {
        case .bed:
            return (
                UIColor(red: 0.56, green: 0.68, blue: 0.80, alpha: 1.0),
                UIColor(red: 0.42, green: 0.52, blue: 0.64, alpha: 1.0),
                UIColor(red: 0.48, green: 0.59, blue: 0.72, alpha: 1.0)
            )
        case .seating:
            return (
                UIColor(red: 0.94, green: 0.76, blue: 0.36, alpha: 1.0),
                UIColor(red: 0.78, green: 0.60, blue: 0.24, alpha: 1.0),
                UIColor(red: 0.86, green: 0.68, blue: 0.30, alpha: 1.0)
            )
        case .table:
            return (
                UIColor(red: 0.76, green: 0.58, blue: 0.40, alpha: 1.0),
                UIColor(red: 0.58, green: 0.42, blue: 0.27, alpha: 1.0),
                UIColor(red: 0.66, green: 0.49, blue: 0.33, alpha: 1.0)
            )
        case .storage:
            return (
                UIColor(red: 0.64, green: 0.48, blue: 0.35, alpha: 1.0),
                UIColor(red: 0.48, green: 0.34, blue: 0.23, alpha: 1.0),
                UIColor(red: 0.55, green: 0.40, blue: 0.29, alpha: 1.0)
            )
        default:
            return (
                UIColor(red: 0.84, green: 0.79, blue: 0.73, alpha: 1.0),
                UIColor(red: 0.68, green: 0.63, blue: 0.57, alpha: 1.0),
                UIColor(red: 0.76, green: 0.71, blue: 0.65, alpha: 1.0)
            )
        }
    }
}
