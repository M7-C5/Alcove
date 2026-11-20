import SwiftUI

/// 1:1 Life-Size AR Spatial Walkthrough Screen for iPad landscape.
/// Provides pure immersive spatial walkthrough of the redesigned room
/// with dynamic ceiling cutaways and a minimalist floating HUD.
public struct ARWalkthroughView: View {
    let room: Room
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var viewModel: ARWalkthroughViewModel

    public init(room: Room) {
        self.room = room
        self._viewModel = State(initialValue: ARWalkthroughViewModel(room: room))
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Full-screen 1:1 AR Viewport (mounted only once camera permission is authorized)
            if viewModel.cameraPermission == .authorized {
                ARWalkthroughViewport(room: room, viewModel: viewModel)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            // Top Navigation HUD: Back button & Instruction pill
            ZStack {
                HStack {
                    StudioStageButton(title: "Back", role: .previous) {
                        StudioViewportFeedback.snap()
                        dismiss()
                    }
                    .accessibilityLabel("Exit AR Walkthrough")

                    Spacer()
                }

                // Center Status / Guidance Pill (Alcove cream notification capsule)
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(viewModel.isPlaced ? Color.alcoveProgressDone : Color.alcovePrimaryFill)
                        Circle()
                            .stroke(Color.alcoveInk, lineWidth: 1.75)
                        Image(systemName: viewModel.isPlaced ? "checkmark" : "viewfinder")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(Color.alcoveInk)
                    }
                    .frame(width: 26, height: 26)

                    Text(viewModel.instructionMessage)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.alcoveInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .padding(.leading, 10)
                .padding(.trailing, 16)
                .frame(minHeight: 44)
                .background(Color.alcoveSurface, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.alcoveInk, lineWidth: 2.5))
                .shadow(color: Color.alcoveInk.opacity(0.18), radius: 8, y: 3)
                .animation(.easeInOut(duration: 0.25), value: viewModel.instructionMessage)
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)

            // Bottom Minimalist Reposition HUD
            if viewModel.isPlaced {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        // Rotate Counter-Clockwise
                        Button {
                            StudioViewportFeedback.snap()
                            viewModel.rotateRoom(by: -.pi / 12.0)
                        } label: {
                            Image(systemName: "rotate.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.alcoveInk)
                                .frame(width: 45, height: 45)
                                .background { StudioTactileCircleBackground() }
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Rotate room counter-clockwise")

                        // Reposition Room Button
                        StudioStageButton(
                            title: "Reposition",
                            role: .next,
                            systemImage: "arrow.counterclockwise",
                            showsNavigationChevron: false
                        ) {
                            StudioViewportFeedback.snap()
                            viewModel.repositionRoom()
                        }
                        .accessibilityLabel("Reposition room anchor")

                        // Rotate Clockwise
                        Button {
                            StudioViewportFeedback.snap()
                            viewModel.rotateRoom(by: .pi / 12.0)
                        } label: {
                            Image(systemName: "rotate.right")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.alcoveInk)
                                .frame(width: 45, height: 45)
                                .background { StudioTactileCircleBackground() }
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Rotate room clockwise")
                    }
                    .padding(.bottom, 24)
                    .safeAreaPadding(.bottom)
                    .frame(maxWidth: .infinity)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Camera Permission Denied Card Overlay
            if viewModel.cameraPermission == .denied {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.alcovePrimaryFill)
                        Circle()
                            .stroke(Color.alcoveInk, lineWidth: 2.5)
                        Image(systemName: "camera.badge.ellipsis")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.alcoveInk)
                    }
                    .frame(width: 64, height: 64)

                    Text("Camera Access Required")
                        .font(.custom("Cleanow", size: 22, relativeTo: .title3))
                        .foregroundStyle(Color.alcoveInk)

                    Text("Alcove requires camera access for the 1:1 life-size spatial walkthrough. Please enable camera access in Settings.")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.alcoveMutedInk)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)

                    StudioStageButton(
                        title: "Open Settings",
                        role: .next,
                        systemImage: "gearshape.fill",
                        showsNavigationChevron: false
                    ) {
                        StudioViewportFeedback.snap()
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                }
                .padding(32)
                .background(Color.alcoveSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.alcoveInk, lineWidth: 3)
                )
                .shadow(color: Color.alcoveInk.opacity(0.22), radius: 20, y: 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .zIndex(30)
            }
        }
        .task {
            viewModel.checkCameraPermission()
            if viewModel.cameraPermission == .notDetermined {
                await viewModel.requestCameraPermission()
            }
        }
    }
}
