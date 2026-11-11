import SwiftUI
import RealityKit
import AudioToolbox
import UIKit
import Combine

/// Interactive 3D RealityKit Viewport for iPad landscape, wrapping an authentic `ARView(cameraMode: .nonAR)`.
/// Mirrors Resign's proven architectural pattern with a real `PerspectiveCamera`, native sub-pixel
/// screen projection via `arView.project(_:)`, and raycasted floor drag translation via `arView.ray(through:)`.
public struct Studio3DViewport: UIViewRepresentable {
    public let room: Room
    @Binding public var selectedFurnitureID: UUID?
    @Binding public var selectedFurnitureScreenPosition: CGPoint?
    public var viewportSize: CGSize = .zero
    public var ghostFurnitureID: UUID? = nil
    public var ghostFloorPosition: SIMD3<Float>? = nil
    public var currentStage: StageType = .rearrangement
    public var beforeAfterSplit: Double = 1.0
    public var revealMode: HarmonyRevealMode = .splitSlider
    public typealias FloorRaycaster = (CGPoint) -> SIMD3<Float>?
    public typealias ViewportSnapper = (ViewportPreset) -> Void
    public var onFurnitureMoved: ((FurnitureMoveEvent) -> Void)? = nil
    public var onFloorRaycasterResolved: ((@escaping FloorRaycaster) -> Void)? = nil
    public var onSnapToViewportResolved: ((@escaping ViewportSnapper) -> Void)? = nil
    public var onTapBackground: (() -> Void)? = nil

    public init(
        room: Room,
        selectedFurnitureID: Binding<UUID?>,
        selectedFurnitureScreenPosition: Binding<CGPoint?>,
        viewportSize: CGSize = .zero,
        ghostFurnitureID: UUID? = nil,
        ghostFloorPosition: SIMD3<Float>? = nil,
        currentStage: StageType = .rearrangement,
        beforeAfterSplit: Double = 1.0,
        revealMode: HarmonyRevealMode = .splitSlider,
        onFurnitureMoved: ((FurnitureMoveEvent) -> Void)? = nil,
        onFloorRaycasterResolved: ((@escaping FloorRaycaster) -> Void)? = nil,
        onSnapToViewportResolved: ((@escaping ViewportSnapper) -> Void)? = nil,
        onTapBackground: (() -> Void)? = nil
    ) {
        self.room = room
        self._selectedFurnitureID = selectedFurnitureID
        self._selectedFurnitureScreenPosition = selectedFurnitureScreenPosition
        self.viewportSize = viewportSize
        self.ghostFurnitureID = ghostFurnitureID
        self.ghostFloorPosition = ghostFloorPosition
        self.currentStage = currentStage
        self.beforeAfterSplit = beforeAfterSplit
        self.revealMode = revealMode
        self.onFurnitureMoved = onFurnitureMoved
        self.onFloorRaycasterResolved = onFloorRaycasterResolved
        self.onSnapToViewportResolved = onSnapToViewportResolved
        self.onTapBackground = onTapBackground
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(
            room: room,
            selectedFurnitureID: selectedFurnitureID,
            onSelectFurniture: { id in
                selectedFurnitureID = id
            },
            onProjectSelectedFurniture: { point in
                selectedFurnitureScreenPosition = point
            },
            onFurnitureMoved: onFurnitureMoved,
            onTapBackground: onTapBackground
        )
    }

    public func makeUIView(context: Context) -> ARView {
        let view = RoomPreviewARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(UIColor.systemGroupedBackground)
        view.renderOptions.insert([.disableMotionBlur, .disableDepthOfField])

        context.coordinator.install(in: view)
        view.onViewportChange = { [weak coordinator = context.coordinator] _ in
            coordinator?.updateSelectedProjection()
        }

        onFloorRaycasterResolved? { [weak coordinator = context.coordinator, weak view] screenPoint in
            guard let coordinator, let view else { return nil }
            return coordinator.projectToFloor(from: screenPoint, in: view)
        }

        onSnapToViewportResolved? { [weak coordinator = context.coordinator] preset in
            coordinator?.snapToViewport(preset)
        }

        return view
    }

    public func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.selectedFurnitureID = selectedFurnitureID
        context.coordinator.ghostFurnitureID = ghostFurnitureID
        context.coordinator.ghostFloorPosition = ghostFloorPosition
        context.coordinator.currentStage = currentStage
        context.coordinator.beforeAfterSplit = beforeAfterSplit
        context.coordinator.revealMode = revealMode
        context.coordinator.updateFurnitureEntities(from: room)
        context.coordinator.updateSelectionHalos()
        context.coordinator.updateSelectedProjection()
        context.coordinator.onTapBackground = onTapBackground

        onFloorRaycasterResolved? { [weak coordinator = context.coordinator, weak arView] screenPoint in
            guard let coordinator, let arView else { return nil }
            return coordinator.projectToFloor(from: screenPoint, in: arView)
        }

        onSnapToViewportResolved? { [weak coordinator = context.coordinator] preset in
            coordinator?.snapToViewport(preset)
        }
    }

    public static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        coordinator.animationTask?.cancel()
        coordinator.updateSubscription?.cancel()
        view.scene.anchors.removeAll()
    }

    // MARK: - Coordinator & Gesture Controller

    @MainActor
    public final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var arView: ARView?
        var room: Room
        var selectedFurnitureID: UUID?
        var ghostFurnitureID: UUID?
        var ghostFloorPosition: SIMD3<Float>?
        var currentStage: StageType = .rearrangement
        var beforeAfterSplit: Double = 1.0
        var revealMode: HarmonyRevealMode = .splitSlider
        var onSelectFurniture: ((UUID?) -> Void)?
        var onProjectSelectedFurniture: ((CGPoint?) -> Void)?
        var onFurnitureMoved: ((FurnitureMoveEvent) -> Void)?
        var onTapBackground: (() -> Void)?

        let root = Entity()
        let camera = PerspectiveCamera()
        let sun = DirectionalLight()
        let fill = DirectionalLight()

        var updateSubscription: (any Cancellable)?
        var animationTask: Task<Void, Never>? = nil

        // Camera Orbit & Distance
        var yaw: Float = 0.0
        var pitch: Float = 0.62
        var distance: Float = 10.0
        var cameraTarget: SIMD3<Float> = [0, 0.6, 0]

        private var pinchStartDistance: Float = 10.0

        private enum DragMode {
            case none
            case translating(furnitureID: UUID, offset: SIMD2<Float>, initialPos: SIMD3<Float>)
            case orbiting(startYaw: Float, startPitch: Float)
        }
        private var dragMode: DragMode = .none

        init(
            room: Room,
            selectedFurnitureID: UUID?,
            onSelectFurniture: ((UUID?) -> Void)?,
            onProjectSelectedFurniture: ((CGPoint?) -> Void)?,
            onFurnitureMoved: ((FurnitureMoveEvent) -> Void)?,
            onTapBackground: (() -> Void)? = nil
        ) {
            self.room = room
            self.selectedFurnitureID = selectedFurnitureID
            self.onSelectFurniture = onSelectFurniture
            self.onProjectSelectedFurniture = onProjectSelectedFurniture
            self.onFurnitureMoved = onFurnitureMoved
            self.onTapBackground = onTapBackground
            super.init()

            let span = Float(max(room.dimensionsWidth, room.dimensionsLength, 3.0))
            distance = min(20, max(5, span * 1.5))
            cameraTarget = SIMD3<Float>(0, Float(room.dimensionsHeight) * 0.35, 0)

            setupScene()
        }

        private func setupScene() {
            root.name = "DollhouseRoot"

            // Non-AR lighting configuration
            root.components.set(EnvironmentLightingConfigurationComponent(environmentLightingWeight: 0))
            root.components.set(ImageBasedLightComponent(source: .none))
            root.components.set(ImageBasedLightReceiverComponent(imageBasedLight: root))

            // Realistic Perspective Camera
            camera.name = "OrbitCamera"
            camera.camera.fieldOfViewInDegrees = 40
            camera.camera.near = 0.1
            camera.camera.far = 60
            root.addChild(camera)

            // Directional Sunlight pouring in fixed projection through the window opening
            let halfL = Float(room.dimensionsLength) / 2.0
            let windowCenterY: Float = 0.85 + (1.30 / 2.0) // 1.50m
            let windowZ: Float = -halfL

            sun.name = "SunLight"
            sun.light.intensity = 2800
            sun.light.color = .init(red: 1.0, green: 0.96, blue: 0.90, alpha: 1.0)
            sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 14.0, depthBias: 0.8)

            // Fixed position directly outside the window aperture, aimed across the room floor
            let sunPos = SIMD3<Float>(0.4, windowCenterY + 0.9, windowZ - 2.5)
            let sunTarget = SIMD3<Float>(-0.2, 0.0, windowZ + halfL * 0.9)
            sun.look(at: sunTarget, from: sunPos, relativeTo: root)
            root.addChild(sun)

            // Ambient Fill Light (soft bounce light without shadows)
            fill.name = "FillLight"
            fill.light.intensity = 1100
            fill.light.color = .init(red: 0.92, green: 0.95, blue: 1.0, alpha: 1.0)
            fill.look(at: .zero, from: [-2.0, 3.5, 2.5], relativeTo: root)
            root.addChild(fill)

            // Procedural Room Shell: Floor and 4 Cardinal Walls
            let shell = ProceduralRoomShellBuilder.buildShell(for: room, includeCeiling: false)
            root.addChild(shell)

            // Procedural Low-Poly Furniture Entities
            let furnitureGroup = Entity()
            furnitureGroup.name = "FurnitureGroup"
            let layout = room.workingLayout ?? room.baselineLayout
            if let layout {
                for item in layout.furnitures {
                    let entity = buildFurnitureEntity(for: item)
                    entity.isEnabled = !item.isArchived
                    furnitureGroup.addChild(entity)
                }
            }
            root.addChild(furnitureGroup)

            updateCamera()
            updateWallCutaways()
        }

        func install(in view: ARView) {
            self.arView = view
            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(root)
            view.scene.addAnchor(anchor)

            setupGestures(in: view)

            updateSubscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
                self?.updateSelectedProjection()
            }
        }

        // MARK: - Camera & Dynamic Cutaways

        func updateCamera() {
            let cosPitch = cos(pitch)
            let sinPitch = sin(pitch)
            let offset = SIMD3<Float>(
                distance * cosPitch * sin(yaw),
                distance * sinPitch,
                distance * cosPitch * cos(yaw)
            )
            camera.look(at: cameraTarget, from: cameraTarget + offset, relativeTo: nil)
        }

        func updateWallCutaways() {
            guard let shell = root.children.first(where: { $0.name == "RoomShell" }) else { return }

            let yawQuat = simd_quatf(angle: -yaw, axis: SIMD3<Float>(0, 1, 0))
            let pitchQuat = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
            let orientation = pitchQuat * yawQuat

            let walls: [(name: String, normal: SIMD3<Float>)] = [
                ("FrontWallGroup", WallCutawayEvaluator.frontNormal),
                ("BackWallGroup", WallCutawayEvaluator.backNormal),
                ("LeftWallGroup", WallCutawayEvaluator.leftNormal),
                ("RightWallGroup", WallCutawayEvaluator.rightNormal)
            ]

            for wall in walls {
                if let entity = shell.children.first(where: { $0.name == wall.name }) {
                    let isHidden = WallCutawayEvaluator.isWallHidden(
                        wallNormal: wall.normal,
                        orientation: orientation,
                        pitch: pitch
                    )
                    if #available(iOS 18.0, *) {
                        if isHidden {
                            entity.components.set(OpacityComponent(opacity: 0.0))
                        } else {
                            entity.components.remove(OpacityComponent.self)
                        }
                    } else {
                        entity.isEnabled = !isHidden
                    }
                }
            }
        }

        // MARK: - Viewport Snapping & Cutaways

        /// Snaps the orbit camera to an architectural viewport preset, smoothly interpolating by default.
        public func snapToViewport(_ preset: ViewportPreset, animated: Bool = true) {
            let startYaw = self.yaw
            let startPitch = self.pitch
            let targetYaw = preset.targetYaw
            let targetPitch = preset.targetPitch

            if !animated {
                animationTask?.cancel()
                self.yaw = targetYaw
                self.pitch = targetPitch
                updateCamera()
                updateWallCutaways()
                updateSelectedProjection()
                return
            }

            animationTask?.cancel()
            animationTask = Task { @MainActor [weak self] in
                guard let self else { return }
                let duration: Double = 0.35
                let startTime = CACurrentMediaTime()

                var deltaYaw = (targetYaw - startYaw).truncatingRemainder(dividingBy: .pi * 2)
                if deltaYaw > .pi { deltaYaw -= .pi * 2 }
                if deltaYaw < -.pi { deltaYaw += .pi * 2 }

                while !Task.isCancelled {
                    let elapsed = CACurrentMediaTime() - startTime
                    let progress = min(1.0, elapsed / duration)
                    let t = Float(progress < 0.5 ? 2 * progress * progress : 1 - pow(-2 * progress + 2, 2) / 2)

                    self.yaw = startYaw + deltaYaw * t
                    self.pitch = startPitch + (targetPitch - startPitch) * t
                    self.updateCamera()
                    self.updateWallCutaways()
                    self.updateSelectedProjection()

                    if progress >= 1.0 { break }
                    try? await Task.sleep(nanoseconds: 16_000_000)
                }
            }
        }

        // MARK: - 3D to 2D Screen Projection (Native RealityKit Hardware Matrix)

        func updateSelectedProjection() {
            guard let arView = arView,
                  let id = selectedFurnitureID,
                  let container = arView.scene.findEntity(named: "Furniture_\(id.uuidString)") else {
                DispatchQueue.main.async { [weak self] in
                    self?.onProjectSelectedFurniture?(nil)
                }
                return
            }

            let bounds = container.visualBounds(relativeTo: nil)
            let yPos = bounds.max.y.isFinite ? bounds.max.y + 0.08 : container.position.y + 0.8
            let pos = container.position(relativeTo: nil)
            let topCenter = SIMD3<Float>(pos.x, yPos, pos.z)

            // Native hardware camera projection: perfectly locks 2D Sims HUD above the 3D centroid
            let projected = arView.project(topCenter)
            DispatchQueue.main.async { [weak self] in
                self?.onProjectSelectedFurniture?(projected)
            }
        }

        // MARK: - Screen Point to Floor Raycasting

        func projectToFloor(from screenPoint: CGPoint, in arView: ARView) -> SIMD3<Float>? {
            guard let ray = arView.ray(through: screenPoint) else { return nil }
            let floorY: Float = 0.0
            guard abs(ray.direction.y) > 1e-4 else {
                let projected = ray.origin + distance * ray.direction
                return SIMD3<Float>(projected.x, floorY, projected.z)
            }
            let t = (floorY - ray.origin.y) / ray.direction.y
            if t > 0 {
                return ray.origin + t * ray.direction
            } else {
                let projected = ray.origin + distance * ray.direction
                return SIMD3<Float>(projected.x, floorY, projected.z)
            }
        }

        // MARK: - Gesture Setup & Handling

        private func setupGestures(in arView: ARView) {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.delegate = self
            arView.addGestureRecognizer(tap)

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.delegate = self
            arView.addGestureRecognizer(pan)

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinch.delegate = self
            arView.addGestureRecognizer(pinch)
        }

        public func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView, gesture.state == .ended else { return }
            let point = gesture.location(in: arView)

            if let hitEntity = arView.entity(at: point) {
                var current: Entity? = hitEntity
                while let p = current, !p.name.hasPrefix("Furniture_") {
                    current = p.parent
                }
                if let container = current, container.name.hasPrefix("Furniture_") {
                    let uuidStr = String(container.name.dropFirst("Furniture_".count))
                    if let id = UUID(uuidString: uuidStr) {
                        selectedFurnitureID = id
                        onSelectFurniture?(id)
                        updateSelectionHalos()
                        updateSelectedProjection()
                        playTapFeedback()
                        return
                    }
                }
            }

            // Tapped empty space -> deselect
            selectedFurnitureID = nil
            onSelectFurniture?(nil)
            onTapBackground?()
            updateSelectionHalos()
            updateSelectedProjection()
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let arView = arView else { return }
            let point = gesture.location(in: arView)

            switch gesture.state {
            case .began:
                animationTask?.cancel()
                if let hitEntity = arView.entity(at: point) {
                    var current: Entity? = hitEntity
                    while let p = current, !p.name.hasPrefix("Furniture_") {
                        current = p.parent
                    }
                    if let container = current, container.name.hasPrefix("Furniture_") {
                        let uuidStr = String(container.name.dropFirst("Furniture_".count))
                        if let id = UUID(uuidString: uuidStr), id == selectedFurnitureID {
                            // Already selected -> enter floor translation mode
                            if let floorPos = projectToFloor(from: point, in: arView) {
                                let offset = SIMD2<Float>(container.position.x - floorPos.x, container.position.z - floorPos.z)
                                dragMode = .translating(furnitureID: id, offset: offset, initialPos: container.position)
                            } else {
                                dragMode = .translating(furnitureID: id, offset: .zero, initialPos: container.position)
                            }
                            updateSelectedProjection()
                            return
                        }
                    }
                }

                // Touched unselected furniture or background -> camera orbit mode
                dragMode = .orbiting(startYaw: yaw, startPitch: pitch)

            case .changed:
                switch dragMode {
                case .translating(let id, let offset, _):
                    guard let floorPos = projectToFloor(from: point, in: arView) else { return }
                    guard let container = arView.scene.findEntity(named: "Furniture_\(id.uuidString)") else { return }
                    let layout = room.workingLayout ?? room.baselineLayout
                    guard let item = layout?.furnitures.first(where: { $0.id == id }) else { return }

                    let candidatePos = SIMD3<Float>(floorPos.x + offset.x, 0.0, floorPos.z + offset.y)
                    let clamped = FurnitureTransformEngine.clampPosition(
                        position: candidatePos,
                        furnitureWidth: Float(item.width),
                        furnitureLength: Float(item.length),
                        rotationYaw: Float(item.rotationYaw),
                        roomWidth: Float(room.dimensionsWidth),
                        roomLength: Float(room.dimensionsLength)
                    )
                    container.position = clamped
                    updateSelectedProjection()

                case .orbiting(let startYaw, let startPitch):
                    let translation = gesture.translation(in: arView)
                    yaw = startYaw - Float(translation.x) * 0.007
                    let rawPitch = startPitch + Float(translation.y) * 0.007
                    pitch = min(1.55, max(0.12, rawPitch))
                    updateCamera()
                    updateWallCutaways()
                    updateSelectedProjection()

                case .none:
                    break
                }

            case .ended:
                switch dragMode {
                case .translating(let id, _, let initialPos):
                    guard let container = arView.scene.findEntity(named: "Furniture_\(id.uuidString)") else { break }
                    let layout = room.workingLayout ?? room.baselineLayout
                    guard let item = layout?.furnitures.first(where: { $0.id == id }) else { break }

                    let oldPos = (x: Double(initialPos.x), z: Double(initialPos.z))
                    item.positionX = Double(container.position.x)
                    item.positionZ = Double(container.position.z)
                    let newPos = (x: item.positionX, z: item.positionZ)

                    playTapFeedback()
                    onFurnitureMoved?(FurnitureMoveEvent(
                        furnitureName: item.name,
                        category: item.category,
                        oldPosition: oldPos,
                        newPosition: newPos,
                        rotationYaw: item.rotationYaw
                    ))

                default:
                    break
                }
                dragMode = .none

            case .cancelled:
                dragMode = .none

            default:
                break
            }
        }

        @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                pinchStartDistance = distance
            case .changed:
                let scale = Float(gesture.scale)
                if scale > 0.05 {
                    let maxDim = Float(max(room.dimensionsWidth, room.dimensionsLength, 3.0))
                    let newDist = pinchStartDistance / scale
                    distance = min(maxDim * 3.5, max(maxDim * 0.6, newDist))
                    updateCamera()
                    updateSelectedProjection()
                }
            default:
                break
            }
        }

        // MARK: - Scene Entities & Halos Synchronization

        private func applyGhostAppearance(to entity: Entity, isGhost: Bool) {
            if #available(iOS 18.0, *) {
                if isGhost {
                    entity.components.set(OpacityComponent(opacity: 0.55))
                } else {
                    entity.components.remove(OpacityComponent.self)
                }
            }
        }

        func updateFurnitureEntities(from room: Room) {
            self.room = room
            guard let group = root.children.first(where: { $0.name == "FurnitureGroup" }) else { return }
            let layout = room.workingLayout ?? room.baselineLayout
            guard let layout else { return }

            let baselineItems = room.baselineLayout?.furnitures ?? []

            // If not in harmony mode or not in overlayDiff, disable ghost group if present
            if let existingGhostGroup = root.children.first(where: { $0.name == "BaselineGhostGroup" }) {
                existingGhostGroup.isEnabled = (currentStage == .harmony && revealMode == .overlayDiff)
            }

            if currentStage == .harmony && revealMode == .splitSlider {
                let t = Float(max(0.0, min(1.0, beforeAfterSplit)))

                for (index, item) in layout.furnitures.enumerated() {
                    var entity = group.children.first(where: { $0.name == "Furniture_\(item.id.uuidString)" })
                    if entity == nil {
                        let newEntity = buildFurnitureEntity(for: item)
                        group.addChild(newEntity)
                        entity = newEntity
                    }
                    guard let entity else { continue }

                    let baselineItem: Furniture? = {
                        if index < baselineItems.count && baselineItems[index].name == item.name {
                            return baselineItems[index]
                        }
                        return baselineItems.first { $0.name == item.name && $0.category == item.category }
                    }()

                    applyGhostAppearance(to: entity, isGhost: false)

                    if let base = baselineItem {
                        let posX = Float(base.positionX) * (1.0 - t) + Float(item.positionX) * t
                        let posY = Float(base.positionY) * (1.0 - t) + Float(item.positionY) * t
                        let posZ = Float(base.positionZ) * (1.0 - t) + Float(item.positionZ) * t
                        entity.position = SIMD3<Float>(posX, posY, posZ)

                        let yaw = Float(base.rotationYaw) * (1.0 - t) + Float(item.rotationYaw) * t
                        entity.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))

                        if item.isArchived {
                            let scale = max(0.001, 1.0 - t)
                            entity.scale = SIMD3<Float>(scale, scale, scale)
                            entity.isEnabled = t < 0.95
                        } else {
                            entity.scale = SIMD3<Float>(1, 1, 1)
                            entity.isEnabled = true
                        }
                    } else {
                        entity.position = SIMD3<Float>(Float(item.positionX), Float(item.positionY), Float(item.positionZ))
                        entity.orientation = simd_quatf(angle: Float(item.rotationYaw), axis: SIMD3<Float>(0, 1, 0))
                        entity.scale = SIMD3<Float>(1, 1, 1)
                        entity.isEnabled = !item.isArchived
                    }
                }
            } else if currentStage == .harmony && revealMode == .overlayDiff {
                // Working layout active
                for item in layout.furnitures {
                    var entity = group.children.first(where: { $0.name == "Furniture_\(item.id.uuidString)" })
                    if entity == nil {
                        let newEntity = buildFurnitureEntity(for: item)
                        group.addChild(newEntity)
                        entity = newEntity
                    }
                    guard let entity else { continue }
                    applyGhostAppearance(to: entity, isGhost: false)
                    entity.position = SIMD3<Float>(Float(item.positionX), Float(item.positionY), Float(item.positionZ))
                    entity.orientation = simd_quatf(angle: Float(item.rotationYaw), axis: SIMD3<Float>(0, 1, 0))
                    entity.scale = SIMD3<Float>(1, 1, 1)
                    entity.isEnabled = !item.isArchived
                }

                // Baseline ghost group
                var ghostGroup = root.children.first(where: { $0.name == "BaselineGhostGroup" })
                if ghostGroup == nil {
                    let newGroup = Entity()
                    newGroup.name = "BaselineGhostGroup"
                    root.addChild(newGroup)
                    ghostGroup = newGroup
                }
                if let ghostGroup {
                    ghostGroup.isEnabled = true
                    for baseItem in baselineItems {
                        var ghostEntity = ghostGroup.children.first(where: { $0.name == "Ghost_\(baseItem.id.uuidString)" })
                        if ghostEntity == nil {
                            let newEntity = buildFurnitureEntity(for: baseItem)
                            newEntity.name = "Ghost_\(baseItem.id.uuidString)"
                            ghostGroup.addChild(newEntity)
                            ghostEntity = newEntity
                        }
                        if let ghostEntity {
                            ghostEntity.position = SIMD3<Float>(Float(baseItem.positionX), Float(baseItem.positionY), Float(baseItem.positionZ))
                            ghostEntity.orientation = simd_quatf(angle: Float(baseItem.rotationYaw), axis: SIMD3<Float>(0, 1, 0))
                            ghostEntity.isEnabled = true
                            applyGhostAppearance(to: ghostEntity, isGhost: true)
                        }
                    }
                }
            } else {
                // Standard mode (Audit, Rearrangement, Illumination)
                for item in layout.furnitures {
                    var entity = group.children.first(where: { $0.name == "Furniture_\(item.id.uuidString)" })
                    if entity == nil {
                        let newEntity = buildFurnitureEntity(for: item)
                        newEntity.isEnabled = !item.isArchived
                        group.addChild(newEntity)
                        entity = newEntity
                    }
                    guard let entity else { continue }

                    entity.scale = SIMD3<Float>(1, 1, 1)
                    let isGhost = (item.id == ghostFurnitureID && ghostFloorPosition != nil)

                    if isGhost, let pos = ghostFloorPosition {
                        entity.isEnabled = true
                        entity.position = pos
                        entity.orientation = simd_quatf(angle: Float(item.rotationYaw), axis: SIMD3<Float>(0, 1, 0))
                        applyGhostAppearance(to: entity, isGhost: true)
                    } else {
                        applyGhostAppearance(to: entity, isGhost: false)
                        entity.isEnabled = !item.isArchived

                        // Do not override translation if currently actively dragging
                        if case .translating(let id, _, _) = dragMode, id == item.id {
                            // Keep dragged position
                        } else {
                            entity.position = SIMD3<Float>(Float(item.positionX), Float(item.positionY), Float(item.positionZ))
                            entity.orientation = simd_quatf(angle: Float(item.rotationYaw), axis: SIMD3<Float>(0, 1, 0))
                        }
                    }
                }
            }
        }

        func updateSelectionHalos() {
            guard let group = root.children.first(where: { $0.name == "FurnitureGroup" }) else { return }
            for child in group.children {
                if child.name.starts(with: "Furniture_") {
                    let idString = String(child.name.dropFirst("Furniture_".count))
                    let isSelected = (idString == selectedFurnitureID?.uuidString)
                    let isGhost = (idString == ghostFurnitureID?.uuidString && ghostFloorPosition != nil)
                    if let halo = child.children.first(where: { $0.name == "SelectionHalo" }) {
                        halo.isEnabled = isSelected || isGhost
                    }
                }
            }
        }

        private func playTapFeedback() {
            AudioServicesPlaySystemSound(1104)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        // MARK: - Procedural Geometry Assembly

        private func buildRoomShell(for room: Room) -> Entity {
            ProceduralRoomShellBuilder.buildShell(for: room, includeCeiling: false)
        }

        private func buildFurnitureEntity(for item: Furniture) -> Entity {
            let container = Entity()
            container.name = "Furniture_\(item.id.uuidString)"
            container.position = SIMD3<Float>(Float(item.positionX), Float(item.positionY), Float(item.positionZ))
            container.orientation = simd_quatf(angle: Float(item.rotationYaw), axis: SIMD3<Float>(0, 1, 0))

            let width = Float(item.width)
            let height = Float(item.height)
            let length = Float(item.length)

            // Detailed procedural model
            let model = ProceduralFurnitureBuilder.buildDetailedEntity(for: item)
            container.addChild(model)

            // Collision & Raycast target box
            let boxShape = ShapeResource.generateBox(size: SIMD3<Float>(width, height, length))
            let offset = Transform(translation: SIMD3<Float>(0, height / 2.0, 0))
            container.components.set(CollisionComponent(shapes: [boxShape.offsetBy(rotation: offset.rotation, translation: offset.translation)]))
            container.components.set(InputTargetComponent())

            // Selection footprint halo on floor
            let haloMesh = MeshResource.generateBox(
                size: SIMD3<Float>(width + 0.08, 0.004, length + 0.08),
                cornerRadius: 0.02
            )
            let haloMat = SimpleMaterial(
                color: UIColor.systemBlue.withAlphaComponent(0.45),
                roughness: 0.2,
                isMetallic: false
            )
            let halo = ModelEntity(mesh: haloMesh, materials: [haloMat])
            halo.name = "SelectionHalo"
            halo.position = SIMD3<Float>(0, 0.002, 0)
            halo.isEnabled = (item.id == selectedFurnitureID)
            container.addChild(halo)

            return container
        }
    }
}

/// Resizes the interactive viewport without replacing its scene or gesture coordinator.
private final class RoomPreviewARView: ARView {
    var onViewportChange: ((CGSize) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onViewportChange?(bounds.size)
    }
}
