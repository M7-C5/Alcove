import SwiftUI

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

/// Friendly Mascot character silhouette matching the wireframe aesthetic
public struct MascotFigureView: View {
    public let emotion: MascotEmotion

    public init(emotion: MascotEmotion = .neutral) {
        self.emotion = emotion
    }

    public var body: some View {
        ZStack(alignment: .top) {
            // Stylized Mascot Body
            VStack(spacing: -8) {
                // Head with cute ears
                ZStack {
                    // Left ear
                    Circle()
                        .fill(mascotGradient)
                        .frame(width: 28, height: 28)
                        .offset(x: -24, y: -24)

                    // Right ear
                    Circle()
                        .fill(mascotGradient)
                        .frame(width: 28, height: 28)
                        .offset(x: 24, y: -24)

                    // Head
                    Circle()
                        .fill(mascotGradient)
                        .frame(width: 76, height: 76)

                    // Face expression indicator
                    Text(emotion.emoji)
                        .font(.system(size: 32))
                        .offset(y: 2)
                }

                // Torso & Waving Arm
                ZStack(alignment: .topTrailing) {
                    // Torso
                    Capsule()
                        .fill(mascotGradient)
                        .frame(width: 70, height: 85)

                    // Waving right arm
                    Capsule()
                        .fill(mascotGradient)
                        .frame(width: 22, height: 50)
                        .rotationEffect(.degrees(38))
                        .offset(x: 26, y: -8)

                    // Left resting arm
                    Capsule()
                        .fill(mascotGradient)
                        .frame(width: 20, height: 46)
                        .rotationEffect(.degrees(-25))
                        .offset(x: -30, y: 12)
                }
            }
        }
        .frame(width: 140, height: 180)
        .shadow(color: Color.orange.opacity(0.35), radius: 16, x: 0, y: 8)
    }

    private var mascotGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.62, blue: 0.32),
                Color(red: 0.95, green: 0.44, blue: 0.16)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Fullscreen interactive walkthrough overlay reflecting the Stage 1 & 2 Figma designs.
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
            // Dimmed semi-transparent backdrop
            Color.black.opacity(0.48)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    onAdvance()
                }

            // Top Bar with Skip Button & Page Dots
            VStack {
                HStack {
                    // Step indicators
                    HStack(spacing: 6) {
                        ForEach(0..<steps.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentStepIndex ? Color.orange : Color.white.opacity(0.4))
                                .frame(width: index == currentStepIndex ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.35), value: currentStepIndex)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.ultraThinMaterial))

                    Spacer()

                    // Skip button
                    Button(action: onSkip) {
                        Text("Skip Intro")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.black.opacity(0.4)))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)

                Spacer()
            }

            // Mascot & Speech Callout positioned at bottom-left
            VStack {
                Spacer()

                HStack(alignment: .bottom, spacing: 20) {
                    // Mascot Figure
                    MascotFigureView(emotion: currentStep?.emotion ?? .neutral)
                        .padding(.leading, 32)
                        .padding(.bottom, 24)

                    // Speech Bubble & Tap Prompt
                    if let step = currentStep {
                        VStack(alignment: .leading, spacing: 12) {
                            // Speech Bubble
                            VStack(alignment: .leading, spacing: 6) {
                                if let attributed = try? AttributedString(markdown: step.text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                                    Text(attributed)
                                        .font(.system(size: 19, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color(red: 0.15, green: 0.12, blue: 0.10))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.leading)
                                        .lineSpacing(4)
                                } else {
                                    Text(step.text)
                                        .font(.system(size: 19, weight: .medium, design: .rounded))
                                        .foregroundStyle(Color(red: 0.15, green: 0.12, blue: 0.10))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .multilineTextAlignment(.leading)
                                        .lineSpacing(4)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color(red: 0.99, green: 0.97, blue: 0.93))
                                    .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 10)
                            )
                            .frame(maxWidth: 520, alignment: .leading)

                            // Tap to continue prompt
                            HStack(spacing: 8) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.caption)
                                Text("Tap anywhere to continue")
                                    .font(.footnote.weight(.medium))
                            }
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.leading, 8)
                        }
                        .padding(.bottom, 36)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                    }

                    Spacer()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: currentStepIndex)
    }
}

