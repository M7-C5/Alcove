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
                            .frame(height: geometry.size.height * 0.47)

                        VStack(spacing: 18) {
                            // "Scan Your Room" Header in Cleanow
                            Text("Scan Your Room")
                                .font(.custom("Cleanow", size: 32, relativeTo: .largeTitle))
                                .foregroundStyle(Color(red: 74 / 255, green: 38 / 255, blue: 18 / 255))
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.8)

                            // Explanatory Subtitle in SF Pro Rounded (Warm Golden Chestnut)
                            Text("Turn your space into a 3D\nroom with a single scan.")
                                .font(.system(.title3, design: .rounded, weight: .semibold))
                                .foregroundStyle(Color(red: 131 / 255, green: 86 / 255, blue: 43 / 255))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .minimumScaleFactor(0.85)
                                .frame(maxWidth: 320)

                            // Chunky Tactile Pill "Start >" in Cleanow
                            TactilePillButton(title: "Start >", accessibilityLabel: "Start") {
                                viewModel.start()
                            }
                            .padding(.top, 18)
                        }
                        .frame(maxWidth: 340)

                        Spacer(minLength: 16)
                    }
                    .frame(width: geometry.size.width * 0.50)

                    Spacer(minLength: 0)
                }
            }
        }
        .ignoresSafeArea()
    }
}
