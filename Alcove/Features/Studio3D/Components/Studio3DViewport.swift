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
    public var furnitureWarningSeverities: [UUID: SpatialWarningSeverity] = [:]
    public typealias FloorRaycaster = (CGPoint) -> SIMD3<Float>?
    public typealias ViewportSnapper = (ViewportPreset) -> Void
    public var onFurnitureMoved: ((FurnitureMoveEvent) -> Void)? = nil
    public var onFurnitureDragging: (() -> Void)? = nil
    public var onComputeWarningSeverities: (() -> [UUID: SpatialWarningSeverity])? = nil
    public var onFloorRaycasterResolved: ((@escaping FloorRaycaster) -> Void)? = nil
    public var onSnapToViewportResolved: ((@escaping ViewportSnapper) -> Void)? = nil
    public var onTapBackground: (() -> Void)? = nil
    public var onHeaderOverlap: ((Bool) -> Void)? = nil

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
        furnitureWarningSeverities: [UUID: SpatialWarningSeverity] = [:],
        onFurnitureMoved: ((FurnitureMoveEvent) -> Void)? = nil,
        onFurnitureDragging: (() -> Void)? = nil,
        onComputeWarningSeverities: (() -> [UUID: SpatialWarningSeverity])? = nil,
        onFloorRaycasterResolved: ((@escaping FloorRaycaster) -> Void)? = nil,
        onSnapToViewportResolved: ((@escaping ViewportSnapper) -> Void)? = nil,
        onTapBackground: (() -> Void)? = nil,
        onHeaderOverlap: ((Bool) -> Void)? = nil
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
        self.furnitureWarningSeverities = furnitureWarningSeverities
        self.onFurnitureMoved = onFurnitureMoved
        self.onFurnitureDragging = onFurnitureDragging
        self.onComputeWarningSeverities = onComputeWarningSeverities
        self.onFloorRaycasterResolved = onFloorRaycasterResolved
        self.onSnapToViewportResolved = onSnapToViewportResolved
        self.onTapBackground = onTapBackground
        self.onHeaderOverlap = onHeaderOverlap
    }

    public func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(
            room: room,
            selectedFurnitureID: selectedFurnitureID,
            furnitureWarningSeverities: furnitureWarningSeverities,
            onSelectFurniture: { id in
                selectedFurnitureID = id
            },
            onProjectSelectedFurniture: { point in
                selectedFurnitureScreenPosition = point
            },
            onFurnitureMoved: onFurnitureMoved,
            onFurnitureDragging: onFurnitureDragging,
            onComputeWarningSeverities: onComputeWarningSeverities,
            onTapBackground: onTapBackground,
            onHeaderOverlap: onHeaderOverlap
        )
        coordinator.currentStage = currentStage
        return coordinator
    }

    public func makeUIView(context: Context) -> ARView {
        let view = RoomPreviewARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.isOpaque = false
        view.backgroundColor = .clear
        view.environment.background = .color(.clear)
        let daylight = IlluminationSimulationEngine().calculateDaylight(hourOfDay: 12)
        view.environment.lighting.intensityExponent = -5 + Float(daylight.intensityLux / 10000) * 2
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
        let previousSelection = context.coordinator.selectedFurnitureID
        context.coordinator.viewportSize = viewportSize
        context.coordinator.selectedFurnitureID = selectedFurnitureID
        context.coordinator.ghostFurnitureID = ghostFurnitureID
        context.coordinator.ghostFloorPosition = ghostFloorPosition
        context.coordinator.currentStage = currentStage
        context.coordinator.beforeAfterSplit = beforeAfterSplit
        context.coordinator.revealMode = revealMode
        context.coordinator.furnitureWarningSeverities = furnitureWarningSeverities
        context.coordinator.onFurnitureDragging = onFurnitureDragging
        context.coordinator.onComputeWarningSeverities = onComputeWarningSeverities
        context.coordinator.onHeaderOverlap = onHeaderOverlap
        if !context.coordinator.isTranslatingFurniture {
            context.coordinator.updateRoomLighting()
            context.coordinator.updateFurnitureEntities(from: room)
        }
        context.coordinator.updateSelectionHalos()
        if selectedFurnitureID != previousSelection {
            context.coordinator.updateSelectedProjection()
        }
        context.coordinator.onTapBackground = onTapBackground
        if let selectedFurnitureID, selectedFurnitureID != previousSelection {
            context.coordinator.focusMascot(onFurnitureID: selectedFurnitureID)
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
        var viewportSize: CGSize = .zero
        var selectedFurnitureID: UUID?
        var ghostFurnitureID: UUID?
        var ghostFloorPosition: SIMD3<Float>?
        var currentStage: StageType = .rearrangement
        var beforeAfterSplit: Double = 1.0
        var revealMode: HarmonyRevealMode = .splitSlider
        var furnitureWarningSeverities: [UUID: SpatialWarningSeverity] = [:]
        var onSelectFurniture: ((UUID?) -> Void)?
        var onProjectSelectedFurniture: ((CGPoint?) -> Void)?
        var onFurnitureMoved: ((FurnitureMoveEvent) -> Void)?
        var onFurnitureDragging: (() -> Void)?
        var onComputeWarningSeverities: (() -> [UUID: SpatialWarningSeverity])?
        var onTapBackground: (() -> Void)?
        var onHeaderOverlap: ((Bool) -> Void)?
        private var headerOverlap: Bool?

        private let blueHaloMaterial = SimpleMaterial(
            color: UIColor.systemBlue.withAlphaComponent(0.45),
            roughness: 0.2,
            isMetallic: false
        )
        private let redHaloMaterial = SimpleMaterial(
            color: UIColor.systemRed.withAlphaComponent(0.68),
            roughness: 0.25,
            isMetallic: false
        )
        private let yellowHaloMaterial = SimpleMaterial(
            color: UIColor.systemYellow.withAlphaComponent(0.72),
            roughness: 0.25,
            isMetallic: false
        )

        let root = Entity()
        let camera = PerspectiveCamera()
        let sun = DirectionalLight()
        private var lightingDefinitions: [LightFixture] = []
        private var fixtureLights: [(light: LightingFixtureLight, model: LightingFixtureModel)] = []

        var updateSubscription: (any Cancellable)?
        private var entitySignatures: [UUID: String] = [:]
        let cameraController: StudioOrbitCameraController
        var animationTask: Task<Void, Never>? { cameraController.animationTask }
        var yaw: Float {
            get { cameraController.yaw }
            set { cameraController.yaw = newValue }
        }
        var pitch: Float {
            get { cameraController.pitch }
            set { cameraController.pitch = newValue }
        }
        var distance: Float {
            get { cameraController.distance }
            set { cameraController.distance = newValue }
        }
        var cameraTarget: SIMD3<Float> {
            get { cameraController.target }
            set { cameraController.target = newValue }
        }
        let mascotController = MascotRoamController()


        private var pinchStartDistance: Float = 10.0

        private enum DragMode {
            case none
            case translating(furnitureID: UUID, offset: SIMD2<Float>, initialPos: SIMD3<Float>, useScreenSpace: Bool)
            case orbiting(startYaw: Float, startPitch: Float)
        }
        private var dragMode: DragMode = .none

        init(
            room: Room,
            selectedFurnitureID: UUID?,
            furnitureWarningSeverities: [UUID: SpatialWarningSeverity] = [:],
            onSelectFurniture: ((UUID?) -> Void)?,
            onProjectSelectedFurniture: ((CGPoint?) -> Void)?,
            onFurnitureMoved: ((FurnitureMoveEvent) -> Void)?,
            onFurnitureDragging: (() -> Void)? = nil,
            onComputeWarningSeverities: (() -> [UUID: SpatialWarningSeverity])? = nil,
            onTapBackground: (() -> Void)? = nil,
            onHeaderOverlap: ((Bool) -> Void)? = nil
        ) {
            self.room = room
            self.selectedFurnitureID = selectedFurnitureID
            self.furnitureWarningSeverities = furnitureWarningSeverities
            self.onSelectFurniture = onSelectFurniture
            self.onProjectSelectedFurniture = onProjectSelectedFurniture
            self.onFurnitureMoved = onFurnitureMoved
            self.onFurnitureDragging = onFurnitureDragging
            self.onComputeWarningSeverities = onComputeWarningSeverities
            self.onTapBackground = onTapBackground
            self.onHeaderOverlap = onHeaderOverlap
            cameraController = StudioOrbitCameraController(width: room.dimensionsWidth, length: room.dimensionsLength,
                                                           height: room.dimensionsHeight)
            super.init()

            setupScene()
        }

        private func setupScene() {
            root.name = "DollhouseRoot"

            // Realistic Perspective Camera
            camera.name = "OrbitCamera"
            cameraController.configure(camera)
            root.addChild(camera)

            let geometry = LightingRoomGeometry(width: room.dimensionsWidth, length: room.dimensionsLength,
                                                height: room.dimensionsHeight)
            sun.name = "SunLight"
            StudioDaylightRig.configure(sun, geometry: geometry)
            root.addChild(sun)
            root.addChild(StudioDaylightRig.roofOccluder(geometry: geometry))
            updateRoomLighting()

            // Procedural Room Shell: Floor and 4 Cardinal Walls
            let shell = ProceduralRoomShellBuilder.buildShell(for: room, includeCeiling: false)
            root.addChild(shell)
            RoomNorthMarker.installIfEnabled(in: root, snapshot: LightingRoomSnapshot(room: room))

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

            // 3D Roaming Otter Mascot
            root.addChild(mascotController.rootEntity)
            mascotController.configureInitialPosition(
                roomSize: roomSizeVector(),
                obstacles: currentObstacles()
            )

            updateCamera()
            updateWallCutaways()
        }

        /// Stage previews use the same default noon sun and saved fixture optics as Lighting.
        func updateRoomLighting() {
            let snapshot = LightingRoomSnapshot(room: room)
            let settings = LightingSimulationSettings()
            let daylight = IlluminationSimulationEngine().calculateDaylight(hourOfDay: settings.hourOfDay)
            StudioDaylightRig.update(sun, in: root, geometry: snapshot.geometry,
                                     orientation: snapshot.compassOrientation, daylight: daylight, enabled: true)
            guard lightingDefinitions != snapshot.fixtures else { return }
            for fixture in fixtureLights {
                fixture.light.entity.removeFromParent()
                fixture.model.root.removeFromParent()
            }
            let activeIDs = settings.renderedFixtureIDs(in: snapshot.fixtures,
                maximumCount: StudioLightBudget.maximumFixtures(sunlightActive: sun.isEnabled))
            fixtureLights = snapshot.fixtures.map { fixture in
                let model = LightingFixtureModel(fixture: fixture, room: snapshot)
                let light = LightingFixtureLight(optics: model.optics)
                light.entity.name = "LightingFixture-\(fixture.id)"
                light.position(at: model.emitterPosition, direction: model.emissionDirection)
                let enabled = activeIDs.contains(fixture.id)
                light.apply(output: settings.output(for: fixture), kelvin: fixture.colorTemperatureKelvin, enabled: enabled)
                model.applyAppearance(output: settings.output(for: fixture),
                                      kelvin: fixture.colorTemperatureKelvin)
                root.addChild(light.entity)
                root.addChild(model.root)
                return (light, model)
            }
            lightingDefinitions = snapshot.fixtures
        }

        func install(in view: ARView) {
            self.arView = view
            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(root)
            view.scene.addAnchor(anchor)

            setupGestures(in: view)

            updateSubscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
                self?.updateSelectedProjection()
                self?.updateMascot(dt: Float(event.deltaTime))
            }
        }

        private func roomSizeVector() -> SIMD2<Float> {
            SIMD2<Float>(Float(room.dimensionsWidth), Float(room.dimensionsLength))
        }

        private func currentObstacles() -> [MascotRoamingEngine.Obstacle] {
            let layout = room.workingLayout ?? room.baselineLayout
            return (layout?.furnitures ?? [])
                .filter { !$0.isArchived }
                .map { item in
                    MascotRoamingEngine.Obstacle(
                        id: item.id,
                        center: SIMD2<Float>(Float(item.positionX), Float(item.positionZ)),
                        size: SIMD2<Float>(Float(item.width), Float(item.length)),
                        yaw: Float(item.rotationYaw)
                    )
                }
        }

        func focusMascot(onFurnitureID id: UUID) {
            let obstacles = currentObstacles()
            guard let target = obstacles.first(where: { $0.id == id }) else { return }
            mascotController.focusOnFurniture(
                target,
                roomSize: roomSizeVector(),
                obstacles: obstacles
            )
        }

        func updateMascot(dt: Float) {
            mascotController.update(
                dt: dt,
                roomSize: roomSizeVector(),
                obstacles: currentObstacles()
            )
        }

        // MARK: - Camera & Dynamic Cutaways

        func updateCamera() {
            cameraController.apply(to: camera)
            updateHeaderOverlap()
            if currentStage == .harmony {
                updateFurnitureEntities(from: room)
            }
        }

        /// Runs independently of furniture selection, including Audit and Harmony.
        func updateHeaderOverlap() {
            guard !isTranslatingFurniture, let arView,
                  arView.bounds.width > 1, arView.bounds.height > 1 else { return }
            if cameraController.frameInitialViewport(arView.bounds.size) {
                cameraController.apply(to: camera)
            }
            let points = StudioViewportGeometry.roomCorners(width: room.dimensionsWidth,
                length: room.dimensionsLength, height: room.dimensionsHeight).compactMap {
                    arView.project(root.convert(position: $0, to: nil))
            }
            let overlap = StudioViewportGeometry.overlapsHeader(points)
            guard headerOverlap != overlap else { return }
            headerOverlap = overlap
            DispatchQueue.main.async { [weak self] in
                guard let self, self.headerOverlap == overlap else { return }
                self.onHeaderOverlap?(overlap)
            }
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
                    StudioDaylightRig.setCutaway(entity, hidden: isHidden)
                }
            }
        }

        // MARK: - Viewport Snapping & Cutaways

        /// Snaps the orbit camera to an architectural viewport preset, smoothly interpolating by default.
        public func snapToViewport(_ preset: ViewportPreset, animated: Bool = true) {
            cameraController.snap(to: preset, animated: animated) { [weak self] in
                self?.updateCamera()
                self?.updateWallCutaways()
                self?.updateSelectedProjection()
            }
        }

        // MARK: - 3D to 2D Screen Projection (Native RealityKit Hardware Matrix)

        private var lastProjectedPoint: CGPoint? = nil

        func updateSelectedProjection() {
            updateHeaderOverlap()
            guard let arView = arView,
                  let id = selectedFurnitureID,
                  let container = arView.scene.findEntity(named: "Furniture_\(id.uuidString)") else {
                guard lastProjectedPoint != nil else { return }
                lastProjectedPoint = nil
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
            let rawProjected = arView.project(topCenter)
            let projected: CGPoint? = rawProjected.flatMap { pt in
                (pt.x.isFinite && pt.y.isFinite) ? pt : nil
            }

            // Deduplicate sub-pixel updates so SceneEvents.Update does not trigger a 60Hz SwiftUI updateUIView loop
            switch (lastProjectedPoint, projected) {
            case (.none, .none):
                return
            case let (.some(prev), .some(next)) where hypot(next.x - prev.x, next.y - prev.y) < 0.75:
                return
            default:
                lastProjectedPoint = projected
                DispatchQueue.main.async { [weak self] in
                    self?.onProjectSelectedFurniture?(projected)
                }
            }
        }

        // MARK: - Screen Point to Floor Raycasting

        func projectToFloor(from screenPoint: CGPoint, in arView: ARView) -> SIMD3<Float>? {
            guard let ray = arView.ray(through: screenPoint) else { return nil }
            let floorY: Float = 0.0
            let maxT = max(distance * 3.0, cameraController.span * 2.5)
            // At very shallow/upward grazing angles (heavy zoom + low pitch), avoid exploding intersections.
            guard ray.direction.y < -0.05 else {
                let projected = ray.origin + min(distance, maxT) * ray.direction
                return SIMD3<Float>(projected.x, floorY, projected.z)
            }
            let t = min(maxT, (floorY - ray.origin.y) / ray.direction.y)
            if t > 0 {
                let hit = ray.origin + t * ray.direction
                return SIMD3<Float>(hit.x, floorY, hit.z)
            } else {
                let projected = ray.origin + min(distance, maxT) * ray.direction
                return SIMD3<Float>(projected.x, floorY, projected.z)
            }
        }

        // MARK: - Gesture Setup & Handling

        private weak var twoFingerPanGesture: UIPanGestureRecognizer?
        private weak var pinchGesture: UIPinchGestureRecognizer?
        private var twoFingerPanStartTarget: SIMD3<Float> = .zero
        private var lastLiveDragSyncTime: CFTimeInterval = 0

        var isTranslatingFurniture: Bool {
            if case .translating = dragMode { return true }
            return false
        }

        private func setupGestures(in arView: ARView) {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.delegate = self
            arView.addGestureRecognizer(tap)

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.maximumNumberOfTouches = 1
            pan.delegate = self
            arView.addGestureRecognizer(pan)

            let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
            twoFingerPan.minimumNumberOfTouches = 2
            twoFingerPan.maximumNumberOfTouches = 2
            twoFingerPan.delegate = self
            arView.addGestureRecognizer(twoFingerPan)
            self.twoFingerPanGesture = twoFingerPan

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinch.delegate = self
            arView.addGestureRecognizer(pinch)
            self.pinchGesture = pinch
        }

        public func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            let isTwoFingerAndPinch =
                (gestureRecognizer === twoFingerPanGesture && otherGestureRecognizer === pinchGesture) ||
                (gestureRecognizer === pinchGesture && otherGestureRecognizer === twoFingerPanGesture)
            return isTwoFingerAndPinch
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView = arView, gesture.state == .ended else { return }
            let point = gesture.location(in: arView)

            let canSelectFurniture = currentStage.unlockedTools.contains(.dragFurniture) && currentStage != .harmony
            if canSelectFurniture, let hitEntity = arView.entity(at: point) {
                var current: Entity? = hitEntity
                while let p = current, !p.name.hasPrefix("Furniture_") {
                    current = p.parent
                }
                if let container = current, container.name.hasPrefix("Furniture_") {
                    let uuidStr = String(container.name.dropFirst("Furniture_".count))
                    if let id = UUID(uuidString: uuidStr) {
                        selectedFurnitureID = id
                        onSelectFurniture?(id)
                        focusMascot(onFurnitureID: id)
                        updateSelectionHalos()
                        updateSelectedProjection()
                        playTapFeedback()
                        return
                    }
                }
            }

            if mascotController.handleScreenTap(at: point, in: arView) {
                return
            }

            // Tapped empty space (or Stage 1 inspection mode) -> deselect
            selectedFurnitureID = nil
            onSelectFurniture?(nil)
            onTapBackground?()
            updateSelectionHalos()
            updateSelectedProjection()
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let arView = arView else { return }
            let point = gesture.location(in: arView)
            let canDragFurniture = currentStage.unlockedTools.contains(.dragFurniture) && currentStage != .harmony

            switch gesture.state {
            case .began:
                animationTask?.cancel()
                if canDragFurniture, let hitEntity = arView.entity(at: point) {
                    var current: Entity? = hitEntity
                    while let p = current, !p.name.hasPrefix("Furniture_") {
                        current = p.parent
                    }
                    if let container = current, container.name.hasPrefix("Furniture_") {
                        let uuidStr = String(container.name.dropFirst("Furniture_".count))
                        if let id = UUID(uuidString: uuidStr), id == selectedFurnitureID {
                            // Already selected -> enter floor translation mode.
                            // At low/perpendicular camera pitch (< 0.45 rad), floor raycasts are grazing and unstable,
                            // so use smooth camera-relative horizontal screen-space dragging instead.
                            let useScreenSpace = pitch < 0.45
                            if !useScreenSpace, let floorPos = projectToFloor(from: point, in: arView) {
                                let offset = SIMD2<Float>(container.position.x - floorPos.x, container.position.z - floorPos.z)
                                dragMode = .translating(furnitureID: id, offset: offset, initialPos: container.position, useScreenSpace: false)
                            } else {
                                dragMode = .translating(furnitureID: id, offset: .zero, initialPos: container.position, useScreenSpace: true)
                            }
                            updateSelectedProjection()
                            return
                        }
                    }
                }

                // Touched unselected furniture, audit mode, or background -> camera orbit mode
                dragMode = .orbiting(startYaw: yaw, startPitch: pitch)

            case .changed:
                switch dragMode {
                case .translating(let id, let offset, let initialPos, let useScreenSpace):
                    guard canDragFurniture else { return }
                    guard let container = arView.scene.findEntity(named: "Furniture_\(id.uuidString)") else { return }
                    let layout = room.workingLayout ?? room.baselineLayout
                    guard let item = layout?.furnitures.first(where: { $0.id == id }) else { return }

                    let candidatePos: SIMD3<Float>
                    if useScreenSpace {
                        let translation = gesture.translation(in: arView)
                        let scale = distance * 0.0022
                        let right = SIMD3<Float>(cos(yaw), 0, -sin(yaw))
                        let forwardXZ = SIMD3<Float>(-sin(yaw), 0, -cos(yaw))
                        candidatePos = SIMD3<Float>(
                            initialPos.x + right.x * Float(translation.x) * scale - forwardXZ.x * Float(translation.y) * scale,
                            0.0,
                            initialPos.z + right.z * Float(translation.x) * scale - forwardXZ.z * Float(translation.y) * scale
                        )
                    } else {
                        guard let floorPos = projectToFloor(from: point, in: arView) else { return }
                        candidatePos = SIMD3<Float>(floorPos.x + offset.x, 0.0, floorPos.z + offset.y)
                    }
                    let clamped = FurnitureTransformEngine.clampPosition(
                        position: candidatePos,
                        furnitureWidth: Float(item.width),
                        furnitureLength: Float(item.length),
                        rotationYaw: Float(item.rotationYaw),
                        roomWidth: Float(room.dimensionsWidth),
                        roomLength: Float(room.dimensionsLength)
                    )
                    container.position = clamped
                    // Throttle SwiftData/SwiftUI warning & halo evaluation to ~15Hz during 120Hz touch drags
                    // so RealityKit's Metal render loop is never starved by synchronous SwiftUI re-renders.
                    let now = CACurrentMediaTime()
                    if now - lastLiveDragSyncTime >= 0.065 {
                        lastLiveDragSyncTime = now
                        item.positionX = Double(clamped.x)
                        item.positionZ = Double(clamped.z)
                        onFurnitureDragging?()
                        if let computed = onComputeWarningSeverities?() {
                            furnitureWarningSeverities = computed
                        }
                        updateSelectionHalos()
                    }
                    updateSelectedProjection()

                case .orbiting(let startYaw, let startPitch):
                    let translation = gesture.translation(in: arView)
                    cameraController.orbit(fromYaw: startYaw, pitch: startPitch,
                                           deltaX: translation.x, deltaY: translation.y)
                    updateCamera()
                    updateWallCutaways()
                    updateSelectedProjection()

                case .none:
                    break
                }

            case .ended:
                switch dragMode {
                case .translating(let id, _, let initialPos, _):
                    guard canDragFurniture else { break }
                    guard let container = arView.scene.findEntity(named: "Furniture_\(id.uuidString)") else { break }
                    let layout = room.workingLayout ?? room.baselineLayout
                    guard let item = layout?.furnitures.first(where: { $0.id == id }) else { break }

                    let oldPos = (x: Double(initialPos.x), z: Double(initialPos.z))
                    item.positionX = Double(container.position.x)
                    item.positionZ = Double(container.position.z)
                    let newPos = (x: item.positionX, z: item.positionZ)
                    if let computed = onComputeWarningSeverities?() {
                        furnitureWarningSeverities = computed
                    }
                    updateSelectionHalos()

                    playTapFeedback()
                    focusMascot(onFurnitureID: id)
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

            case .cancelled, .failed:
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
                    cameraController.magnify(from: pinchStartDistance, scale: scale)
                    updateCamera()
                    updateSelectedProjection()
                }
            default:
                break
            }
        }

        @objc private func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
            guard let arView = arView else { return }
            switch gesture.state {
            case .began:
                animationTask?.cancel()
                twoFingerPanStartTarget = cameraController.target
            case .changed:
                let translation = gesture.translation(in: arView)
                cameraController.panAnchor(
                    from: twoFingerPanStartTarget,
                    deltaX: translation.x,
                    deltaY: translation.y
                )
                updateCamera()
                updateWallCutaways()
                updateSelectedProjection()
            default:
                break
            }
        }

        // MARK: - Scene Entities & Halos Synchronization

        private func applyOpacity(_ opacity: Float, to entity: Entity) {
            if #available(iOS 18.0, *) {
                if opacity >= 0.995 {
                    entity.components.remove(OpacityComponent.self)
                } else {
                    entity.components.set(OpacityComponent(opacity: max(0.0, min(1.0, opacity))))
                }
            }
        }

        private func applyGhostAppearance(to entity: Entity, isGhost: Bool) {
            applyOpacity(isGhost ? 0.55 : 1.0, to: entity)
        }

        func updateFurnitureEntities(from room: Room) {
            self.room = room
            guard let group = root.children.first(where: { $0.name == "FurnitureGroup" }) else { return }
            let layout = room.workingLayout ?? room.baselineLayout
            guard let layout else { return }

            let baselineItems = room.baselineLayout?.furnitures ?? []

            // Manage Baseline Group for Stage 4 Overlay
            var ghostGroup = root.children.first(where: { $0.name == "BaselineGhostGroup" })
            if ghostGroup == nil {
                let newGroup = Entity()
                newGroup.name = "BaselineGhostGroup"
                root.addChild(newGroup)
                ghostGroup = newGroup
            }

            if currentStage == .harmony {
                ghostGroup?.isEnabled = true

                let screenWidth = Float(arView?.bounds.width ?? (viewportSize.width > 0 ? viewportSize.width : 1024))
                let splitScreenX = screenWidth * Float(max(0.01, min(0.99, beforeAfterSplit)))
                let featherZone: Float = 160.0 // Smooth screen-space cross-fade overlay band

                // 1. Working Layout Entities (After side -> Fades in smoothly to the right of splitScreenX)
                for item in layout.furnitures {
                    var entity = group.children.first(where: { $0.name == "Furniture_\(item.id.uuidString)" })
                    if entity == nil {
                        let newEntity = buildFurnitureEntity(for: item)
                        group.addChild(newEntity)
                        entity = newEntity
                    }
                    guard let entity else { continue }

                    entity.position = SIMD3<Float>(Float(item.positionX), Float(item.positionY), Float(item.positionZ))
                    entity.orientation = simd_quatf(angle: Float(item.rotationYaw), axis: SIMD3<Float>(0, 1, 0))
                    entity.scale = SIMD3<Float>(1, 1, 1)

                    if item.isArchived {
                        entity.isEnabled = false
                    } else if let arView = arView, let screenPos = arView.project(entity.position) {
                        let delta = Float(screenPos.x) - splitScreenX
                        let t = simd_clamp((delta + featherZone / 2.0) / featherZone, 0.0, 1.0)
                        let opacity = Float(t)

                        if opacity <= 0.01 {
                            entity.isEnabled = false
                        } else {
                            entity.isEnabled = true
                            applyOpacity(opacity, to: entity)
                        }
                    } else {
                        entity.isEnabled = true
                        applyOpacity(1.0, to: entity)
                    }
                }

                // 2. Baseline Layout Entities (Before side -> Fades in smoothly to the left of splitScreenX)
                if let ghostGroup {
                    for baseItem in baselineItems {
                        var ghostEntity = ghostGroup.children.first(where: { $0.name == "Ghost_\(baseItem.id.uuidString)" })
                        if ghostEntity == nil {
                            let newEntity = buildFurnitureEntity(for: baseItem)
                            newEntity.name = "Ghost_\(baseItem.id.uuidString)"
                            ghostGroup.addChild(newEntity)
                            ghostEntity = newEntity
                        }
                        guard let ghostEntity else { continue }

                        ghostEntity.position = SIMD3<Float>(Float(baseItem.positionX), Float(baseItem.positionY), Float(baseItem.positionZ))
                        ghostEntity.orientation = simd_quatf(angle: Float(baseItem.rotationYaw), axis: SIMD3<Float>(0, 1, 0))
                        ghostEntity.scale = SIMD3<Float>(1, 1, 1)

                        if baseItem.isArchived {
                            ghostEntity.isEnabled = false
                        } else if let arView = arView, let screenPos = arView.project(ghostEntity.position) {
                            let delta = Float(screenPos.x) - splitScreenX
                            let t = simd_clamp((-delta + featherZone / 2.0) / featherZone, 0.0, 1.0)
                            let opacity = Float(t)

                            if opacity <= 0.01 {
                                ghostEntity.isEnabled = false
                            } else {
                                ghostEntity.isEnabled = true
                                applyOpacity(opacity, to: ghostEntity)
                            }
                        } else {
                            ghostEntity.isEnabled = true
                            applyOpacity(1.0, to: ghostEntity)
                        }
                    }
                }
            } else {
                ghostGroup?.isEnabled = false

                // Prune entities for user-added furniture that were removed from workingLayout
                let activeIDs = Set(layout.furnitures.map(\.id))
                for child in group.children where child.name.starts(with: "Furniture_") {
                    let idString = String(child.name.dropFirst("Furniture_".count))
                    if let uuid = UUID(uuidString: idString), !activeIDs.contains(uuid) {
                        child.removeFromParent()
                        entitySignatures.removeValue(forKey: uuid)
                    }
                }

                for item in layout.furnitures {
                    let signature = "\(item.name)|\(item.categoryRaw)|\(item.width)|\(item.length)|\(item.height)|\(item.assetIdentifier ?? "")"
                    var entity = group.children.first(where: { $0.name == "Furniture_\(item.id.uuidString)" })

                    // Rebuild entity if item was swapped in-place with a different catalog preset
                    if let existing = entity, entitySignatures[item.id] != signature {
                        existing.removeFromParent()
                        entity = nil
                    }

                    if entity == nil {
                        let newEntity = buildFurnitureEntity(for: item)
                        newEntity.isEnabled = !item.isArchived
                        group.addChild(newEntity)
                        entitySignatures[item.id] = signature
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
                        if case .translating(let id, _, _, _) = dragMode, id == item.id {
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
                    let uuid = UUID(uuidString: idString)
                    let isSelected = (idString == selectedFurnitureID?.uuidString)
                    let isGhost = (idString == ghostFurnitureID?.uuidString && ghostFloorPosition != nil)
                    if let halo = child.children.first(where: { $0.name == "SelectionHalo" }) as? ModelEntity {
                        if currentStage == .harmony {
                            halo.isEnabled = isSelected || isGhost
                            halo.model?.materials = [blueHaloMaterial]
                        } else if let uuid, let severity = furnitureWarningSeverities[uuid] {
                            halo.isEnabled = true
                            halo.model?.materials = [severity == .collision ? redHaloMaterial : yellowHaloMaterial]
                        } else if isSelected || isGhost {
                            halo.isEnabled = true
                            halo.model?.materials = [blueHaloMaterial]
                        } else {
                            halo.isEnabled = false
                        }
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

            // Selection / warning footprint halo on floor
            let haloMesh = MeshResource.generateBox(
                size: SIMD3<Float>(width + 0.14, 0.006, length + 0.14),
                cornerRadius: 0.03
            )
            let halo = ModelEntity(mesh: haloMesh, materials: [blueHaloMaterial])
            halo.name = "SelectionHalo"
            halo.position = SIMD3<Float>(0, 0.003, 0)
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
