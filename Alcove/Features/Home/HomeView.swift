import SwiftUI
import SwiftData

/// The landing home and entry screen for Alcove in iPad landscape.
/// Greets users with warm hand-drawn branding and transitions irreversibly into the main Dashboard.
public struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel = HomeViewModel()

    public init() {}

    public var body: some View {
        Group {
            if viewModel.hasEnteredDashboard {
                DashboardView()
            } else {
                homeLandingContent
            }
        }
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.35),
            value: viewModel.hasEnteredDashboard
        )
    }

    private var homeLandingContent: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Fullscreen Hand-Drawn Mascot & Room Artwork constrained strictly to viewport bounds.
                Image(decorative: "HomeBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()

                // Left Column Action Overlay (Positioned directly below the Alcove title)
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        // Top spacer positioned below the Alcove logo
                        Spacer()
                            .frame(height: geometry.size.height * 0.475)

                        VStack(spacing: 12) {
                            // "Let's Explore Your Room" Header in Cleanow
                            Text("Let's Explore Your Room")
                                .font(.custom("Cleanow", size: 42, relativeTo: .largeTitle))
                                .foregroundStyle(.alcoveText)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            // Explanatory Subtitle in SF Pro Rounded
                            Text("Start by scanning your room\nand see it come to life in 3D!")
                                .font(.system(size: 28, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.alcoveSubtitleInk)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .minimumScaleFactor(0.85)
                                .frame(maxWidth: 360)

                            // Chunky Tactile Pill "Start" with chevron in Cleanow
                            TactilePillButton(title: "Start", accessibilityLabel: "Start", systemImage: "chevron.right") {
                                viewModel.start()
                            }
                            .padding(.top, 22)
                        }
                        .frame(maxWidth: 420)

                        Spacer(minLength: 16)
                    }
                    .frame(width: geometry.size.width * 0.475)

                    Spacer(minLength: 0)
                }
            }
        }
        .ignoresSafeArea()
    }
}
