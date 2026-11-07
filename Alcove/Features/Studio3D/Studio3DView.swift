import SwiftUI
import SwiftData

public struct Studio3DView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var room: Room
    @State var currentStage: StageType

    private let mascotService: MascotAIServiceProtocol = MockMascotAIService()

    // Interactive state
    @State private var selectedFurnitureID: UUID?
    @State private var mascotMessage: String = ""
    @State private var mascotEmotion: MascotEmotion = .neutral

    // Stage 3 Illumination state
    @State private var daylightHour: Double = 12.0 // 12 PM noon

    // Stage 4 Harmony Reveal state
    @State private var beforeAfterSplit: Double = 0.5 // Split slider

    // Dialog sheets
    @State private var showingChatDrawer = false
    @State private var showingEvaluationSheet = false
    @State private var evaluationResult: StageEvaluationResult?
    @State private var isEvaluating = false

    public init(room: Room, stage: StageType) {
        self.room = room
        self._currentStage = State(initialValue: stage)
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background Spatial Viewport
            spatialViewport

            // Top HUD Bar
            VStack {
                topHUDBar
                Spacer()
            }

            // Bottom Mascot & Dialogue Controls
            bottomMascotHUD
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            updateMascotGreeting()
        }
        .sheet(isPresented: $showingChatDrawer) {
            MascotChatDrawer(
                mascotService: mascotService,
                currentStage: currentStage,
                room: room
            )
        }
        .sheet(isPresented: $showingEvaluationSheet) {
            if let result = evaluationResult {
                StageEvaluationSheet(
                    result: result,
                    stage: currentStage,
                    onProceedAnyway: {
                        advanceToNextStage(result: result)
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

                // Simulated Daylight Overlay (Stage 3)
                if currentStage == .illumination || currentStage == .harmony {
                    daylightOverlay(width: canvasWidth, height: canvasHeight)
                }

                // 2D/3D Room Spatial Canvas
                RoomSpatialCanvas(
                    room: room,
                    currentStage: currentStage,
                    selectedFurnitureID: $selectedFurnitureID,
                    beforeAfterSplit: beforeAfterSplit,
                    onFurnitureMoved: { event in
                        handleFurnitureMoved(event)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Stage-Specific Tool HUD Overlay (Right Side)
                VStack {
                    Spacer()
                    stageSpecificToolbars
                        .padding(.trailing, 24)
                        .padding(.bottom, 120)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    // MARK: - Top HUD
    private var topHUDBar: some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Stages")
                }
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(.ultraThinMaterial))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(room.name)
                    .font(.headline)
                Text(currentStage.title)
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
            }

            Spacer()

            // Stage Switcher Pills
            HStack(spacing: 6) {
                ForEach(StageType.allCases) { stage in
                    let isUnlocked = room.isUnlocked(stage)
                    let isCurrent = stage == currentStage

                    Button {
                        if isUnlocked {
                            currentStage = stage
                            updateMascotGreeting()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isUnlocked ? stage.icon : "lock.fill")
                                .font(.caption2)
                            Text("S\(stage.stageNumber)")
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(isCurrent ? Color.indigo : (isUnlocked ? Color.secondary.opacity(0.15) : Color.gray.opacity(0.1)))
                        )
                        .foregroundStyle(isCurrent ? .white : (isUnlocked ? .primary : .secondary))
                    }
                    .disabled(!isUnlocked)
                }
            }
            .padding(6)
            .background(Capsule().fill(.ultraThinMaterial))

            // Reset Layout button
            Button {
                room.resetWorkingLayoutToBaseline()
                mascotEmotion = .curious
                mascotMessage = "Restored your room to the original baseline scan!"
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.body.bold())
                    .padding(10)
                    .background(Circle().fill(.ultraThinMaterial))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    // MARK: - Bottom Mascot HUD & Visual Novel Dialogue
    private var bottomMascotHUD: some View {
        HStack(alignment: .bottom, spacing: 16) {
            // Mascot Control Button with Menu
            Menu {
                Button {
                    triggerStageEvaluation()
                } label: {
                    Label("Proceed & Evaluate Stage", systemImage: "flag.checkered")
                }

                Button {
                    showingChatDrawer = true
                } label: {
                    Label("Ask Mascot (Design Chat)", systemImage: "bubble.left.and.bubble.right.fill")
                }
            } label: {
                VStack(spacing: 4) {
                    Text(mascotEmotion.emoji)
                        .font(.system(size: 38))
                    Text("Mascot")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }
                .frame(width: 72, height: 72)
                .background(Circle().fill(Color.indigo.gradient))
                .shadow(color: .indigo.opacity(0.4), radius: 8, x: 0, y: 4)
            }

            // Visual Novel Dialogue Box
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("ALCOVE COMPANION")
                            .font(.caption2.bold())
                            .foregroundStyle(.indigo)
                            .tracking(1.2)

                        Spacer()

                        Button {
                            showingChatDrawer = true
                        } label: {
                            Label("Chat", systemImage: "message.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.indigo)
                        }
                    }

                    Text(mascotMessage)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .animation(.easeInOut, value: mascotMessage)
                }

                Divider()

                // Proceed Button
                Button {
                    triggerStageEvaluation()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                        Text("Proceed")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(.indigo)
                    .frame(width: 58)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
            )
            .frame(maxWidth: 640)
        }
        .padding(.leading, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Stage-Specific Toolbars
    @ViewBuilder
    private var stageSpecificToolbars: some View {
        switch currentStage {
        case .audit:
            VStack(spacing: 8) {
                Label("Audit Mode", systemImage: "magnifyingglass")
                    .font(.caption.bold())
                Text("Inspect clearance bottlenecks")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))

        case .rearrangement:
            if let selectedID = selectedFurnitureID,
               let item = room.workingLayout?.furnitures.first(where: { $0.id == selectedID }) {
                VStack(spacing: 12) {
                    Text(item.name)
                        .font(.headline)

                    // Rotation Controls
                    HStack(spacing: 12) {
                        Button {
                            rotateFurniture(item, delta: -Double.pi / 4)
                        } label: {
                            Image(systemName: "rotate.left.fill")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            rotateFurniture(item, delta: Double.pi / 4)
                        } label: {
                            Image(systemName: "rotate.right.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(role: .destructive) {
                        item.isArchived.toggle()
                        selectedFurnitureID = nil
                        mascotEmotion = .curious
                        mascotMessage = "Archived \(item.name) into inventory!"
                    } label: {
                        Label(item.isArchived ? "Restore" : "Archive to Inventory", systemImage: "archivebox.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
            }

        case .illumination:
            VStack(alignment: .leading, spacing: 8) {
                Label("Daylight Angle: \(String(format: "%.0f:00", daylightHour))", systemImage: "sun.max.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)

                Slider(value: $daylightHour, in: 8.0...20.0, step: 1.0)
                    .tint(.orange)
                    .frame(width: 200)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(.regularMaterial))

        case .harmony:
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Baseline")
                        .font(.caption2.bold())
                    Spacer()
                    Text("New Design")
                        .font(.caption2.bold())
                        .foregroundStyle(.indigo)
                }
                Slider(value: $beforeAfterSplit, in: 0.0...1.0)
                    .tint(.indigo)
                    .frame(width: 220)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(.regularMaterial))
        }
    }

    // MARK: - Sunlight Daylight Overlay
    private func daylightOverlay(width: Double, height: Double) -> some View {
        let normalizedTime = (daylightHour - 8.0) / 12.0 // 0 to 1
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

    // MARK: - Actions & Handlers
    private func updateMascotGreeting() {
        mascotMessage = mascotService.stageGreeting(stage: currentStage, roomName: room.name)
        mascotEmotion = .neutral
    }

    private func handleFurnitureMoved(_ event: FurnitureMoveEvent) {
        if let reaction = mascotService.microReact(
            event: event,
            roomDimensions: (width: room.dimensionsWidth, length: room.dimensionsLength),
            allFurnitures: room.workingLayout?.furnitures ?? []
        ) {
            mascotMessage = reaction.message
            mascotEmotion = reaction.emotion
        }
    }

    private func rotateFurniture(_ item: Furniture, delta: Double) {
        let oldPos = (x: item.positionX, z: item.positionZ)
        item.rotationYaw += delta
        handleFurnitureMoved(
            FurnitureMoveEvent(
                furnitureName: item.name,
                category: item.category,
                oldPosition: oldPos,
                newPosition: oldPos,
                rotationYaw: item.rotationYaw
            )
        )
    }

    private func triggerStageEvaluation() {
        Task {
            isEvaluating = true
            let result = await mascotService.evaluateStage(stage: currentStage, room: room)
            await MainActor.run {
                self.evaluationResult = result
                self.isEvaluating = false
                self.showingEvaluationSheet = true
            }
        }
    }

    private func advanceToNextStage(result: StageEvaluationResult) {
        room.completeStage(currentStage, score: result.score, feedback: result.dialogue)
        if let next = currentStage.nextStage {
            currentStage = next
            updateMascotGreeting()
        }
    }
}

// MARK: - 2D/3D Interactive Room Spatial Canvas
private struct RoomSpatialCanvas: View {
    @Bindable var room: Room
    let currentStage: StageType
    @Binding var selectedFurnitureID: UUID?
    let beforeAfterSplit: Double
    let onFurnitureMoved: (FurnitureMoveEvent) -> Void

    private let scale: Double = 60.0 // Pixels per meter

    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2.0, y: proxy.size.height / 2.0)
            let roomW = room.dimensionsWidth * scale
            let roomL = room.dimensionsLength * scale

            ZStack {
                // Room floor boundary
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 3)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.8))
                    )
                    .frame(width: roomW, height: roomL)
                    .position(center)

                // Floor grid lines
                FloorGrid(width: roomW, height: roomL, step: scale)
                    .position(center)

                // If Stage 4, show split between Baseline and Working
                if currentStage == .harmony && beforeAfterSplit < 0.95 {
                    // Baseline layout items (ghosted)
                    ForEach(room.baselineLayout?.furnitures.filter { !$0.isArchived } ?? []) { item in
                        furnitureItemView(item, center: center, isGhosted: true)
                    }
                }

                // Working layout items
                ForEach(room.workingLayout?.furnitures.filter { !$0.isArchived } ?? []) { item in
                    furnitureItemView(item, center: center, isGhosted: false)
                }
            }
        }
    }

    @ViewBuilder
    private func furnitureItemView(_ item: Furniture, center: CGPoint, isGhosted: Bool) -> some View {
        let isSelected = selectedFurnitureID == item.id && !isGhosted
        let canDrag = currentStage.unlockedTools.contains(.dragFurniture) && !isGhosted

        let itemWidth = item.width * scale
        let itemLength = item.length * scale
        let posX = center.x + (item.positionX * scale)
        let posZ = center.y + (item.positionZ * scale)

        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isGhosted ? Color.gray.opacity(0.3) :
                    (isSelected ? Color.indigo : Color.indigo.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2)
                )

            VStack(spacing: 2) {
                Image(systemName: item.category.icon)
                    .font(.caption2)
                    .foregroundStyle(.white)
                Text(item.name)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(4)
        }
        .frame(width: itemWidth, height: itemLength)
        .rotationEffect(.radians(item.rotationYaw))
        .position(x: posX, y: posZ)
        .onTapGesture {
            if !isGhosted {
                selectedFurnitureID = item.id
            }
        }
        .gesture(
            canDrag ? DragGesture()
                .onChanged { value in
                    selectedFurnitureID = item.id
                    let deltaX = value.translation.width / scale
                    let deltaZ = value.translation.height / scale

                    let halfW = room.dimensionsWidth / 2.0 - (item.width / 2.0)
                    let halfL = room.dimensionsLength / 2.0 - (item.length / 2.0)

                    item.positionX = max(-halfW, min(halfW, item.positionX + (deltaX * 0.05)))
                    item.positionZ = max(-halfL, min(halfL, item.positionZ + (deltaZ * 0.05)))
                }
                .onEnded { _ in
                    onFurnitureMoved(
                        FurnitureMoveEvent(
                            furnitureName: item.name,
                            category: item.category,
                            oldPosition: (x: item.positionX, z: item.positionZ),
                            newPosition: (x: item.positionX, z: item.positionZ),
                            rotationYaw: item.rotationYaw
                        )
                    )
                } : nil
        )
    }
}

private struct FloorGrid: View {
    let width: Double
    let height: Double
    let step: Double

    var body: some View {
        Canvas { context, size in
            var path = Path()
            // Vertical lines
            var x = step
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            // Horizontal lines
            var y = step
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
            context.stroke(path, with: .color(Color.secondary.opacity(0.1)), lineWidth: 1)
        }
        .frame(width: width, height: height)
    }
}
