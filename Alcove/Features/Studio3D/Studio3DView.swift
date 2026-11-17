import SwiftUI
import SwiftData
import AudioToolbox

/// 3D Studio workspace rendering the framed RealityKit room, 5-step stage header,
/// circular Sims Action HUD, Otter walkthrough & chat overlays, and bottom-left Otter trigger.
public struct Studio3DView: View {
    @Environment(\.dismiss) private var dismiss
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

    public init(room: Room, stage: StageType = .rearrangement) {
        self.room = room
        self.stage = stage
        self._viewModel = State(initialValue: Studio3DViewModel(room: room, stage: stage))
    }

    public var body: some View {
        Group {
            if viewModel.currentStage == .illumination {
                LightingWorkspaceView(
                    room: room,
                    settings: $viewModel.lightingSettings,
                    isARPresented: isARWalkthroughPresented,
                    onOpenAR: { isARWalkthroughPresented = true }
                ) {
                    if let router, !router.isEmpty { router.pop() }
                    else { dismiss() }
                }
            } else {
                furnitureStudio
            }
        }
    }

    private var stageHeaderTitle: String {
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

                VStack(spacing: 12) {
                    studioHeader
                    stageProgressBar

                    Spacer(minLength: 4)

                    // Centered Framed 3D Room Viewport matching Light Stage UI
                    framedRoomViewport(
                        outerSize: outerGeometry.size,
                        selectedFurnitureID: $bindableVM.selectedFurnitureID,
                        beforeAfterSplit: $bindableVM.beforeAfterSplit,
                        warningSeverities: warningSeverities
                    )

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .padding(.bottom, 16)
                .safeAreaPadding(.top)

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
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .zIndex(15)

                // Floating Camera View & Add Furniture Popovers
                if isCameraMenuPresented || viewModel.isFurnitureCatalogPresented {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.16)) {
                                isCameraMenuPresented = false
                                viewModel.isFurnitureCatalogPresented = false
                                viewModel.swapTargetFurnitureID = nil
                            }
                        }
                        .zIndex(27)
                }

                if isCameraMenuPresented {
                    VStack {
                        HStack {
                            Spacer()
                            cameraMenuPopover
                                .padding(.trailing, 28)
                                .padding(.top, 70)
                                .safeAreaPadding(.top)
                        }
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
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
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        if let target = swapTarget {
                                            viewModel.swapFurniture(target, with: item)
                                        } else {
                                            viewModel.addFurniture(from: item)
                                        }
                                    }
                                },
                                onDismiss: {
                                    viewModel.isFurnitureCatalogPresented = false
                                    viewModel.swapTargetFurnitureID = nil
                                }
                            )
                            .padding(.trailing, 28)
                            .padding(.top, 70)
                            .safeAreaPadding(.top)
                        }
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
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

                // Inline Otter Chat Overlay over the 3D Room
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
            .coordinateSpace(name: "Studio3DViewportSpace")
        }
        .ignoresSafeArea()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.updateMascotGreeting()
            if viewModel.currentStage == .audit || viewModel.currentStage == .rearrangement {
                viewModel.startWalkthrough()
            }
        }
        .onChange(of: viewModel.currentStage) { _, newStage in
            if newStage == .rearrangement {
                viewModel.startWalkthrough()
            }
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
                .presentationBackground(.clear)
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
        .fullScreenCover(isPresented: $isARWalkthroughPresented) {
            ARWalkthroughView(room: room)
        }
        .alert("AR Room Walkthrough", isPresented: $viewModel.showingARPlaceholder) {
            Button("Got it!", role: .cancel) {}
        } message: {
            Text("The 1:1 scale AR Walkthrough experience is currently in development! You'll soon be able to step directly inside your redesigned room in physical augmented reality using ARKit & RealityKit.")
        }
    }

    // MARK: - Top Header & 5-Step Stage Stepper (Figma / Light Stage Style)

    private var studioHeader: some View {
        HStack(spacing: 12) {
            Button {
                switch viewModel.currentStage {
                case .rearrangement:
                    viewModel.switchToStage(.audit)
                case .illumination:
                    viewModel.switchToStage(.rearrangement)
                case .harmony:
                    viewModel.switchToStage(.illumination)
                case .audit:
                    if let router, !router.isEmpty {
                        router.pop()
                    } else {
                        dismiss()
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    Text("Previous Stage")
                }
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0))
                .padding(.horizontal, 16)
                .frame(minWidth: 44, minHeight: 44)
                .background {
                    ZStack {
                        Capsule()
                            .fill(Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0))

                        ZStack {
                            VStack(spacing: 0) {
                                Color(red: 0xF9 / 255.0, green: 0xE4 / 255.0, blue: 0xC9 / 255.0)
                                Color(red: 0xE9 / 255.0, green: 0xC7 / 255.0, blue: 0x9D / 255.0)
                            }

                            Capsule()
                                .fill(Color(red: 0xFF / 255.0, green: 0xF7 / 255.0, blue: 0xE7 / 255.0))
                                .padding(.top, 2)
                                .padding(.bottom, 3.5)
                        }
                        .clipShape(Capsule())
                        .padding(2)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous Stage")

            Text(stageHeaderTitle)
                .font(.custom("Cleanow", size: 32, relativeTo: .title))
                .foregroundStyle(Color.alcoveText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        viewModel.isFurnitureCatalogPresented = false
                        viewModel.swapTargetFurnitureID = nil
                        isCameraMenuPresented.toggle()
                    }
                    playSnapFeedback()
                } label: {
                    Image(systemName: "cube")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0))
                        .frame(width: 45, height: 45)
                        .background {
                            tactileCircleBackground(isCoralActive: isCameraMenuPresented)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Camera view")

                Button {
                    isARWalkthroughPresented = true
                    playSnapFeedback()
                } label: {
                    Text("AR")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0))
                        .frame(width: 45, height: 45)
                        .background {
                            tactileCircleBackground(isCoralActive: false)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Launch 1:1 Life-Size AR Walkthrough")

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
                                .frame(width: 45, height: 45)
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
                        isCameraMenuPresented = false
                        viewModel.openAddFurnitureCatalog()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0))
                            .frame(width: 45, height: 45)
                            .background {
                                tactileCircleBackground(isCoralActive: viewModel.isFurnitureCatalogPresented && viewModel.swapTargetFurnitureID == nil)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add furniture")
                }
            }
        }
    }

    private var cameraMenuPopover: some View {
        let brown = Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0)
        let peach = Color(red: 0xFE / 255.0, green: 0xEE / 255.0, blue: 0xDE / 255.0)
        let anglePresets = ViewportPreset.allCases.filter { $0 != .dollhouse }

        return VStack(alignment: .leading, spacing: 2) {
            ForEach(anglePresets) { preset in
                Button {
                    selectedCameraPreset = preset
                    viewModel.snapToViewport?(preset)
                    playSnapFeedback()
                    withAnimation(.easeInOut(duration: 0.16)) {
                        isCameraMenuPresented = false
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(brown)
                            .opacity(selectedCameraPreset == preset ? 1 : 0)
                            .frame(width: 16)

                        Image(systemName: preset.systemImage)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(brown)
                            .frame(width: 22)

                        Text(preset.title)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(brown)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 40)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(brown)
                .frame(height: 1.5)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

            Button {
                selectedCameraPreset = .dollhouse
                viewModel.snapToViewport?(.dollhouse)
                playSnapFeedback()
                withAnimation(.easeInOut(duration: 0.16)) {
                    isCameraMenuPresented = false
                }
            } label: {
                HStack(spacing: 12) {
                    Color.clear
                        .frame(width: 16)

                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(brown)
                        .frame(width: 22)

                    Text("Reset Angle")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(brown)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 40)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .frame(width: 230)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(peach)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(brown, lineWidth: 2.5)
        )
    }

    @ViewBuilder
    private func tactileCircleBackground(isCoralActive: Bool) -> some View {
        let border = Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0)
        let topHighlight = isCoralActive
            ? Color(red: 0xFE / 255.0, green: 0xF6 / 255.0, blue: 0xED / 255.0)
            : Color(red: 0xF9 / 255.0, green: 0xE4 / 255.0, blue: 0xC9 / 255.0)
        let bottomLip = isCoralActive
            ? Color(red: 0xD2 / 255.0, green: 0x7D / 255.0, blue: 0x5C / 255.0)
            : Color(red: 0xE9 / 255.0, green: 0xC7 / 255.0, blue: 0x9D / 255.0)
        let face = isCoralActive
            ? Color(red: 0xFE / 255.0, green: 0xBC / 255.0, blue: 0xA3 / 255.0)
            : Color(red: 0xFF / 255.0, green: 0xF7 / 255.0, blue: 0xE7 / 255.0)

        ZStack {
            Circle()
                .fill(border)

            ZStack {
                VStack(spacing: 0) {
                    topHighlight
                    bottomLip
                }

                Circle()
                    .fill(face)
                    .padding(.top, 1.5)
                    .padding(.bottom, 3)
            }
            .clipShape(Circle())
            .padding(2)
        }
    }

    private enum StepStatus {
        case done
        case active(Int)
        case upcoming(Int)
    }

    private var progressSteps: [(title: String, status: StepStatus)] {
        switch viewModel.currentStage {
        case .audit:
            return [
                ("Scan", .done),
                ("Check", .active(2)),
                ("Rearrange", .upcoming(3)),
                ("Lighting", .upcoming(4)),
                ("AR", .upcoming(5))
            ]
        case .rearrangement:
            return [
                ("Scan", .done),
                ("Check", .done),
                ("Rearrange", .active(3)),
                ("Lighting", .upcoming(4)),
                ("AR", .upcoming(5))
            ]
        case .illumination:
            return [
                ("Scan", .done),
                ("Check", .done),
                ("Rearrange", .done),
                ("Lighting", .active(4)),
                ("AR", .upcoming(5))
            ]
        case .harmony:
            return [
                ("Scan", .done),
                ("Check", .done),
                ("Rearrange", .done),
                ("Lighting", .done),
                ("AR", .active(5))
            ]
        }
    }

    @ViewBuilder
    private var stageProgressBar: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Text(stageHeaderTitle)
                .font(.custom("Cleanow", size: 22, relativeTo: .headline))
                .foregroundStyle(Color.alcoveText)
        } else {
            let steps = progressSteps
            HStack(alignment: .top, spacing: 6) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    VStack(spacing: 6) {
                        ZStack {
                            switch step.status {
                            case .done:
                                Circle()
                                    .fill(Color.alcoveProgressDone)
                                Circle()
                                    .stroke(Color.alcoveBorder, lineWidth: 2)
                                Image(systemName: "checkmark")
                                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                    .foregroundStyle(Color.alcoveText)
                            case .active(let number):
                                Circle()
                                    .fill(Color.alcovePrimaryFill)
                                Circle()
                                    .stroke(Color.alcoveBorder, lineWidth: 2)
                                Text("\(number)")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(Color.alcoveText)
                            case .upcoming(let number):
                                Circle()
                                    .fill(Color.alcoveProgressInactive)
                                Circle()
                                    .stroke(Color.alcoveMutedInk.opacity(0.45), lineWidth: 1.5)
                                Text("\(number)")
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                    .foregroundStyle(Color.alcoveMutedInk.opacity(0.65))
                            }
                        }
                        .frame(width: 40, height: 40)

                        Text(step.title)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle({
                                switch step.status {
                                case .done, .active: return Color.alcoveText
                                case .upcoming: return Color.alcoveMutedInk.opacity(0.7)
                                }
                            }())
                    }
                    .frame(width: 66)

                    if index < steps.count - 1 {
                        let lineDone: Bool = {
                            if case .done = step.status { return true }
                            return false
                        }()
                        Capsule()
                            .fill(lineDone ? Color.alcoveProgressDone : Color.alcoveMutedInk.opacity(0.3))
                            .frame(maxWidth: 72)
                            .frame(height: 2)
                            .padding(.top, 19)
                    }
                }
            }
            .frame(maxWidth: 660)
            .frame(maxWidth: .infinity)
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
        let panelWidth = min(760, max(320, outerSize.width - 140))

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

                    // Stage 4 Harmony: Split Curtain Divider inside framed viewport
                    if viewModel.currentStage == .harmony && !viewModel.isArchiveListPresented {
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
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(10)
        .lightingPanel()
        .frame(maxWidth: panelWidth, maxHeight: .infinity)
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
