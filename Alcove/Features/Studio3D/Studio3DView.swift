import SwiftUI
import SwiftData
import AudioToolbox

/// 3D Studio workspace rendering the low-poly RealityKit room and furniture layout,
/// featuring Resign's circular Sims Action HUD where the rotate button glides along the orbit rim.
public struct Studio3DView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NavigationRouter.self) private var router: NavigationRouter?
    public let room: Room
    public let stage: StageType

    @State private var viewModel: Studio3DViewModel
    @State private var selectedFurnitureScreenPosition: CGPoint? = nil
    @State private var rotateDragStartYaw: Float? = nil
    @State private var wasSnapped: Bool = false

    public init(room: Room, stage: StageType = .rearrangement) {
        self.room = room
        self.stage = stage
        self._viewModel = State(initialValue: Studio3DViewModel(room: room, stage: stage))
    }

    public var body: some View {
        @Bindable var bindableVM = viewModel

        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Interactive 3D RealityKit Viewport
                Studio3DViewport(
                    room: room,
                    selectedFurnitureID: $bindableVM.selectedFurnitureID,
                    selectedFurnitureScreenPosition: $selectedFurnitureScreenPosition,
                    viewportSize: geometry.size,
                    onFurnitureMoved: { event in
                        viewModel.handleFurnitureMoved(event)
                    }
                )

                // Resign-style Circular Sims Action HUD projected over selected furniture
                if let furniture = viewModel.selectedFurniture,
                   let projected = selectedFurnitureScreenPosition {
                    let clamped = FurnitureSimsActionHUD.clampedPosition(
                        projected: projected,
                        in: geometry.size
                    )
                    FurnitureSimsActionHUD(
                        furniture: furniture,
                        isColliding: false,
                        onStepRotate: {
                            handleStepRotate(for: furniture)
                        },
                        onCircularRotate: { deltaAngle in
                            handleCircularRotate(for: furniture, deltaAngle: deltaAngle)
                        },
                        onDragRotateEnded: {
                            handleDragRotateEnded(for: furniture)
                        },
                        onArchive: {
                            handleArchive(for: furniture)
                        }
                    )
                    .position(clamped)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .zIndex(10)
                }

                // Top Navigation HUD: Back button, Mascot Feedback, and Room Title
                HStack(spacing: 12) {
                    Button {
                        if let router, !router.isEmpty {
                            router.pop()
                        } else {
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                            Text("Stages")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(.regularMaterial, in: Capsule())
                    }

                    Spacer()

                    // Mascot Reaction Feedback Pill
                    if !viewModel.mascotMessage.isEmpty {
                        HStack(spacing: 8) {
                            Text(viewModel.mascotEmotion.emoji)
                                .font(.subheadline)
                            Text(viewModel.mascotMessage)
                                .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(.regularMaterial, in: Capsule())
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()

                    // Room Title Pill
                    HStack(spacing: 8) {
                        Image(systemName: "cube.transparent")
                            .foregroundStyle(.secondary)
                        Text(room.name)
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(.regularMaterial, in: Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .safeAreaPadding(.top)
            }
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
    }

    private func handleStepRotate(for furniture: Furniture) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
            viewModel.rotateSelectedFurniture(delta: -.pi / 4.0) // 45° step clockwise
            playSnapFeedback()
        }
    }

    private func handleCircularRotate(for furniture: Furniture, deltaAngle: Float) {
        let startYaw = rotateDragStartYaw ?? Float(furniture.rotationYaw)
        if rotateDragStartYaw == nil {
            rotateDragStartYaw = startYaw
        }
        // Clockwise motion on screen decreases yaw in RealityKit
        let targetYaw = startYaw - deltaAngle
        let snapResult = FurnitureTransformEngine.snapYaw(
            rawYaw: targetYaw,
            step: .pi / 2.0,
            threshold: 0.14
        )
        if snapResult.didSnap && !wasSnapped {
            playSnapFeedback()
            wasSnapped = true
        } else if !snapResult.didSnap {
            wasSnapped = false
        }
        furniture.rotationYaw = Double(snapResult.yaw)
    }

    private func handleDragRotateEnded(for furniture: Furniture) {
        rotateDragStartYaw = nil
        wasSnapped = false
        playSnapFeedback()
        viewModel.handleFurnitureMoved(
            FurnitureMoveEvent(
                furnitureName: furniture.name,
                category: furniture.category,
                oldPosition: (x: furniture.positionX, z: furniture.positionZ),
                newPosition: (x: furniture.positionX, z: furniture.positionZ),
                rotationYaw: furniture.rotationYaw
            )
        )
    }

    private func handleArchive(for furniture: Furniture) {
        playSnapFeedback()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            viewModel.toggleSelectedFurnitureArchive()
        }
    }

    private func playSnapFeedback() {
        // System audio click cue (vital for iPad which has no vibration motor)
        AudioServicesPlaySystemSound(1104)
        // Physical haptic impact (for iPhone and Apple Pencil Pro)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

#Preview("Mock Bedroom & Office") {
    let mockRoom = MockRoomGenerator.generateBedroomOfficeCombo()
    return Studio3DView(room: mockRoom)
}
