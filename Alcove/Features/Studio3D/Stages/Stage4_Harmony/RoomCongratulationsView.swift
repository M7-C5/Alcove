import SwiftUI
import UIKit
import ImageIO

/// Lighting-completion milestone over Stage 5, with repeating center-out confetti bursts.
struct RoomCongratulationsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let assets: CongratulationsAssetStore
    @State private var contentVisible = false
    @State private var animationsRunning = false
    let onViewRoom: () -> Void
    let onBackHome: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let mascotHeight = min(460, min(geometry.size.height * 0.60, max(180, geometry.size.height - 300)))
            let mascotSize = min(mascotHeight * 1.3, min(geometry.size.width - 48, max(160, geometry.size.height - 360)))
            ZStack {
                Color.black.opacity(0.48).ignoresSafeArea()
                CongratulationsConfetti(sprites: assets.sprites, isAnimating: animationsRunning)
                    .id(assets.isReady)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                VStack(spacing: 6) {
                    CongratulationsRibbon()
                        .frame(width: min(480, geometry.size.width * 0.64), height: 88)
                    CongratulationsOtter(animation: assets.animation,
                                         isAnimating: animationsRunning && !reduceMotion && scenePhase == .active)
                        .frame(width: mascotSize, height: mascotSize)
                        .clipped()
                        .accessibilityHidden(true)
                    Text("You've finished designing your room.")
                        .font(.custom("Cleanow", size: 23, relativeTo: .title3))
                        .foregroundStyle(Color.alcoveSurfaceElevated)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 5)
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 24) { actions }
                        VStack(spacing: 12) { actions }
                    }
                    .padding(.top, 8)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .opacity(contentVisible ? 1 : 0)
        }
        .ignoresSafeArea()
        .task {
            await assets.prepare()
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.28), completionCriteria: .logicallyComplete) {
                contentVisible = true
            } completion: {
                if contentVisible { animationsRunning = true }
            }
        }
        .onDisappear {
            animationsRunning = false
            contentVisible = false
        }
        .accessibilityAddTraits(.isModal)
    }

    @ViewBuilder private var actions: some View {
        StudioStageButton(title: "View My Room", role: .add, systemImage: "viewfinder",
                          fontSize: 24, minimumHeight: 56, action: onViewRoom)
        StudioStageButton(title: "Back to Home", role: .next, systemImage: "house",
                          showsNavigationChevron: false, fontSize: 24, minimumHeight: 56, action: onBackHome)
    }
}

private struct CongratulationsRibbon: View {
    var body: some View {
        ZStack {
            RibbonTails()
                .fill(Color.alcovePrimaryFill)
                .overlay(RibbonTails().stroke(Color.alcoveInk, lineWidth: 3))
                .padding(.top, 24)
            RibbonFace()
                .fill(LinearGradient(colors: [.alcovePrimaryHighlight, .alcovePrimaryFill],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RibbonFace().stroke(Color.alcoveInk, lineWidth: 3))
                .padding(.horizontal, 44)
                .padding(.bottom, 12)
            CurvedCongratulationsTitle()
                .padding(.horizontal, 60)
                .padding(.bottom, 16)
        }
    }
}

/// Individual glyphs follow the shallow arch of the ribbon, with natural advances.
private struct CurvedCongratulationsTitle: View {
    @ScaledMetric(relativeTo: .largeTitle) private var fontSize: CGFloat = 34
    private let title = "Congratulations!"

    var body: some View {
        Canvas { context, size in
            let font = UIFont(name: "Cleanow", size: fontSize) ?? .boldSystemFont(ofSize: fontSize)
            let letters = title.map { String($0) }
            let advances = letters.map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            let naturalWidth = advances.reduce(0, +)
            let scale = min(1, size.width / max(1, naturalWidth))
            let width = naturalWidth * scale
            let rise = min(10, width * 0.035)
            var cursor = (size.width - width) / 2
            for (index, letter) in letters.enumerated() {
                let advance = advances[index] * scale
                let x = cursor + advance / 2
                let progress = (x - size.width / 2) * 2 / max(1, width)
                let y = size.height / 2 + rise * (progress * progress - 0.5)
                var glyphContext = context
                glyphContext.translateBy(x: x, y: y)
                glyphContext.rotate(by: .radians(atan(4 * rise * progress / max(1, width))))
                glyphContext.draw(Text(letter)
                    .font(.custom("Cleanow", size: fontSize * scale))
                    .foregroundStyle(Color.alcoveInk), at: .zero, anchor: .center)
                cursor += advance
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct RibbonFace: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.22))
        path.addQuadCurve(to: CGPoint(x: rect.width, y: rect.height * 0.22),
                          control: CGPoint(x: rect.midX, y: -rect.height * 0.2))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.95, y: rect.height * 0.94),
                          control: CGPoint(x: rect.width, y: rect.height * 0.7))
        path.addQuadCurve(to: CGPoint(x: rect.width * 0.05, y: rect.height * 0.94),
                          control: CGPoint(x: rect.midX, y: rect.height * 0.54))
        path.addQuadCurve(to: CGPoint(x: 0, y: rect.height * 0.22),
                          control: CGPoint(x: 0, y: rect.height * 0.7))
        path.closeSubpath()
        return path
    }
}

private struct RibbonTails: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for mirrored in [false, true] {
            func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: (mirrored ? 1 - x : x) * rect.width, y: y * rect.height)
            }
            path.move(to: point(0.15, 0.02))
            path.addQuadCurve(to: point(0.01, 0.23), control: point(0, 0.04))
            path.addLine(to: point(0.05, 0.48))
            path.addLine(to: point(0.035, 0.91))
            path.addQuadCurve(to: point(0.18, 0.67), control: point(0.1, 1))
            path.closeSubpath()
        }
        return path
    }
}

/// Thumbnail decoding bounds GIF memory instead of retaining full-resolution frames.
struct CongratulationsGIF: Sendable {
    let frames: [CGImage]
    let duration: TimeInterval

    @MainActor static func load(maxPixelSize: Int = 480) -> CongratulationsGIF? {
        guard let data = NSDataAsset(name: "CongratsOtter")?.data else { return nil }
        return decode(data: data, maxPixelSize: maxPixelSize)
    }

    nonisolated static func decode(data: Data, maxPixelSize: Int = 480) -> CongratulationsGIF? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }
        let step = max(1, Int(ceil(Double(count) / 60)))
        var frames: [CGImage] = []
        var duration: TimeInterval = 0
        for index in 0..<count {
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            duration += max(0.02, delay)
            guard index.isMultiple(of: step), let image = CGImageSourceCreateThumbnailAtIndex(source, index, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: max(1, maxPixelSize),
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
            ] as CFDictionary) else { continue }
            frames.append(image)
        }
        guard !frames.isEmpty else { return nil }
        return CongratulationsGIF(frames: frames, duration: duration)
    }
}

private struct CongratulationsOtter: UIViewRepresentable {
    let animation: CongratulationsGIF?
    let isAnimating: Bool

    final class Coordinator { var installedAnimation = false }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.isUserInteractionEnabled = false
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        guard let width = proposal.width, let height = proposal.height else { return nil }
        return CGSize(width: width, height: height)
    }
    func updateUIView(_ view: UIImageView, context: Context) {
        if !context.coordinator.installedAnimation, let animation {
            view.image = animation.frames.first.map { UIImage(cgImage: $0) }
            view.animationImages = animation.frames.map { UIImage(cgImage: $0) }
            view.animationDuration = animation.duration
            view.animationRepeatCount = 0
            context.coordinator.installedAnimation = true
        }
        if isAnimating && !view.isAnimating { view.startAnimating() }
        else if !isAnimating { view.stopAnimating() }
    }
    static func dismantleUIView(_ view: UIImageView, coordinator: Coordinator) {
        view.stopAnimating()
        view.animationImages = nil
        view.image = nil
    }
}

#Preview("Room complete") {
    ZStack {
        LightingWorkspaceBackground()
        RoomCongratulationsView(assets: CongratulationsAssetStore(), onViewRoom: {}, onBackHome: {})
    }
}
