import RealityKit
import UIKit
import simd

@MainActor
final class LightingViewportOverlay: UIView {
    private let outline = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        outline.fillColor = UIColor.clear.cgColor
        outline.strokeColor = (UIColor(named: "LightingInk") ?? .systemBrown).cgColor
        outline.lineWidth = 2
        outline.lineJoin = .round
        layer.addSublayer(outline)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(points: [CGPoint], bounds: CGRect) -> Bool {
        frame = bounds
        let hull = Self.hull(points)
        let path = UIBezierPath()
        if let first = hull.first {
            path.move(to: first)
            for point in hull.dropFirst() { path.addLine(to: point) }
            path.close()
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        outline.path = path.cgPath
        CATransaction.commit()
        return hull.contains { $0.y < 160 }
    }

    /// Silhouette of the projected room box, including side elevations.
    static func hull(_ points: [CGPoint]) -> [CGPoint] {
        let sorted = points.filter { $0.x.isFinite && $0.y.isFinite }.sorted {
            $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x
        }
        guard sorted.count > 2 else { return sorted }
        func cross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
            (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        }
        func half(_ input: [CGPoint]) -> [CGPoint] {
            var result: [CGPoint] = []
            for point in input {
                while result.count >= 2 && cross(result[result.count - 2], result[result.count - 1], point) <= 0 {
                    result.removeLast()
                }
                result.append(point)
            }
            return result
        }
        return Array(half(sorted).dropLast()) + Array(half(Array(sorted.reversed())).dropLast())
    }
}

/// Fits the entire placement plane into the clear area between the open inspectors.
enum LightingPlacementFraming {
    static func distance(width: Double, length: Double, height: Double, viewport: CGSize) -> Float {
        let panel = min(288.0, max(240.0, viewport.width * 0.21))
        let clearWidth = max(100, viewport.width - 2 * (panel + 44 + 16) - 48)
        let clearHeight = max(100, viewport.height - 360)
        let tangent = tan(40.0 * .pi / 360)
        let vertical = length / (2 * tangent * (clearHeight / max(1, viewport.height)))
        let horizontal = width / (2 * tangent * (clearWidth / max(1, viewport.height)))
        return Float(max(vertical, horizontal) + height * 0.65)
    }
}
