import SwiftUI

public struct FloorGridView: View {
    let width: Double
    let height: Double
    let step: Double

    public init(width: Double, height: Double, step: Double) {
        self.width = width
        self.height = height
        self.step = step
    }

    public var body: some View {
        Canvas { context, size in
            var path = Path()
            // Vertical lines
            var x = step
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            // Horizontal lines
            var y = step
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(Color.secondary.opacity(0.1)), lineWidth: 1)
        }
        .frame(width: width, height: height)
    }
}
