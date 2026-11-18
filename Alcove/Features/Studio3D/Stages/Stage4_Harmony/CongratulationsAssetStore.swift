import SwiftUI
import UIKit

/// Prepare once during Lighting, so the celebration's first frame only presents ready textures.
@Observable @MainActor
final class CongratulationsAssetStore {
    private(set) var animation: CongratulationsGIF?
    private(set) var sprites: [CGImage] = []
    private(set) var isReady = false
    @ObservationIgnored private var preparation: Task<PreparedAssets, Never>?

    private struct PreparedAssets: Sendable {
        let animation: CongratulationsGIF?
        let sprites: [CGImage]
    }

    func prepare() async {
        guard !isReady else { return }
        let task: Task<PreparedAssets, Never>
        if let preparation {
            task = preparation
        } else {
            let data = NSDataAsset(name: "CongratsOtter")?.data
            let sourceImages = (1...9).compactMap { UIImage(named: "Confetti\($0)")?.cgImage }
            task = Task.detached(priority: .userInitiated) {
                PreparedAssets(animation: data.flatMap { CongratulationsGIF.decode(data: $0) },
                               sprites: sourceImages.compactMap(CongratulationsConfettiEmitterView.croppedSprite))
            }
            preparation = task
        }
        let assets = await task.value
        guard !isReady else { return }
        animation = assets.animation
        sprites = assets.sprites
        isReady = true
        preparation = nil
    }
}
