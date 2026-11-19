import SwiftUI
import SwiftData
import AudioToolbox

/// 3D Studio workspace rendering the framed RealityKit room, 5-step stage header,
/// circular Sims Action HUD, Otter walkthrough & chat overlays, and bottom-left Otter trigger.
public struct Studio3DView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    @State private var viewportFrame: CGRect = .zero
    @State private var isCameraMenuPresented: Bool = false
    @State private var selectedCameraPreset: ViewportPreset = .dollhouse
    @State private var headerOverlapped: Bool = false
    @State private var congratulationsAssets = CongratulationsAssetStore()
    @State private var isFreeEditResultMode: Bool
    @State private var resultMode: ResultWorkspaceMode = .overview
    @State private var isResultSplitActive: Bool = false

    public init(room: Room, stage: StageType = .rearrangement) {
        self.room = room
        self.stage = stage
        let completedCurriculum = room.isCompleted(.harmony) || room.isUnlocked(.harmony)
        self._isFreeEditResultMode = State(initialValue: completedCurriculum)
        self._viewModel = State(initialValue: Studio3DViewModel(room: room, stage: completedCurriculum ? .harmony : stage))
    }

    private func returnToDashboard() {
        if isFreeEditResultMode && !room.isCompleted(.harmony) {
            let metrics = viewModel.currentHarmonyMetrics
            room.completeStage(.harmony, score: metrics.overallHarmonyScore, feedback: metrics.summaryVerdict)
        }
        if let router {
            router.popToRoot()
        } else {
            dismiss()
        }
        playSnapFeedback()
    }

    private func switchResultMode(_ mode: ResultWorkspaceMode) {
        isCameraMenuPresented = false
        viewModel.isFurnitureCatalogPresented = false
        viewModel.isArchiveListPresented = false
        viewModel.swapTargetFurnitureID = nil
        resultMode = mode
        switch mode {
        case .overview:
            viewModel.switchToStage(.harmony)
        case .lighting:
            viewModel.switchToStage(.illumination)
        case .rearrange:
            viewModel.switchToStage(.rearrangement)
        }
        playSnapFeedback()
    }

    public var body: some View {
        ZStack {
            if viewModel.currentStage == .illumination {
                LightingWorkspaceView(
                    room: room,
                    settings: $viewModel.lightingSettings,
                    isARPresented: isARWalkthroughPresented,
                    onOpenAR: { isARWalkthroughPresented = true },
                    onNextStage: {
                        viewModel.markLayoutDirty()
                        viewModel.triggerStageEvaluation()
                    },
                    isAdvancing: viewModel.isEvaluating,
                    onTapOtter: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showingChatDrawer = true
                        }
                    },
                    onSelectStage: { targetStage in
                        viewModel.switchToStage(targetStage)
                        playSnapFeedback()
                    },
                    isResultMode: isFreeEditResultMode,
                    onSelectResultMode: { mode in
                        switchResultMode(mode)
                    },
                    onBackToDashboard: {
                        returnToDashboard()
                    }
                ) {
                    viewModel.switchToStage(.rearrangement)
                }
            } else {
                furnitureStudio
            }

            // Inline Otter Chat Overlay over any active stage (including Lighting)
            if viewModel.showingChatDrawer {
                MascotChatDrawer(
                    mascotService: viewModel.mascotService,
                    feedbackService: viewModel.feedbackService,
                    currentStage: viewModel.currentStage,
                    room: viewModel.room,
                    initialHistory: viewModel.chatHistory,
                    onHistoryUpdated: { updated in
                        viewModel.chatHistory = updated
                    },
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.showingChatDrawer = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(32)
            }
        }
        .onChange(of: viewModel.currentStage) { _, newStage in
            if newStage == .harmony && !isFreeEditResultMode {
                isFreeEditResultMode = true
                resultMode = .overview
            }
        }
        .overlay {
            if viewModel.showingCongratulations {
                RoomCongratulationsView(assets: congratulationsAssets, onViewRoom: {
                    viewModel.showingCongratulations = false
                    isARWalkthroughPresented = true
                }, onBackHome: {
                    viewModel.showingCongratulations = false
                    if let router { router.popToRoot() } else { dismiss() }
                })
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .task(id: viewModel.currentStage == .illumination) {
            if viewModel.currentStage == .illumination {
                await congratulationsAssets.prepare()
            }
        }

        .fullScreenCover(isPresented: $isARWalkthroughPresented) {
            ARWalkthroughView(room: room)
        }
        .sheet(isPresented: $viewModel.showingEvaluationSheet, onDismiss: {
            guard viewModel.congratulationsAwaitingDismissal else { return }
            Task {
                await congratulationsAssets.prepare()
                viewModel.evaluationSheetDidDismiss()
            }
        }) {
            if let result = viewModel.evaluationResult {
                let presentedStage = viewModel.evaluationPresentationStage ?? viewModel.currentStage
                StageEvaluationSheet(
                    result: result,
                    stage: presentedStage,
                    onProceedAnyway: {
                        if presentedStage == .harmony {
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
                .presentationBackground(.clear)
            }
        }
    }

    private var stageHeaderTitle: String {
        if isFreeEditResultMode {
            switch resultMode {
            case .overview: return "Result"
            case .lighting: return "Result: Lighting"
            case .rearrange: return "Result: Rearrange"
            }
        }
        switch viewModel.currentStage {
        case .audit:
            return "Stage 2: Check Your Room"
        case .rearrangement:
            return "Stage 3: Rearrange Your Room"
        case .illumination:
            return "Stage 4: Light Your Room"
        case .harmony:
            return "Stage 5: Harmony Reveal"
        }
    }

    @ViewBuilder private var furnitureStudio: some View {
        @Bindable var bindableVM = viewModel
        let warningSeverities = viewModel.warningSeverityByFurnitureID

        GeometryReader { outerGeometry in
            ZStack(alignment: .bottomLeading) {
                LightingWorkspaceBackground()

                // Full-bleed 3D Room Viewport (unboxed so users can freely zoom & orbit edge-to-edge)
                framedRoomViewport(
                    outerSize: outerGeometry.size,
                    selectedFurnitureID: $bindableVM.selectedFurnitureID,
                    beforeAfterSplit: $bindableVM.beforeAfterSplit,
                    warningSeverities: warningSeverities
                )
                .ignoresSafeArea()

                VStack(spacing: 12) {
                    studioHeader
                    if !isFreeEditResultMode {
                        stageProgressBar
                            .opacity(headerOverlapped ? 0 : 1)
                            .accessibilityHidden(headerOverlapped)
                    }
                    Spacer()
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .padding(.bottom, 16)
                .safeAreaPadding(.top)
                .animation(.easeInOut(duration: 0.2), value: headerOverlapped)

                // Bottom-Center Furniture Archive Dock (when archive open)
                if viewModel.isArchiveListPresented && viewModel.currentStage.unlockedTools.contains(.inventoryArchive) && viewModel.currentStage != .harmony {
                    VStack {
                        Spacer()
                        FurnitureInventoryDock(
                            archivedFurnitures: viewModel.archivedFurnitures,
                            dockWidth: min(540, max(280, outerGeometry.size.width - 360)),
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
                                let dockTopThreshold = outerGeometry.size.height - 120
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

                // Bottom-Left Floating Otter Logo, Centered Collision/Warning Banner, & Bottom-Right Next Stage Button
                VStack {
                    Spacer()
                    ZStack(alignment: .bottom) {
                        StudioBottomHUD(
                            mascotEmotion: viewModel.mascotEmotion,
                            mascotMessage: viewModel.mascotMessage,
                            showsNextStage: !isFreeEditResultMode,
                            onTriggerEvaluation: { viewModel.triggerStageEvaluation() },
                            onOpenChat: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.showingChatDrawer = true
                                }
                            }
                        )

                        if !viewModel.isArchiveListPresented && !viewModel.isWalkthroughActive && !viewModel.showingChatDrawer {
                            warningBanner
                                .padding(.horizontal, 180)
                                .padding(.bottom, 18)
                                .safeAreaPadding(.bottom)
                                .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.activeTopWarning?.id)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .zIndex(15)

                // Top-Right Liquid Glass Morphing Overlays (appear directly on top of the header buttons)
                if isCameraMenuPresented || viewModel.isFurnitureCatalogPresented {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                                isCameraMenuPresented = false
                                viewModel.isFurnitureCatalogPresented = false
                                viewModel.swapTargetFurnitureID = nil
                            }
                        }
                        .zIndex(27)
                }

                if isCameraMenuPresented {
                    let buttonsToRight: Int = if isFreeEditResultMode {
                        3 + (resultMode == .rearrange ? 2 : 0)
                    } else {
                        (viewModel.currentStage.unlockedTools.contains(.inventoryArchive) && viewModel.currentStage != .harmony ? 1 : 0)
                        + (viewModel.canManipulateFurniture ? 1 : 0)
                    }
                    let cameraTrailing: CGFloat = 28 + CGFloat(buttonsToRight) * 59
                    VStack {
                        HStack {
                            Spacer()
                            cameraMenuPopover
                                .padding(.trailing, cameraTrailing)
                                .padding(.top, 16)
                                .safeAreaPadding(.top)
                        }
                        Spacer()
                    }
                    .transition(
                        .scale(scale: 0.18, anchor: .topTrailing)
                            .combined(with: .opacity)
                    )
                    .zIndex(28)
                }

                if viewModel.isFurnitureCatalogPresented {
                    let swapTarget = viewModel.swapTargetFurnitureID.flatMap { id in
                        room.workingLayout?.furnitures.first(where: { $0.id == id })
                    }
                    VStack {
                        HStack {
                            Spacer()
                            FurnitureCatalogSheet(
                                swapTarget: swapTarget,
                                onSelectItem: { item in
                                    playSnapFeedback()
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                                        if let target = swapTarget {
                                            viewModel.swapFurniture(target, with: item)
                                        } else {
                                            viewModel.addFurniture(from: item)
                                        }
                                    }
                                },
                                onDismiss: {
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                                        viewModel.isFurnitureCatalogPresented = false
                                        viewModel.swapTargetFurnitureID = nil
                                    }
                                }
                            )
                            .padding(.trailing, isFreeEditResultMode ? 87 : 28)
                            .padding(.top, 16)
                            .safeAreaPadding(.top)
                        }
                        Spacer()
                    }
                    .transition(
                        .scale(scale: 0.18, anchor: .topTrailing)
                            .combined(with: .opacity)
                    )
                    .zIndex(28)
                }

                // Stage Walkthrough Dialogue Overlay
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
            .animation(.spring(response: 0.32, dampingFraction: 0.84), value: viewModel.isWalkthroughActive)
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: viewModel.currentStage)
            .animation(.spring(response: 0.34, dampingFraction: 0.78), value: isCameraMenuPresented)
            .animation(.spring(response: 0.34, dampingFraction: 0.78), value: viewModel.isFurnitureCatalogPresented)
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.updateMascotGreeting()
            if viewModel.currentStage == .audit || viewModel.currentStage == .rearrangement {
                viewModel.startWalkthroughIfNeeded()
            }
        }
        .onDisappear {
            viewModel.refreshRoomThumbnail(modelContext: modelContext)
        }
        .onChange(of: viewModel.currentStage) { _, newStage in
            if newStage == .audit || newStage == .rearrangement {
                viewModel.startWalkthroughIfNeeded()
            }
        }
        .sheet(isPresented: $viewModel.showingScorecardSheet) {
            RoomHarmonyScorecardSheet(
                room: viewModel.room,
                metrics: viewModel.currentHarmonyMetrics,
                onInteractiveSplitTapped: {
                    // Scorecard dismisses automatically
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
        .alert("AR Room Walkthrough", isPresented: $viewModel.showingARPlaceholder) {
            Button("Got it!", role: .cancel) {}
        } message: {
            Text("The 1:1 scale AR Walkthrough experience is currently in development! You'll soon be able to step directly inside your redesigned room in physical augmented reality using ARKit & RealityKit.")
        }
    }

    // MARK: - Top Header & 5-Step Stage Stepper (Figma / Light Stage Style)

    private var studioHeader: some View {
        StudioHeaderLayout(title: stageHeaderTitle, titleHidden: headerOverlapped) {
            if isFreeEditResultMode {
                StudioStageButton(title: "Back", role: .previous) {
                    returnToDashboard()
                }
            } else {
                Button {
                    returnToDashboard()
                } label: {
                    Image(systemName: "house")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0))
                        .frame(width: 49, height: 45)
                        .background { tactileCircleBackground(isCoralActive: false) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Home")
                if viewModel.currentStage != .audit {
                    StudioStageButton(title: "Previous Stage", role: .previous) {
                        switch viewModel.currentStage {
                        case .rearrangement:
                            viewModel.switchToStage(.audit)
                        case .illumination:
                            viewModel.switchToStage(.rearrangement)
                        case .harmony:
                            viewModel.switchToStage(.illumination)
                        case .audit:
                            break
                        }
                    }
                } else {
                    Color.clear
                        .frame(width: 100, height: 44)
                }
            }

        } actions: {
            HStack(spacing: 10) {
                if isFreeEditResultMode {
                    StudioResultIconButton(
                        systemImage: "arrow.left.and.right",
                        active: resultMode == .overview && isResultSplitActive,
                        accessibilityLabel: "Toggle Before and After Split"
                    ) {
                        if resultMode == .overview {
                            isResultSplitActive.toggle()
                            playSnapFeedback()
                        } else {
                            isResultSplitActive = true
                            switchResultMode(.overview)
                        }
                    }
                }

                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                        viewModel.isFurnitureCatalogPresented = false
                        viewModel.swapTargetFurnitureID = nil
                        isCameraMenuPresented.toggle()
                    }
                    playSnapFeedback()
                } label: {
                    Image(systemName: "rotate.3d")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0))
                        .frame(width: 49, height: 45)
                        .background {
                            tactileCircleBackground(isCoralActive: isCameraMenuPresented)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Camera view")

                if isFreeEditResultMode {
                    StudioResultIconButton(
                        systemImage: "lightbulb",
                        active: resultMode == .lighting,
                        accessibilityLabel: "Lighting"
                    ) {
                        switchResultMode(.lighting)
                    }

                    StudioResultIconButton(
                        systemImage: "arrow.up.and.down.and.arrow.left.and.right",
                        active: resultMode == .rearrange,
                        accessibilityLabel: "Rearrange"
                    ) {
                        switchResultMode(resultMode == .rearrange ? .overview : .rearrange)
                    }
                }


                if viewModel.currentStage.unlockedTools.contains(.inventoryArchive) && viewModel.currentStage != .harmony {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                            viewModel.isArchiveListPresented.toggle()
                        }
                        playSnapFeedback()
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "archivebox")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0))
                                .frame(width: 49, height: 45)
                                .background {
                                    tactileCircleBackground(isCoralActive: viewModel.isArchiveListPresented)
                                }

                            if !viewModel.archivedFurnitures.isEmpty {
                                Text("\(viewModel.archivedFurnitures.count)")
                                    .font(.system(.caption2, design: .rounded, weight: .bold))
                                    .foregroundStyle(Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.alcovePrimaryFill, in: Capsule())
                                    .overlay(Capsule().stroke(Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0), lineWidth: 1.5))
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(viewModel.isArchiveListPresented ? "Close archive inventory" : "Open archive inventory, \(viewModel.archivedFurnitures.count) items archived")
                }

                if viewModel.canManipulateFurniture {
                    Button {
                        playSnapFeedback()
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                            isCameraMenuPresented = false
                            viewModel.openAddFurnitureCatalog()
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0))
                            .frame(width: 49, height: 45)
                            .background {
                                tactileCircleBackground(isCoralActive: viewModel.isFurnitureCatalogPresented && viewModel.swapTargetFurnitureID == nil)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add furniture")
                }

                if isFreeEditResultMode {
                    StudioResultIconButton(
                        labelText: "AR",
                        accessibilityLabel: "Launch 1:1 Life-Size AR Walkthrough"
                    ) {
                        isARWalkthroughPresented = true
                        playSnapFeedback()
                    }
                }
            }
        }
    }

    private var cameraMenuPopover: some View {
        StudioCameraMenuContent(selected: selectedCameraPreset) { preset in
            selectedCameraPreset = preset
            viewModel.snapToViewport?(preset)
            playSnapFeedback()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.80)) {
                isCameraMenuPresented = false
            }
        }
    }

    private func tactileCircleBackground(isCoralActive: Bool) -> some View {
        StudioTactileCircleBackground(active: isCoralActive)
    }

    private var stageProgressBar: some View {
        StudioStageProgress(
            stage: viewModel.currentStage,
            room: room,
            accessibilityTitle: stageHeaderTitle
        ) { targetStage in
            viewModel.switchToStage(targetStage)
            playSnapFeedback()
        }
    }

    // MARK: - Centered Framed 3D Room Viewport

    @ViewBuilder
    private func framedRoomViewport(
        outerSize: CGSize,
        selectedFurnitureID: Binding<UUID?>,
        beforeAfterSplit: Binding<Double>,
        warningSeverities: [UUID: SpatialWarningSeverity]
    ) -> some View {
        ZStack {
            GeometryReader { viewportGeometry in
                ZStack(alignment: .top) {
                    if !isARWalkthroughPresented {
                        Studio3DViewport(
                            room: room,
                            selectedFurnitureID: selectedFurnitureID,
                            selectedFurnitureScreenPosition: $selectedFurnitureScreenPosition,
                            viewportSize: viewportGeometry.size,
                            ghostFurnitureID: ghostFurnitureID,
                            ghostFloorPosition: ghostFloorPosition,
                            currentStage: (isFreeEditResultMode && resultMode == .overview && !isResultSplitActive) ? .audit : viewModel.currentStage,
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
                            },
                            onHeaderOverlap: { headerOverlapped = $0 }
                        )
                        .background {
                            GeometryReader { frameProxy in
                                Color.clear
                                    .onAppear {
                                        viewportFrame = frameProxy.frame(in: .named("Studio3DViewportSpace"))
                                    }
                                    .onChange(of: frameProxy.size) {
                                        viewportFrame = frameProxy.frame(in: .named("Studio3DViewportSpace"))
                                    }
                            }
                        }
                    }

                    // Resign-style Circular Sims Action HUD projected inside framed viewport
                    if viewModel.currentStage.unlockedTools.contains(.rotateFurniture),
                       viewModel.currentStage != .harmony,
                       let furniture = viewModel.selectedFurniture,
                       let projected = selectedFurnitureScreenPosition,
                       !viewModel.isArchiveListPresented {
                        let clamped = FurnitureSimsActionHUD.clampedPosition(
                            projected: projected,
                            in: viewportGeometry.size
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
                            },
                            onSwap: {
                                viewModel.openSwapFurnitureCatalog(for: furniture)
                            },
                            onRemove: furniture.isUserAdded ? {
                                handleRemove(for: furniture)
                            } : nil
                        )
                        .position(clamped)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                        .zIndex(10)
                    }

                    // Stage 4 Harmony: Split Curtain Divider inside viewport
                    if viewModel.currentStage == .harmony
                        && (!isFreeEditResultMode || (resultMode == .overview && isResultSplitActive))
                        && !viewModel.isArchiveListPresented {
                        SplitCurtainDividerView(
                            splitFraction: beforeAfterSplit,
                            totalWidth: viewportGeometry.size.width,
                            totalHeight: viewportGeometry.size.height
                        )
                        .transition(.opacity)
                        .zIndex(14)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var warningBanner: some View {
        if let warning = viewModel.activeTopWarning {
            let isCollision = warning.severity == .collision
            let bannerFill = isCollision
                ? Color(red: 0xD4 / 255.0, green: 0x63 / 255.0, blue: 0x63 / 255.0)
                : Color(red: 0xFB / 255.0, green: 0xEA / 255.0, blue: 0xB6 / 255.0)
            let foregroundInk: Color = isCollision ? .white : Color.alcoveText

            Button {
                if let targetID = warning.furnitureIDs.first {
                    viewModel.selectFurniture(id: targetID)
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Image(systemName: isCollision ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(foregroundInk)

                        Text(warning.title.uppercased())
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(foregroundInk)
                            .tracking(0.5)
                    }

                    Text(warning.message)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(isCollision ? Color.white.opacity(0.95) : Color.alcoveText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
                .frame(maxWidth: 460, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(bannerFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.alcoveBorder, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.2), value: warning.id)
        }
    }

    // MARK: - Interaction Helpers

    private func handleStepRotate(for furniture: Furniture) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
            viewModel.rotateSelectedFurniture(delta: -.pi / 4.0)
            playSnapFeedback()
        }
    }

    private func handleCircularRotate(for furniture: Furniture, deltaAngle: Float) {
        let startYaw = rotateDragStartYaw ?? Float(furniture.rotationYaw)
        if rotateDragStartYaw == nil {
            rotateDragStartYaw = startYaw
        }
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

    private func handleRemove(for furniture: Furniture) {
        playSnapFeedback()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            viewModel.removeFurniture(furniture)
        }
    }

    private func viewportLocalPoint(from screenPoint: CGPoint) -> CGPoint {
        guard viewportFrame.width > 0 else { return screenPoint }
        return CGPoint(
            x: screenPoint.x - viewportFrame.minX,
            y: screenPoint.y - viewportFrame.minY
        )
    }

    private func updateGhostFloorPosition(for furniture: Furniture, at point: CGPoint, roomSize: (Float, Float)) {
        if let p = viewModel.floorRaycaster?(viewportLocalPoint(from: point)) {
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
        if let screenPoint, let p = viewModel.floorRaycaster?(viewportLocalPoint(from: screenPoint)) {
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
        AudioServicesPlaySystemSound(1104)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}

#Preview("Mock Bedroom & Office") {
    let mockRoom = MockRoomGenerator.generateBedroomOfficeCombo()
    return Studio3DView(room: mockRoom)
}
