import SwiftUI
import SwiftData
import AudioToolbox

/// 3D Studio workspace rendering the low-poly RealityKit room and furniture layout,
/// featuring Resign's circular Sims Action HUD where the rotate button glides along the orbit rim,
/// accompanied by the pedagogical Mascot AI Companion bottom HUD and contextual chat drawer.
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
        Group {
            if viewModel.currentStage == .illumination {
                LightingWorkspaceView(room: room, settings: $viewModel.lightingSettings) {
                    if let router, !router.isEmpty { router.pop() }
                    else { dismiss() }
                }
            } else {
                furnitureStudio
            }
        }
    }

    @ViewBuilder private var furnitureStudio: some View {
        @Bindable var bindableVM = viewModel
        let warningSeverities = viewModel.warningSeverityByFurnitureID

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
                        currentStage: viewModel.currentStage,
                        beforeAfterSplit: viewModel.beforeAfterSplit,
                        revealMode: viewModel.revealMode,
                        furnitureWarningSeverities: warningSeverities,
                        onFurnitureMoved: { event in
                            viewModel.handleFurnitureMoved(event)
                        },
                        onFurnitureDragging: {
                            viewModel.notifyLiveFurnitureDrag()
                        },
                        onComputeWarningSeverities: {
                            viewModel.warningSeverityByFurnitureID
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
                if viewModel.currentStage.unlockedTools.contains(.rotateFurniture),
                   viewModel.currentStage != .harmony,
                   let furniture = viewModel.selectedFurniture,
                   let projected = selectedFurnitureScreenPosition,
                   !viewModel.isArchiveListPresented {
                    let clamped = FurnitureSimsActionHUD.clampedPosition(
                        projected: projected,
                        in: geometry.size
                    )
                    let currentWarningSeverity = warningSeverities[furniture.id]
                    FurnitureSimsActionHUD(
                        furniture: furniture,
                        isColliding: currentWarningSeverity == .collision,
                        warningSeverity: currentWarningSeverity,
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

                    // Top Warning Notification Banner (Red: Collision, Yellow: Can Be Better)
                    if let warning = viewModel.activeTopWarning {
                        let isCollision = warning.severity == .collision
                        let accentTint: Color = isCollision ? .red : .yellow
                        let badgeTint: Color = isCollision ? .red : Color(red: 0.78, green: 0.48, blue: 0.0)

                        Button {
                            if let targetID = warning.furnitureIDs.first {
                                viewModel.selectFurniture(id: targetID)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isCollision ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(badgeTint)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(warning.title.uppercased())
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(badgeTint)
                                        .tracking(0.6)

                                    Text(warning.message)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .frame(minHeight: 44)
                            .frame(maxWidth: 460, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(.regularMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(accentTint.opacity(isCollision ? 0.14 : 0.18))
                                    )
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(accentTint.opacity(isCollision ? 0.65 : 0.80), lineWidth: 1.5)
                            )
                            .shadow(color: accentTint.opacity(0.18), radius: 8, y: 2)
                        }
                        .buttonStyle(.plain)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.2), value: warning.id)
                    } else if viewModel.currentStage != .harmony {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                            Text("No collisions or tight walkways")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.green.opacity(0.30), lineWidth: 1)
                        )
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
                        if viewModel.currentStage.unlockedTools.contains(.inventoryArchive) && viewModel.currentStage != .harmony {
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
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .safeAreaPadding(.top)

                // Stage 4 Harmony: Full-Screen Interactive Split Divider Curtain (Like phone photo editing before/after sliders)
                if viewModel.currentStage == .harmony && !viewModel.isArchiveListPresented {
                    SplitCurtainDividerView(
                        splitFraction: $bindableVM.beforeAfterSplit,
                        totalWidth: geometry.size.width,
                        totalHeight: geometry.size.height
                    )
                    .transition(.opacity)
                    .zIndex(14)
                }

                // Freeform Pen Selection Style Bottom Center Furniture Archive Dock (60% screen width)
                if viewModel.isArchiveListPresented && viewModel.currentStage.unlockedTools.contains(.inventoryArchive) && viewModel.currentStage != .harmony {
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

                // Bottom Mascot & Dialogue Controls (Visible when archive drawer is closed)
                if !viewModel.isArchiveListPresented {
                    VStack {
                        Spacer()
                        StudioBottomHUD(
                            mascotEmotion: viewModel.mascotEmotion,
                            mascotMessage: viewModel.mascotMessage,
                            onTriggerEvaluation: { viewModel.triggerStageEvaluation() },
                            onOpenChat: { viewModel.showingChatDrawer = true }
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .zIndex(15)
                }

                // Stage Walkthrough Dialogue Overlay (Figma Image 1 & 2)
                if viewModel.isWalkthroughActive {
                    StageWalkthroughOverlay(
                        steps: viewModel.walkthroughSteps,
                        currentStepIndex: viewModel.walkthroughStepIndex,
                        onAdvance: { viewModel.advanceWalkthrough() },
                        onSkip: { viewModel.completeWalkthrough() }
                    )
                    .transition(.opacity)
                    .zIndex(30)
                }
            }
            .coordinateSpace(name: "Studio3DViewportSpace")
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .onAppear {
            viewModel.updateMascotGreeting()
            if viewModel.currentStage == .audit {
                viewModel.startWalkthrough()
            }
        }
        .sheet(isPresented: $viewModel.showingChatDrawer) {
            MascotChatDrawer(
                mascotService: viewModel.mascotService,
                feedbackService: viewModel.feedbackService,
                currentStage: viewModel.currentStage,
                room: viewModel.room,
                initialHistory: viewModel.chatHistory,
                onHistoryUpdated: { updated in
                    viewModel.chatHistory = updated
                }
            )
            .presentationDetents([.fraction(0.55), .fraction(0.85), .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.55)))
        }
        .sheet(isPresented: $viewModel.showingEvaluationSheet) {
            if let result = viewModel.evaluationResult {
                StageEvaluationSheet(
                    result: result,
                    stage: viewModel.currentStage,
                    onProceedAnyway: {
                        if viewModel.currentStage == .harmony {
                            isARWalkthroughPresented = true
                        } else {
                            viewModel.advanceToNextStage(result: result)
                        }
                    },
                    onKeepRefining: {
                        // User stays to refine
                    },
                    onReevaluate: {
                        viewModel.triggerStageEvaluation(forceReprompt: true)
                    }
                )
            }
        }
        .sheet(isPresented: $viewModel.showingScorecardSheet) {
            RoomHarmonyScorecardSheet(
                room: viewModel.room,
                metrics: viewModel.currentHarmonyMetrics,
                onInteractiveSplitTapped: {
                    // Scorecard dismisses automatically, leaving user to scrub 3D split
                },
                onStartGuidedTour: {
                    viewModel.startCinematicWalkthroughTour()
                },
                onOpenARWalkthrough: {
                    isARWalkthroughPresented = true
                },
                onCompleteCurriculum: {
                    viewModel.completeHarmonyCurriculum()
                }
            )
            .presentationDetents([.fraction(0.85), .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $isARWalkthroughPresented) {
            ARWalkthroughView(room: room)
        }
        .alert("AR Room Walkthrough", isPresented: $viewModel.showingARPlaceholder) {
            Button("Got it!", role: .cancel) {}
        } message: {
            Text("The 1:1 scale AR Walkthrough experience is currently in development! You'll soon be able to step directly inside your redesigned room in physical augmented reality using ARKit & RealityKit.")
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
