import Testing
import UIKit
import QuartzCore
@testable import Alcove

@Suite("Congratulations assets") @MainActor
struct CongratulationsAssetsTests {
    private static let sprites = (1...9).compactMap { UIImage(named: "Confetti\($0)")?.cgImage }
        .compactMap(CongratulationsConfettiEmitterView.croppedSprite)

    @Test func otterGIFDecodesMultipleBoundedFramesWithValidTiming() throws {
        let animation = try #require(CongratulationsGIF.load(maxPixelSize: 160))
        #expect(animation.frames.count > 1)
        #expect(animation.frames.count <= 60)
        #expect(animation.duration > 0)
        for frame in animation.frames {
            #expect(frame.width <= 160 && frame.height <= 160)
        }
    }

    @Test func celebrationAssetsPrepareOnceAndReuseDecodedTextures() async throws {
        let store = CongratulationsAssetStore()
        await store.prepare()
        let first = try #require(store.animation?.frames.first)
        let sprite = try #require(store.sprites.first)
        #expect(store.isReady && store.sprites.count == 9)
        await store.prepare()
        #expect(store.animation?.frames.first === first)
        #expect(store.sprites.first === sprite)
    }

    @Test func confettiBurstsRepeatFromCenterAndStopWhenInactive() throws {
        let view = CongratulationsConfettiEmitterView(frame: CGRect(x: 0, y: 0, width: 900, height: 675), sprites: Self.sprites)
        view.setActive(true)
        view.layoutIfNeeded()
        #expect(view.emitter.emitterShape == .point)
        #expect(view.emitter.emitterPosition == CGPoint(x: 450, y: 337.5))
        let cells = try #require(view.emitter.emitterCells)
        #expect(cells.count == 9)
        for cell in cells {
            #expect(cell.contents != nil)
            #expect(cell.velocity > 0 && cell.velocityRange > 0)
            #expect(cell.yAcceleration > 0 && cell.alphaSpeed < 0)
            #expect(cell.lifetime > 0 && cell.lifetime < 10)
        }
        let burst = try #require(view.emitter.animation(forKey: "repeatingCenterBurst") as? CAKeyframeAnimation)
        #expect(burst.repeatCount == .infinity)
        #expect(burst.duration == CongratulationsConfettiEmitterView.burstInterval)
        #expect((burst.values?.last as? NSNumber)?.floatValue == 0)

        // Repeated SwiftUI updates must not restart an already-running burst.
        view.setActive(true)
        #expect(view.emitter.animationKeys()?.count == 1)
        view.setActive(false)
        #expect(view.emitter.animationKeys()?.isEmpty != false)
        #expect(view.emitter.emitterCells == nil)
        #expect(view.emitter.birthRate == 0)
    }

    @Test func upwardParticlesCanFallPastScreenBottomBeforeExpiring() throws {
        let view = CongratulationsConfettiEmitterView(frame: CGRect(x: 0, y: 0, width: 1376, height: 1032), sprites: Self.sprites)
        view.setActive(true)
        view.layoutIfNeeded()
        let cells = try #require(view.emitter.emitterCells)
        for cell in cells {
            let earliestExpiry = Double(cell.lifetime - cell.lifetimeRange / 2)
            let upwardSpeed = Double(cell.velocity + cell.velocityRange)
            let downwardTravel = -upwardSpeed * earliestExpiry +
                0.5 * Double(cell.yAcceleration) * earliestExpiry * earliestExpiry
            #expect(downwardTravel > Double(view.bounds.height / 2) + 32)
            #expect(1 + Double(cell.alphaSpeed) * earliestExpiry > 0)
        }
        view.setActive(false)
    }

    @Test func burstFansToBothSidesBeforeFalling() throws {
        let view = CongratulationsConfettiEmitterView(frame: CGRect(x: 0, y: 0, width: 1376, height: 1032), sprites: Self.sprites)
        view.setActive(true)
        view.layoutIfNeeded()
        let cells = try #require(view.emitter.emitterCells)
        let left = cells.filter { cos($0.emissionLongitude) < -0.6 }
        let right = cells.filter { cos($0.emissionLongitude) > 0.6 }
        #expect(left.count >= 4 && right.count >= 4)
        for cell in left + right {
            let horizontalTravel = cos(cell.emissionLongitude) * cell.velocity + cell.xAcceleration / 2
            let verticalTravel = sin(cell.emissionLongitude) * cell.velocity + cell.yAcceleration / 2
            #expect(abs(horizontalTravel) > abs(verticalTravel))
        }
        view.setActive(false)
    }

    @Test func confettiOriginFollowsViewportResize() {
        let view = CongratulationsConfettiEmitterView(frame: CGRect(x: 0, y: 0, width: 900, height: 675), sprites: Self.sprites)
        view.setActive(true)
        view.layoutIfNeeded()
        view.frame.size = CGSize(width: 700, height: 500)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        #expect(view.emitter.emitterPosition == CGPoint(x: 350, y: 250))
        view.setActive(false)
    }

    @Test func composedConfettiReferenceIsAvailable() {
        #expect(UIImage(named: "ConfettiFull") != nil)
    }

    @Test(arguments: 1...9)
    func everyConfettiParticleAssetIsAvailable(index: Int) {
        #expect(UIImage(named: "Confetti\(index)") != nil)
    }
}
