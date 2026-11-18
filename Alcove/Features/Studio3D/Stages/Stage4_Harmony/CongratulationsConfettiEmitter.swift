import SwiftUI
import UIKit
import QuartzCore

struct CongratulationsConfetti: View {
    let sprites: [CGImage]
    let isAnimating: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if reduceMotion {
            Image("ConfettiFull").resizable().scaledToFit()
        } else {
            ConfettiEmitter(sprites: sprites, isActive: isAnimating && scenePhase == .active)
        }
    }
}

private struct ConfettiEmitter: UIViewRepresentable {
    let sprites: [CGImage]
    let isActive: Bool

    func makeUIView(context: Context) -> CongratulationsConfettiEmitterView {
        CongratulationsConfettiEmitterView(frame: .zero, sprites: sprites)
    }

    func updateUIView(_ view: CongratulationsConfettiEmitterView, context: Context) {
        view.setActive(isActive)
    }

    static func dismantleUIView(_ view: CongratulationsConfettiEmitterView, coordinator: ()) {
        view.setActive(false)
    }
}

/// Core Animation owns the simulation; no timers or per-frame SwiftUI state updates.
@MainActor
final class CongratulationsConfettiEmitterView: UIView {
    let emitter = CAEmitterLayer()
    private var isActive = false
    private var simulatedSize: CGSize = .zero
    private let sprites: [CGImage]
    static let burstInterval: TimeInterval = 4.0

    init(frame: CGRect, sprites: [CGImage]) {
        self.sprites = sprites
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = true
        emitter.emitterShape = .point
        emitter.emitterMode = .points
        emitter.renderMode = .unordered
        emitter.birthRate = 0
        layer.addSublayer(emitter)
    }

    required init?(coder: NSCoder) { nil }

    func setActive(_ active: Bool) {
        guard isActive != active else { return }
        isActive = active
        if active {
            setNeedsLayout()
        } else {
            emitter.removeAllAnimations()
            emitter.birthRate = 0
            emitter.emitterCells = nil
            simulatedSize = .zero
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard isActive, bounds.width > 0, bounds.height > 0,
              simulatedSize != bounds.size else { return }
        simulatedSize = bounds.size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.midY)
        // Most pieces fan to either side; one central arc keeps the burst varied.
        let directions: [CGFloat] = [-0.18, -.pi + 0.18, -0.45, -.pi + 0.45,
                                     0.14, .pi - 0.14, -.pi / 4, -.pi * 3 / 4, -.pi / 2]
        emitter.emitterCells = sprites.enumerated().map { index, sprite in
            let cell = CAEmitterCell()
            cell.name = "Confetti\(index + 1)"
            cell.contents = sprite
            cell.birthRate = 4
            cell.lifetimeRange = 0.4
            cell.emissionLongitude = directions[index]
            cell.emissionRange = .pi / 4
            cell.velocity = min(340, bounds.width * 0.28)
            cell.velocityRange = cell.velocity * 0.25
            cell.yAcceleration = 110
            cell.xAcceleration = cos(cell.emissionLongitude) >= 0 ? 14 : -14
            // Even a particle fired upward must get below the screen before expiry.
            let upwardSpeed = cell.velocity + cell.velocityRange
            let fallDistance = bounds.height / 2 + 64
            let exitTime = (upwardSpeed + sqrt(upwardSpeed * upwardSpeed +
                                              2 * cell.yAcceleration * fallDistance)) / cell.yAcceleration
            cell.lifetime = Float(exitTime + 0.6)
            // Cropped textures give stars and streamers comparable visible sizes.
            cell.scale = (index.isMultiple(of: 3) ? 58 : 44) / CGFloat(max(sprite.width, sprite.height))
            cell.scaleRange = cell.scale * 0.3
            cell.spin = index.isMultiple(of: 2) ? 0.7 : -0.6
            cell.spinRange = 1.4
            cell.alphaSpeed = -0.05
            return cell
        }
        let burst = CAKeyframeAnimation(keyPath: "birthRate")
        burst.values = [0, 1, 1, 0, 0]
        burst.keyTimes = [0, 0.02, 0.06, 0.09, 1]
        burst.timingFunctions = [CAMediaTimingFunction(name: .easeInEaseOut),
                                 CAMediaTimingFunction(name: .linear),
                                 CAMediaTimingFunction(name: .easeOut),
                                 CAMediaTimingFunction(name: .linear)]
        burst.duration = Self.burstInterval
        burst.repeatCount = .infinity
        emitter.add(burst, forKey: "repeatingCenterBurst")
        CATransaction.commit()
    }

    /// Assets include large transparent margins. Crop a small decoded copy once,
    /// so emitter size describes the visible artwork rather than its empty canvas.
    nonisolated static func croppedSprite(_ source: CGImage) -> CGImage? {
        let width = 256
        let height = max(1, Int(Double(source.height) / Double(source.width) * Double(width)))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        return pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue |
                                            CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            let rgba = bytes.bindMemory(to: UInt8.self)
            var minX = width, minY = height, maxX = -1, maxY = -1
            for y in 0..<height {
                for x in 0..<width where rgba[(y * width + x) * 4 + 3] > 8 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
            guard maxX >= minX, maxY >= minY else { return nil }
            let rect = CGRect(x: max(0, minX - 1), y: max(0, minY - 1),
                              width: min(width - max(0, minX - 1), maxX - minX + 3),
                              height: min(height - max(0, minY - 1), maxY - minY + 3))
            return context.makeImage()?.cropping(to: rect)
        }
    }
}
