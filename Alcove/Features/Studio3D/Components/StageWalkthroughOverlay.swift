import SwiftUI
import UIKit

/// Represents a single dialogue step during an interactive stage walkthrough.
public struct WalkthroughStep: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let text: String
    public let emotion: MascotEmotion
    public let highlightedFurnitureName: String?

    public init(
        id: UUID = UUID(),
        text: String,
        emotion: MascotEmotion = .neutral,
        highlightedFurnitureName: String? = nil
    ) {
        self.id = id
        self.text = text
        self.emotion = emotion
        self.highlightedFurnitureName = highlightedFurnitureName
    }
}

/// Otter mascot artwork: automatically loads the `"OtterMascot"` image set from `Assets.xcassets` once added,
/// falling back to a vector placeholder illustration until then.
public struct MascotFigureView: View {
    public static let assetName = "OtterMascot"
    public let emotion: MascotEmotion
    public var showsTablet: Bool

    public init(emotion: MascotEmotion = .neutral, showsTablet: Bool = true) {
        self.emotion = emotion
        self.showsTablet = showsTablet
    }

    private var furFill: some ShapeStyle {
        LinearGradient(
            colors: [Color.alcoveChipShadow, Color.alcoveInk],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    public var body: some View {
        if let customImage = UIImage(named: Self.assetName) {
            Image(uiImage: customImage)
                .resizable()
                .scaledToFit()
                .frame(width: 230, height: 215)
        } else {
            placeholderFigure
        }
    }

    private var placeholderFigure: some View {
        ZStack(alignment: .bottom) {
            // Subtle torso peeking above dialogue card
            Capsule()
                .fill(furFill)
                .overlay(
                    Capsule()
                        .fill(Color.alcoveSurface.opacity(0.65))
                        .frame(width: 44, height: 38)
                        .offset(y: 6)
                )
                .overlay(Capsule().stroke(Color.alcoveBorder, lineWidth: 3))
                .frame(width: 72, height: 48)
                .offset(y: -4)

            // Otter Head + Forehead Goggles
            ZStack {
                // Ears
                Circle()
                    .fill(furFill)
                    .overlay(Circle().fill(Color.alcoveSurface).padding(5))
                    .overlay(Circle().stroke(Color.alcoveBorder, lineWidth: 2.5))
                    .frame(width: 24, height: 24)
                    .offset(x: -44, y: -22)

                Circle()
                    .fill(furFill)
                    .overlay(Circle().fill(Color.alcoveSurface).padding(5))
                    .overlay(Circle().stroke(Color.alcoveBorder, lineWidth: 2.5))
                    .frame(width: 24, height: 24)
                    .offset(x: 44, y: -22)

                // Head
                Ellipse()
                    .fill(furFill)
                    .overlay(Ellipse().stroke(Color.alcoveBorder, lineWidth: 3))
                    .frame(width: 102, height: 82)

                // Rosy Blush Cheeks
                Ellipse()
                    .fill(Color.alcoveChipFill.opacity(0.85))
                    .frame(width: 18, height: 10)
                    .offset(x: -31, y: 12)

                Ellipse()
                    .fill(Color.alcoveChipFill.opacity(0.85))
                    .frame(width: 18, height: 10)
                    .offset(x: 31, y: 12)

                // Cream Muzzle Patch
                Ellipse()
                    .fill(Color.alcoveBackground)
                    .frame(width: 46, height: 28)
                    .offset(y: 15)

                // Eyes
                HStack(spacing: 34) {
                    eyeView
                    eyeView
                }
                .offset(y: -1)

                // Small Nose
                Capsule()
                    .fill(Color.alcoveBorder)
                    .frame(width: 13, height: 8)
                    .offset(y: 8)

                // Expressive Mouth
                mouthView
                    .offset(y: 17)

                // Whiskers
                whiskers(leading: true)
                    .offset(x: -38, y: 11)
                whiskers(leading: false)
                    .offset(x: 38, y: 11)

                // Forehead Goggles
                gogglesView
                    .offset(y: -31)
            }
            .offset(y: -30)

            // Tablet held by Otter paws
            if showsTablet {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.alcoveSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.alcoveBorder, lineWidth: 2.5)
                        )
                        .frame(width: 46, height: 56)
                        .rotationEffect(.degrees(10))

                    Circle()
                        .fill(Color.alcoveBorder.opacity(0.45))
                        .frame(width: 6, height: 6)
                        .offset(y: -2)
                        .rotationEffect(.degrees(10))

                    // Holding paws
                    HStack(spacing: 32) {
                        Capsule()
                            .fill(furFill)
                            .overlay(Capsule().stroke(Color.alcoveBorder, lineWidth: 2.2))
                            .frame(width: 16, height: 12)
                            .rotationEffect(.degrees(14))

                        Capsule()
                            .fill(furFill)
                            .overlay(Capsule().stroke(Color.alcoveBorder, lineWidth: 2.2))
                            .frame(width: 16, height: 12)
                            .rotationEffect(.degrees(-14))
                    }
                    .offset(y: 10)
                }
                .offset(x: 24, y: 2)
            }
        }
        .frame(width: 148, height: 136)
    }

    private var eyeView: some View {
        ZStack {
            Circle()
                .fill(Color.alcoveBorder)
                .frame(width: 10, height: 10)
            Circle()
                .fill(Color.alcoveBackground)
                .frame(width: 3, height: 3)
                .offset(x: 1.5, y: -2)
        }
    }

    @ViewBuilder
    private var mouthView: some View {
        switch emotion {
        case .happy, .celebrating:
            Path { path in
                path.move(to: CGPoint(x: -7, y: 0))
                path.addQuadCurve(to: CGPoint(x: 7, y: 0), control: CGPoint(x: 0, y: 8))
            }
            .stroke(Color.alcoveBorder, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            .frame(width: 16, height: 10)
        case .curious, .thinking:
            Circle()
                .stroke(Color.alcoveBorder, lineWidth: 2.2)
                .frame(width: 7, height: 7)
        case .warning:
            Path { path in
                path.move(to: CGPoint(x: -6, y: 3))
                path.addQuadCurve(to: CGPoint(x: 6, y: 3), control: CGPoint(x: 0, y: -2))
            }
            .stroke(Color.alcoveBorder, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            .frame(width: 14, height: 8)
        case .neutral:
            Path { path in
                path.move(to: CGPoint(x: -7, y: 1))
                path.addQuadCurve(to: CGPoint(x: 0, y: 3), control: CGPoint(x: -3.5, y: 4.5))
                path.addQuadCurve(to: CGPoint(x: 7, y: 1), control: CGPoint(x: 3.5, y: 4.5))
            }
            .stroke(Color.alcoveBorder, style: StrokeStyle(lineWidth: 2.1, lineCap: .round))
            .frame(width: 16, height: 8)
        }
    }

    private func whiskers(leading: Bool) -> some View {
        let dir: CGFloat = leading ? -1 : 1
        return ZStack {
            ForEach([-1, 0, 1], id: \.self) { index in
                Path { path in
                    path.move(to: CGPoint(x: 0, y: CGFloat(index) * 4))
                    path.addLine(to: CGPoint(x: 11 * dir, y: CGFloat(index) * 5))
                }
                .stroke(Color.alcoveBorder, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        }
        .frame(width: 14, height: 14)
    }

    private var gogglesView: some View {
        ZStack {
            // Strap
            Capsule()
                .fill(Color.alcoveSurface)
                .overlay(Capsule().stroke(Color.alcoveBorder, lineWidth: 2))
                .frame(width: 74, height: 12)

            HStack(spacing: 4) {
                goggleLens
                goggleLens
            }
        }
    }

    private var goggleLens: some View {
        ZStack {
            Circle()
                .fill(Color.alcoveBackground)
                .frame(width: 30, height: 24)
                .overlay(
                    Circle().stroke(Color.alcoveBorder, lineWidth: 2.4)
                )

            Ellipse()
                .fill(Color.alcoveSurfaceElevated)
                .overlay(
                    Ellipse().stroke(Color.alcoveBorder.opacity(0.6), lineWidth: 1.2)
                )
                .frame(width: 21, height: 15)
        }
    }
}

/// Compact circular Otter badge for the bottom-left HUD trigger and card corner.
/// Automatically uses `"OtterBadge"` from `Assets.xcassets` once added, or falls back to the placeholder badge.
public struct OtterAvatarBadgeView: View {
    public static let assetName = "OtterBadge"
    public var emotion: MascotEmotion
    public var size: CGFloat
    public var showsQuestionBadge: Bool

    public init(
        emotion: MascotEmotion = .neutral,
        size: CGFloat = 52,
        showsQuestionBadge: Bool = true
    ) {
        self.emotion = emotion
        self.size = size
        self.showsQuestionBadge = showsQuestionBadge
    }

    public var body: some View {
        if let customBadge = UIImage(named: Self.assetName) {
            Image(uiImage: customBadge)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(Color.alcoveSurface)

                    MascotFigureView(emotion: emotion, showsTablet: false)
                        .scaleEffect((size / 52.0) * 0.44)
                        .offset(y: size * 0.14)
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.alcoveBorder, lineWidth: 2.5)
                )

                if showsQuestionBadge {
                    Text("?")
                        .font(.system(size: max(12, size * 0.27), weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.alcoveBorder)
                        .frame(width: size * 0.36, height: size * 0.36)
                        .background(Color.alcovePrimaryFill, in: Circle())
                        .overlay(Circle().stroke(Color.alcoveBorder, lineWidth: 1.8))
                        .offset(x: 4, y: -4)
                }
            }
            .frame(width: size, height: size)
        }
    }
}

/// Reusable `"Otter"` gold pill badge straddling dialogue and chat cards.
/// Tactile 3D rounded card surface matching Alcove's Figma inner-bevel border construction.
struct AlcoveTactileCardBackground: View {
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let topHighlightColor: Color
    let bottomLipColor: Color
    let faceColor: Color
    let topBevel: CGFloat
    let bottomBevel: CGFloat

    init(
        cornerRadius: CGFloat = 24,
        borderWidth: CGFloat = 3,
        topHighlightColor: Color = .alcoveSecondaryShadow,
        bottomLipColor: Color = .alcoveSecondaryShadow,
        faceColor: Color = .alcoveSurfaceElevated,
        topBevel: CGFloat = 0,
        bottomBevel: CGFloat = 4
    ) {
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.topHighlightColor = topHighlightColor
        self.bottomLipColor = bottomLipColor
        self.faceColor = faceColor
        self.topBevel = topBevel
        self.bottomBevel = bottomBevel
    }

    var body: some View {
        let outerShape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let innerShape = RoundedRectangle(cornerRadius: max(1, cornerRadius - borderWidth), style: .continuous)
        ZStack {
            outerShape
                .fill(Color.alcoveBorder)

            ZStack {
                VStack(spacing: 0) {
                    topHighlightColor
                    bottomLipColor
                }

                innerShape
                    .fill(faceColor)
                    .padding(.top, topBevel)
                    .padding(.bottom, bottomBevel)
            }
            .clipShape(innerShape)
            .padding(borderWidth)
        }
    }
}

/// Reusable `"Otter"` gold pill badge with 3D inner bevel straddling dialogue and chat cards.
public struct OtterNamePill: View {
    public init() {}

    public var body: some View {
        Text("Otter")
            .font(.custom("Cleanow", size: 22, relativeTo: .title3))
            .foregroundStyle(Color.alcoveText)
            .padding(.horizontal, 32)
            .padding(.vertical, 9)
            .background {
                ZStack {
                    Capsule()
                        .fill(Color.alcoveBorder)

                    ZStack {
                        VStack(spacing: 0) {
                            Color.alcovePrimaryHighlight
                            Color.alcoveSecondaryShadow
                        }

                        Capsule()
                            .fill(Color.alcoveBadgeGold)
                            .padding(.top, 2)
                            .padding(.bottom, 3.5)
                    }
                    .clipShape(Capsule())
                    .padding(2.5)
                }
            }
    }
}

/// Fullscreen interactive walkthrough overlay styled cleanly to match Alcove Figma designs.
public struct StageWalkthroughOverlay: View {
    let steps: [WalkthroughStep]
    let currentStepIndex: Int
    let onAdvance: () -> Void
    let onSkip: () -> Void

    public init(
        steps: [WalkthroughStep],
        currentStepIndex: Int,
        onAdvance: @escaping () -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.steps = steps
        self.currentStepIndex = currentStepIndex
        self.onAdvance = onAdvance
        self.onSkip = onSkip
    }

    private var currentStep: WalkthroughStep? {
        guard currentStepIndex >= 0 && currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }

    public var body: some View {
        ZStack {
            // Dimmed semi-transparent backdrop over the live room
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    onAdvance()
                }

            // Bottom Otter Mascot (behind card & pill) + Cream Dialogue Card
            VStack {
                Spacer()

                if let step = currentStep {
                    HStack(alignment: .center, spacing: 16) {
                        Text(step.text)
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.alcoveText)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button(action: onAdvance) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.alcoveText)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(currentStepIndex < steps.count - 1 ? "Next dialogue step" : "Finish walkthrough")
                    }
                    .padding(.leading, 44)
                    .padding(.trailing, 24)
                    .padding(.vertical, 34)
                    .frame(maxWidth: 980, alignment: .leading)
                    .background {
                        AlcoveTactileCardBackground(
                            cornerRadius: 24,
                            borderWidth: 3,
                            topHighlightColor: .alcoveSurfaceElevated,
                            bottomLipColor: .alcoveSecondaryShadow,
                            faceColor: .alcoveSurfaceElevated,
                            topBevel: 0,
                            bottomBevel: 4
                        )
                    }
                    // Background applied after card fill renders Otter BEHIND both card and name pill
                    .background(alignment: .topLeading) {
                        MascotFigureView(emotion: step.emotion, showsTablet: true)
                            .offset(x: -4, y: -196)
                            .allowsHitTesting(false)
                    }
                    .overlay(alignment: .topLeading) {
                        OtterNamePill()
                            .offset(x: 44, y: -22)
                            .allowsHitTesting(false)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 24)
                    .safeAreaPadding(.bottom)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    ))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentStepIndex)
    }
}
