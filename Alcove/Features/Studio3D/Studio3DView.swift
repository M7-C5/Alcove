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
    @State private var ghostFurnitureID: UUID? = nil
    @State private var ghostFloorPosition: SIMD3<Float>? = nil
    @State private var isARWalkthroughPresented: Bool = false

    public init(room: Room, stage: StageType = .rearrangement) {
        self.room = room
        self.stage = stage
        self._viewModel = State(initialValue: Studio3DViewModel(room: room, stage: stage))
    }

    public var body: some View {
        @Bindable var bindableVM = viewModel

        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Interactive 3D RealityKit Viewport (unmounted during AR Walkthrough to prevent camera/Metal device contention)
                if !isARWalkthroughPresented {
                    Studio3DViewport(
                        room: room,
                        selectedFurnitureID: $bindableVM.selectedFurnitureID,
                        selectedFurnitureScreenPosition: $selectedFurnitureScreenPosition,
                        viewportSize: geometry.size,
                        ghostFurnitureID: ghostFurnitureID,
                        ghostFloorPosition: ghostFloorPosition,
                        onFurnitureMoved: { event in
                            viewModel.handleFurnitureMoved(event)
                        },
                        onFloorRaycasterResolved: { raycaster in
                            viewModel.floorRaycaster = raycaster
                        },
                        onSnapToViewportResolved: { snapper in
                            viewModel.snapToViewport = snapper
                        },
                        onTapBackground: {
                            if viewModel.isArchiveListPresented {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                    viewModel.isArchiveListPresented = false
                                }
                                playSnapFeedback()
                            }
                        }
                    )
                }

                // Resign-style Circular Sims Action HUD projected over selected furniture
                if let furniture = viewModel.selectedFurniture,
                   let projected = selectedFurnitureScreenPosition,
                   !viewModel.isArchiveListPresented {
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

                // Top Navigation HUD: Back button, Mascot Feedback, and Circular Archive Button
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

                    // Trailing Controls: Point of View (POV) Snap Menu & Circular Archive Button
                    HStack(spacing: 8) {
                        Menu {
                            ForEach(ViewportPreset.allCases) { preset in
                                if preset == .dollhouse {
                                    Divider()
                                }
                                Button {
                                    viewModel.snapToViewport?(preset)
                                    playSnapFeedback()
                                } label: {
                                    Label(preset.title, systemImage: preset.systemImage)
                                }
                            }
                        } label: {
                            Image(systemName: "rotate.3d")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .frame(width: 44, height: 44)
                                .background(.regularMaterial, in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .shadow(
                                    color: Color.black.opacity(0.04),
                                    radius: 8,
                                    y: 2
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Point of View")

                        // 1:1 Life-Size AR Walkthrough Button
                        Button {
                            isARWalkthroughPresented = true
                            playSnapFeedback()
                        } label: {
                            Text("AR")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .frame(width: 44, height: 44)
                                .background(.regularMaterial, in: Circle())
                                .overlay(
                                    Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                                .shadow(
                                    color: Color.black.opacity(0.04),
                                    radius: 8,
                                    y: 2
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Launch 1:1 Life-Size AR Walkthrough")

                        // Circular Archive Button (Icon + number badge pinned on top right)
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                                viewModel.isArchiveListPresented.toggle()
                            }
                            playSnapFeedback()
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: viewModel.isArchiveListPresented ? "archivebox.fill" : "archivebox")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(viewModel.isArchiveListPresented ? .white : .primary)
                                    .frame(width: 44, height: 44)
                                    .background {
                                        if viewModel.isArchiveListPresented {
                                            Circle().fill(Color.accentColor)
                                        } else {
                                            Circle().fill(.regularMaterial)
                                        }
                                    }
                                    .overlay(
                                        Circle()
                                            .stroke(viewModel.isArchiveListPresented ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                                    .shadow(
                                        color: viewModel.isArchiveListPresented ? Color.accentColor.opacity(0.40) : Color.black.opacity(0.04),
                                        radius: 8,
                                        y: 2
                                    )

                                if !viewModel.archivedFurnitures.isEmpty {
                                    Text("\(viewModel.archivedFurnitures.count)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.accentColor, in: Capsule())
                                        .offset(x: 4, y: -4)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(viewModel.isArchiveListPresented ? "Close archive inventory" : "Open archive inventory, \(viewModel.archivedFurnitures.count) items archived")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .safeAreaPadding(.top)

                // Freeform Pen Selection Style Bottom Center Furniture Archive Dock (60% screen width)
                if viewModel.isArchiveListPresented {
                    VStack {
                        Spacer()
                        FurnitureInventoryDock(
                            archivedFurnitures: viewModel.archivedFurnitures,
                            dockWidth: geometry.size.width * 0.60,
                            onRestoreItem: { item, screenPoint in
                                restoreFurnitureItem(item, at: screenPoint)
                            },
                            onCardDragStart: { item, point in
                                ghostFurnitureID = item.id
                                updateGhostFloorPosition(for: item, at: point, roomSize: (Float(room.dimensionsWidth), Float(room.dimensionsLength)))
                            },
                            onCardDragChanged: { point in
                                if let id = ghostFurnitureID,
                                   let item = viewModel.archivedFurnitures.first(where: { $0.id == id }) {
                                    updateGhostFloorPosition(for: item, at: point, roomSize: (Float(room.dimensionsWidth), Float(room.dimensionsLength)))
                                }
                            },
                            onCardDragEnded: { item, point in
                                let dockTopThreshold = geometry.size.height - 120
                                if point.y < dockTopThreshold {
                                    restoreFurnitureItem(item, at: point)
                                }
                                ghostFurnitureID = nil
                                ghostFloorPosition = nil
                            }
                        )
                        .padding(.bottom, 24)
                        .safeAreaPadding(.bottom)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.94, anchor: .bottom)),
                            removal: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.94, anchor: .bottom))
                        )
                    )
                    .zIndex(20)
                }
            }
            .coordinateSpace(name: "Studio3DViewportSpace")
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(isPresented: $isARWalkthroughPresented) {
            ARWalkthroughView(room: room)
        }
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
            viewModel.archiveFurniture(furniture)
        }
    }

    private func updateGhostFloorPosition(for furniture: Furniture, at point: CGPoint, roomSize: (Float, Float)) {
        if let p = viewModel.floorRaycaster?(point) {
            let clamped = FurnitureTransformEngine.clampPosition(
                position: SIMD3<Float>(p.x, 0.0, p.z),
                furnitureWidth: Float(furniture.width),
                furnitureLength: Float(furniture.length),
                rotationYaw: Float(furniture.rotationYaw),
                roomWidth: roomSize.0,
                roomLength: roomSize.1
            )
            ghostFloorPosition = clamped
        }
    }

    private func restoreFurnitureItem(_ furniture: Furniture, at screenPoint: CGPoint?) {
        playSnapFeedback()
        let targetPos: SIMD3<Float>
        if let screenPoint, let p = viewModel.floorRaycaster?(screenPoint) {
            let clamped = FurnitureTransformEngine.clampPosition(
                position: SIMD3<Float>(p.x, 0.0, p.z),
                furnitureWidth: Float(furniture.width),
                furnitureLength: Float(furniture.length),
                rotationYaw: Float(furniture.rotationYaw),
                roomWidth: Float(room.dimensionsWidth),
                roomLength: Float(room.dimensionsLength)
            )
            targetPos = clamped
        } else {
            targetPos = SIMD3<Float>(Float(furniture.positionX), 0.0, Float(furniture.positionZ))
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            furniture.positionX = Double(targetPos.x)
            furniture.positionZ = Double(targetPos.z)
            viewModel.restoreFurniture(furniture)
            viewModel.isArchiveListPresented = false
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
