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
            // Full-screen 1:1 AR Viewport
            ARWalkthroughViewport(room: room, viewModel: viewModel)
                .ignoresSafeArea()

            // Top Navigation HUD: Dismiss button & Instruction pill
            HStack(spacing: 14) {
                // Circular Close Button (44x44pt HIG compliant)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.regularMaterial, in: Circle())
                        .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Exit AR Walkthrough")

                Spacer()

                // Center Status / Guidance Pill
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isPlaced ? "checkmark.circle.fill" : "viewfinder")
                        .foregroundStyle(viewModel.isPlaced ? Color.green : Color.accentColor)
                    Text(viewModel.instructionMessage)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
                .animation(.easeInOut(duration: 0.25), value: viewModel.instructionMessage)

                Spacer()

                // Placeholder balancer for symmetric centering
                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .safeAreaPadding(.top)

            // Bottom Minimalist Reposition HUD
            if viewModel.isPlaced {
                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        // Rotate Counter-Clockwise
                        Button {
                            viewModel.rotateRoom(by: -.pi / 12.0)
                        } label: {
                            Image(systemName: "rotate.left")
                                .font(.body.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .background(.regularMaterial, in: Circle())
                                .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Rotate room counter-clockwise")

                        // Reposition Room Button
                        Button {
                            viewModel.repositionRoom()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reposition")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .background(.regularMaterial, in: Capsule())
                            .overlay(Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Reposition room anchor")

                        // Rotate Clockwise
                        Button {
                            viewModel.rotateRoom(by: .pi / 12.0)
                        } label: {
                            Image(systemName: "rotate.right")
                                .font(.body.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .background(.regularMaterial, in: Circle())
                                .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
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
                    Image(systemName: "camera.badge.ellipsis")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.accentColor)

                    Text("Camera Access Required")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("Alcove requires camera access for the 1:1 life-size spatial walkthrough. Please enable camera access in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)

                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        Text("Open Settings")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .frame(minHeight: 44)
                            .background(Color.accentColor, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(32)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 24, y: 8)
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
