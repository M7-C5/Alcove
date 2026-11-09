import SwiftUI
import SwiftData

public struct Studio3DView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NavigationRouter.self) private var router: NavigationRouter?
    @State private var viewModel: Studio3DViewModel

    public init(room: Room, stage: StageType) {
        self._viewModel = State(initialValue: Studio3DViewModel(room: room, stage: stage))
    }

    public init(viewModel: Studio3DViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Spatial Viewport
            spatialViewport

            // Top HUD Bar
            VStack {
                StudioTopHUD(
                    roomName: viewModel.room.name,
                    currentStage: viewModel.currentStage,
                    room: viewModel.room,
                    isVoiceEnabled: viewModel.isVoiceNarrationEnabled,
                    onToggleVoice: { viewModel.toggleVoiceNarration() },
                    onDismiss: {
                        if let router, !router.isEmpty {
                            router.pop()
                        } else {
                            dismiss()
                        }
                    },
                    onSelectStage: { viewModel.switchToStage($0) },
                    onResetLayout: { viewModel.resetWorkingLayout() }
                )
                Spacer()
            }

            // Bottom Mascot & Dialogue Controls
            StudioBottomHUD(
                mascotEmotion: viewModel.mascotEmotion,
                mascotMessage: viewModel.mascotMessage,
                onTriggerEvaluation: { viewModel.triggerStageEvaluation() },
                onOpenChat: { viewModel.showingChatDrawer = true }
            )
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            viewModel.updateMascotGreeting()
        }
        .sheet(isPresented: $viewModel.showingChatDrawer) {
            MascotChatDrawer(
                mascotService: viewModel.mascotService,
                feedbackService: viewModel.feedbackService,
                currentStage: viewModel.currentStage,
                room: viewModel.room
            )
        }
        .sheet(isPresented: $viewModel.showingEvaluationSheet) {
            if let result = viewModel.evaluationResult {
                StageEvaluationSheet(
                    result: result,
                    stage: viewModel.currentStage,
                    onProceedAnyway: {
                        viewModel.advanceToNextStage(result: result)
                    },
                    onKeepRefining: {
                        // User stays to refine
                    }
                )
            }
        }
    }

    // MARK: - Spatial Viewport
    private var spatialViewport: some View {
        GeometryReader { proxy in
            let canvasWidth = proxy.size.width
            let canvasHeight = proxy.size.height

            ZStack {
                // Background room floor
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                // Simulated Daylight Overlay (Stage 3 & 4)
                if viewModel.currentStage == .illumination || viewModel.currentStage == .harmony {
                    daylightOverlay(width: canvasWidth, height: canvasHeight)
                }

                // 2D/3D Room Spatial Canvas
                RoomSpatialCanvas(
                    room: viewModel.room,
                    currentStage: viewModel.currentStage,
                    selectedFurnitureID: $viewModel.selectedFurnitureID,
                    beforeAfterSplit: viewModel.beforeAfterSplit,
                    revealMode: viewModel.revealMode,
                    cameraState: viewModel.cameraState,
                    onFurnitureMoved: { event in
                        viewModel.handleFurnitureMoved(event)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Stage-Specific Tool HUD Overlay (Right Side)
                VStack {
                    Spacer()
                    StudioToolbars(
                        currentStage: viewModel.currentStage,
                        selectedFurniture: viewModel.selectedFurniture,
                        daylightHour: $viewModel.daylightHour,
                        beforeAfterSplit: $viewModel.beforeAfterSplit,
                        cameraPreset: $viewModel.cameraState.preset,
                        revealMode: $viewModel.revealMode,
                        illuminationReport: viewModel.currentStage == .illumination ? viewModel.currentIlluminationReport : nil,
                        harmonyMetrics: viewModel.currentStage == .harmony ? viewModel.currentHarmonyMetrics : nil,
                        onRotate: { viewModel.rotateSelectedFurniture(delta: $0) },
                        onToggleArchive: { viewModel.toggleSelectedFurnitureArchive() },
                        onAddFixture: { name, layer in
                            viewModel.addLightFixture(name: name, layer: layer)
                        }
                    )
                    .padding(.trailing, 24)
                    .padding(.bottom, 120)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - Sunlight Daylight Overlay
    private func daylightOverlay(width: Double, height: Double) -> some View {
        let normalizedTime = (viewModel.daylightHour - 8.0) / 12.0 // 0 to 1
        let sunX = width * normalizedTime
        let sunY = height * 0.15

        return RadialGradient(
            colors: [
                Color.yellow.opacity(0.18),
                Color.orange.opacity(0.08),
                Color.clear
            ],
            center: UnitPoint(x: sunX / width, y: sunY / height),
            startRadius: 20,
            endRadius: 400
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
