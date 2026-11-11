import SwiftUI

public struct RoomSpatialCanvas: View {
    @Bindable var room: Room
    let currentStage: StageType
    @Binding var selectedFurnitureID: UUID?
    @Binding var selectedLightFixtureID: UUID?
    let beforeAfterSplit: Double
    let revealMode: HarmonyRevealMode
    let cameraState: SpatialViewportCameraState?
    let onFurnitureMoved: (FurnitureMoveEvent) -> Void

    @State private var dragInitialPositions: [UUID: (x: Double, z: Double)] = [:]
    @State private var currentMagnification: CGFloat = 1.0
    @State private var activePanTranslation: CGSize = .zero

    private let scale: Double = 60.0 // Pixels per meter

    public init(
        room: Room,
        currentStage: StageType,
        selectedFurnitureID: Binding<UUID?>,
        selectedLightFixtureID: Binding<UUID?> = .constant(nil),
        beforeAfterSplit: Double,
        revealMode: HarmonyRevealMode = .splitSlider,
        cameraState: SpatialViewportCameraState? = nil,
        onFurnitureMoved: @escaping (FurnitureMoveEvent) -> Void
    ) {
        self.room = room
        self.currentStage = currentStage
        self._selectedFurnitureID = selectedFurnitureID
        self._selectedLightFixtureID = selectedLightFixtureID
        self.beforeAfterSplit = beforeAfterSplit
        self.revealMode = revealMode
        self.cameraState = cameraState
        self.onFurnitureMoved = onFurnitureMoved
    }

    public var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2.0, y: proxy.size.height / 2.0)
            let roomW = room.dimensionsWidth * scale
            let roomL = room.dimensionsLength * scale

            let effectivePanX = (cameraState?.panOffsetX ?? 0) + activePanTranslation.width
            let effectivePanY = (cameraState?.panOffsetY ?? 0) + activePanTranslation.height
            let effectiveZoom = (cameraState?.zoomScale ?? 1.0) * currentMagnification

            ZStack {
                // Background interactive canvas surface for viewport panning and double-tap reset
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                activePanTranslation = value.translation
                            }
                            .onEnded { value in
                                cameraState?.applyPan(
                                    translationX: value.translation.width,
                                    translationY: value.translation.height
                                )
                                activePanTranslation = .zero
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            cameraState?.resetCamera()
                        }
                    }

                canvasContent(roomW: roomW, roomL: roomL, center: center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(effectiveZoom)
            .offset(x: effectivePanX, y: effectivePanY)
            .rotation3DEffect(
                .degrees(cameraState?.pitchAngleDegrees ?? 0),
                axis: (x: 1, y: 0, z: 0)
            )
            .rotation3DEffect(
                .degrees(cameraState?.yawAngleDegrees ?? 0),
                axis: (x: 0, y: 0, z: 1)
            )
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: cameraState?.preset)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        currentMagnification = value
                    }
                    .onEnded { value in
                        cameraState?.applyZoom(factor: value)
                        currentMagnification = 1.0
                    }
            )
        }
    }

    @ViewBuilder
    private func canvasContent(roomW: Double, roomL: Double, center: CGPoint) -> some View {
        ZStack {
            // Room floor boundary
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.4), lineWidth: 3)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.85))
                )
                .frame(width: roomW, height: roomL)
                .position(center)

            // Floor grid lines
            FloorGridView(width: roomW, height: roomL, step: scale)
                .position(center)

            // Stage 3: Light Fixtures and illumination pools
            if currentStage == .illumination || currentStage == .harmony {
                ForEach(room.workingLayout?.lightFixtures ?? []) { fixture in
                    lightFixtureView(fixture, center: center)
                }
            }

            // Stage 4: Harmony Reveal Modes
            if currentStage == .harmony {
                switch revealMode {
                case .splitSlider:
                    // Left is Baseline (0.0), Right is New Design (1.0).
                    // splitLineX moves from right edge (at 0.0, showing 100% baseline) to left edge (at 1.0, showing 100% working layout)
                    let splitLineX = (center.x - roomW / 2.0) + (roomW * (1.0 - beforeAfterSplit))

                    // Baseline layout items (shown on the left side of splitLineX)
                    ForEach(room.baselineLayout?.furnitures.filter { !$0.isArchived } ?? []) { item in
                        let posX = center.x + (item.positionX * scale)
                        if posX <= splitLineX {
                            furnitureItemView(item, center: center, isGhosted: true)
                        }
                    }

                    // Working layout items (shown on the right side of splitLineX)
                    ForEach(room.workingLayout?.furnitures.filter { !$0.isArchived } ?? []) { item in
                        let posX = center.x + (item.positionX * scale)
                        if posX > splitLineX {
                            furnitureItemView(item, center: center, isGhosted: false)
                        }
                    }

                    // Split curtain visual line
                    Path { path in
                        path.move(to: CGPoint(x: splitLineX, y: center.y - (roomL / 2.0)))
                        path.addLine(to: CGPoint(x: splitLineX, y: center.y + (roomL / 2.0)))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 3, dash: [6, 4]))
                    .foregroundStyle(.indigo)

                case .overlayDiff:
                    // Render all baseline items ghosted, and all working items active on top
                    ForEach(room.baselineLayout?.furnitures.filter { !$0.isArchived } ?? []) { item in
                        furnitureItemView(item, center: center, isGhosted: true)
                    }
                    ForEach(room.workingLayout?.furnitures.filter { !$0.isArchived } ?? []) { item in
                        furnitureItemView(item, center: center, isGhosted: false)
                    }

                case .sideBySide:
                    let midX = center.x
                    ForEach(room.baselineLayout?.furnitures.filter { !$0.isArchived } ?? []) { item in
                        let posX = center.x + (item.positionX * scale)
                        if posX <= midX {
                            furnitureItemView(item, center: center, isGhosted: true)
                        }
                    }
                    ForEach(room.workingLayout?.furnitures.filter { !$0.isArchived } ?? []) { item in
                        let posX = center.x + (item.positionX * scale)
                        if posX > midX {
                            furnitureItemView(item, center: center, isGhosted: false)
                        }
                    }
                    Path { path in
                        path.move(to: CGPoint(x: midX, y: center.y - (roomL / 2.0)))
                        path.addLine(to: CGPoint(x: midX, y: center.y + (roomL / 2.0)))
                    }
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 2)
                }
            } else {
                // Working layout items (normal display)
                ForEach(room.workingLayout?.furnitures.filter { !$0.isArchived } ?? []) { item in
                    furnitureItemView(item, center: center, isGhosted: false)
                }
            }
        }
    }

    @ViewBuilder
    private func lightFixtureView(_ fixture: LightFixture, center: CGPoint) -> some View {
        let isSelected = selectedLightFixtureID == fixture.id
        let posX = center.x + (fixture.positionX * scale)
        let posZ = center.y + (fixture.positionZ * scale)
        let poolRadius = fixture.isOn ? (fixture.lumens / 12.0) : 0

        ZStack {
            if fixture.isOn {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.yellow.opacity(0.35), Color.clear],
                            center: .center,
                            startRadius: 4,
                            endRadius: poolRadius
                        )
                    )
                    .frame(width: poolRadius * 2, height: poolRadius * 2)
            }

            if isSelected {
                Circle()
                    .strokeBorder(Color.white, lineWidth: 2.5)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.orange.opacity(0.35)))
            }

            Circle()
                .fill(fixture.isOn ? Color.yellow : Color.gray)
                .frame(width: 22, height: 22)
                .overlay(
                    Image(systemName: fixture.layer.icon)
                        .font(.system(size: 11).bold())
                        .foregroundStyle(fixture.isOn ? .black : .white)
                )
        }
        .position(x: posX, y: posZ)
        .contentShape(Circle())
        .onTapGesture {
            if currentStage == .illumination {
                selectedLightFixtureID = fixture.id
                selectedFurnitureID = nil
            }
        }
        .gesture(
            currentStage == .illumination ? DragGesture()
                .onChanged { value in
                    selectedLightFixtureID = fixture.id
                    selectedFurnitureID = nil

                    let halfW = room.dimensionsWidth / 2.0
                    let halfL = room.dimensionsLength / 2.0

                    let startPos = dragInitialPositions[fixture.id] ?? (fixture.positionX, fixture.positionZ)
                    if dragInitialPositions[fixture.id] == nil {
                        dragInitialPositions[fixture.id] = startPos
                    }

                    let targetX = startPos.x + (value.translation.width / scale)
                    let targetZ = startPos.z + (value.translation.height / scale)

                    var fixtures = room.workingLayout?.lightFixtures ?? []
                    if let idx = fixtures.firstIndex(where: { $0.id == fixture.id }) {
                        fixtures[idx].positionX = max(-halfW, min(halfW, targetX))
                        fixtures[idx].positionZ = max(-halfL, min(halfL, targetZ))
                        room.workingLayout?.lightFixtures = fixtures
                    }
                }
                .onEnded { _ in
                    dragInitialPositions.removeValue(forKey: fixture.id)
                } : nil
        )
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
                    isGhosted ? Color.gray.opacity(0.35) :
                    (isSelected ? Color.indigo : Color.indigo.opacity(0.85))
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
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(4)
        }
        .frame(width: itemWidth, height: itemLength)
        .contentShape(Rectangle())
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
                    let startPos = dragInitialPositions[item.id] ?? (item.positionX, item.positionZ)
                    if dragInitialPositions[item.id] == nil {
                        dragInitialPositions[item.id] = startPos
                    }

                    let angle = abs(item.rotationYaw)
                    let cosA = abs(cos(angle))
                    let sinA = abs(sin(angle))
                    let effectiveW = item.width * cosA + item.length * sinA
                    let effectiveL = item.width * sinA + item.length * cosA

                    let halfW = max(0, (room.dimensionsWidth - effectiveW) / 2.0)
                    let halfL = max(0, (room.dimensionsLength - effectiveL) / 2.0)

                    let targetX = startPos.x + (value.translation.width / scale)
                    let targetZ = startPos.z + (value.translation.height / scale)

                    item.positionX = max(-halfW, min(halfW, targetX))
                    item.positionZ = max(-halfL, min(halfL, targetZ))
                }
                .onEnded { _ in
                    let startPos = dragInitialPositions[item.id] ?? (item.positionX, item.positionZ)
                    dragInitialPositions.removeValue(forKey: item.id)

                    onFurnitureMoved(
                        FurnitureMoveEvent(
                            furnitureName: item.name,
                            category: item.category,
                            oldPosition: startPos,
                            newPosition: (x: item.positionX, z: item.positionZ),
                            rotationYaw: item.rotationYaw
                        )
                    )
                } : nil
        )
    }
}
