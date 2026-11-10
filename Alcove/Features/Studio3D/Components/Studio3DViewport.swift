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
    public var onFurnitureMoved: ((FurnitureMoveEvent) -> Void)? = nil

    public init(
        room: Room,
        selectedFurnitureID: Binding<UUID?>,
        selectedFurnitureScreenPosition: Binding<CGPoint?>,
        viewportSize: CGSize = .zero,
        onFurnitureMoved: ((FurnitureMoveEvent) -> Void)? = nil
    ) {
        self.room = room
        self._selectedFurnitureID = selectedFurnitureID
        self._selectedFurnitureScreenPosition = selectedFurnitureScreenPosition
        self.viewportSize = viewportSize
        self.onFurnitureMoved = onFurnitureMoved
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
            onFurnitureMoved: onFurnitureMoved
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

        return view
    }

    public func updateUIView(_ arView: ARView, context: Context) {
        context.coordinator.selectedFurnitureID = selectedFurnitureID
        context.coordinator.updateFurnitureEntities(from: room)
        context.coordinator.updateSelectionHalos()
        context.coordinator.updateSelectedProjection()
    }

    public static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        coordinator.updateSubscription?.cancel()
        view.scene.anchors.removeAll()
    }

    // MARK: - Coordinator & Gesture Controller

    @MainActor
    public final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var arView: ARView?
        var room: Room
        var selectedFurnitureID: UUID?
        var onSelectFurniture: ((UUID?) -> Void)?
        var onProjectSelectedFurniture: ((CGPoint?) -> Void)?
        var onFurnitureMoved: ((FurnitureMoveEvent) -> Void)?

        let root = Entity()
        let camera = PerspectiveCamera()
        let sun = DirectionalLight()
        let fill = DirectionalLight()

        var updateSubscription: (any Cancellable)?

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
            onFurnitureMoved: ((FurnitureMoveEvent) -> Void)?
        ) {
            self.room = room
            self.selectedFurnitureID = selectedFurnitureID
            self.onSelectFurniture = onSelectFurniture
            self.onProjectSelectedFurniture = onProjectSelectedFurniture
            self.onFurnitureMoved = onFurnitureMoved
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

            // Directional Sunlight pouring through window
            sun.name = "SunLight"
            sun.light.intensity = 2800
            sun.light.color = .init(red: 1.0, green: 0.96, blue: 0.90, alpha: 1.0)
            sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 14.0, depthBias: 1.0)
            sun.look(at: .zero, from: [2.5, 4.5, -4.5], relativeTo: nil)
            root.addChild(sun)

            // Ambient Fill Light
            fill.name = "FillLight"
            fill.light.intensity = 1400
            fill.light.color = .init(red: 0.92, green: 0.95, blue: 1.0, alpha: 1.0)
            fill.look(at: .zero, from: [-3.0, 4.0, 3.0], relativeTo: nil)
            root.addChild(fill)

            // Procedural Room Shell: Floor and 4 Cardinal Walls
            let shell = buildRoomShell(for: room)
            root.addChild(shell)

            // Procedural Low-Poly Furniture Entities
            let furnitureGroup = Entity()
            furnitureGroup.name = "FurnitureGroup"
            let layout = room.workingLayout ?? room.baselineLayout
            if let layout {
                for item in layout.furnitures where !item.isArchived {
                    let entity = buildFurnitureEntity(for: item)
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
                    entity.isEnabled = !isHidden
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
            guard abs(ray.direction.y) > 1e-4 else { return nil }
            let floorY: Float = 0.0
            let t = (floorY - ray.origin.y) / ray.direction.y
            guard t > 0 else { return nil }
            return ray.origin + t * ray.direction
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
            updateSelectionHalos()
            updateSelectedProjection()
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let arView = arView else { return }
            let point = gesture.location(in: arView)

            switch gesture.state {
            case .began:
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
                    pitch = min(1.50, max(0.12, rawPitch))
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

        func updateFurnitureEntities(from room: Room) {
            self.room = room
            guard let group = root.children.first(where: { $0.name == "FurnitureGroup" }) else { return }
            let layout = room.workingLayout ?? room.baselineLayout
            guard let layout else { return }

            for item in layout.furnitures {
                if let entity = group.children.first(where: { $0.name == "Furniture_\(item.id.uuidString)" }) {
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

        func updateSelectionHalos() {
            guard let group = root.children.first(where: { $0.name == "FurnitureGroup" }) else { return }
            for child in group.children {
                if child.name.starts(with: "Furniture_") {
                    let idString = String(child.name.dropFirst("Furniture_".count))
                    let isSelected = (idString == selectedFurnitureID?.uuidString)
                    if let halo = child.children.first(where: { $0.name == "SelectionHalo" }) {
                        halo.isEnabled = isSelected
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
            let shell = Entity()
            shell.name = "RoomShell"

            let roomW = Float(room.dimensionsWidth)
            let roomL = Float(room.dimensionsLength)
            let roomH = Float(room.dimensionsHeight)
            let wallThickness: Float = 0.12
            let halfW = roomW / 2.0
            let halfL = roomL / 2.0

            // Floor Plane (Warm Natural Oak)
            let floorMesh = MeshResource.generateBox(
                size: SIMD3<Float>(roomW, 0.02, roomL),
                cornerRadius: 0.005
            )
            let floorMaterial = SimpleMaterial(
                color: UIColor(red: 0.78, green: 0.64, blue: 0.48, alpha: 1.0),
                roughness: 0.45,
                isMetallic: false
            )
            let floorEntity = ModelEntity(mesh: floorMesh, materials: [floorMaterial])
            floorEntity.name = "Floor"
            floorEntity.position = SIMD3<Float>(0, -0.01, 0)
            shell.addChild(floorEntity)

            // Wall & Architectural Trim Materials
            let wallMaterial = SimpleMaterial(
                color: UIColor(red: 0.94, green: 0.93, blue: 0.91, alpha: 1.0),
                roughness: 0.85,
                isMetallic: false
            )
            let trimMaterial = SimpleMaterial(
                color: UIColor(red: 0.96, green: 0.96, blue: 0.95, alpha: 1.0),
                roughness: 0.25,
                isMetallic: false
            )
            let windowFrameMaterial = SimpleMaterial(
                color: UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1.0),
                roughness: 0.35,
                isMetallic: true
            )
            let glassMaterial = SimpleMaterial(
                color: UIColor(red: 0.82, green: 0.90, blue: 0.96, alpha: 0.35),
                roughness: 0.05,
                isMetallic: false
            )
            let doorFrameMaterial = SimpleMaterial(
                color: UIColor(red: 0.38, green: 0.26, blue: 0.18, alpha: 1.0),
                roughness: 0.40,
                isMetallic: false
            )

            let baseboardH: Float = 0.08
            let baseboardThickness: Float = 0.015

            // 1. Back Wall Group (Window Aperture + Baseboard)
            let backWallGroup = Entity()
            backWallGroup.name = "BackWallGroup"

            let windowW: Float = min(1.8, roomW * 0.40)
            let windowH: Float = 1.30
            let sillH: Float = 0.85
            let headerH = roomH - (sillH + windowH)
            let sideW = (roomW - windowW) / 2.0
            let backWallZ = -halfL - (wallThickness / 2.0)

            let backLeftMesh = MeshResource.generateBox(size: SIMD3<Float>(sideW, roomH, wallThickness))
            let backLeft = ModelEntity(mesh: backLeftMesh, materials: [wallMaterial])
            backLeft.position = SIMD3<Float>(-halfW + (sideW / 2.0), roomH / 2.0, backWallZ)
            backWallGroup.addChild(backLeft)

            let backRightMesh = MeshResource.generateBox(size: SIMD3<Float>(sideW, roomH, wallThickness))
            let backRight = ModelEntity(mesh: backRightMesh, materials: [wallMaterial])
            backRight.position = SIMD3<Float>(halfW - (sideW / 2.0), roomH / 2.0, backWallZ)
            backWallGroup.addChild(backRight)

            let backSillMesh = MeshResource.generateBox(size: SIMD3<Float>(windowW, sillH, wallThickness))
            let backSill = ModelEntity(mesh: backSillMesh, materials: [wallMaterial])
            backSill.position = SIMD3<Float>(0, sillH / 2.0, backWallZ)
            backWallGroup.addChild(backSill)

            let backHeaderMesh = MeshResource.generateBox(size: SIMD3<Float>(windowW, headerH, wallThickness))
            let backHeader = ModelEntity(mesh: backHeaderMesh, materials: [wallMaterial])
            backHeader.position = SIMD3<Float>(0, roomH - (headerH / 2.0), backWallZ)
            backWallGroup.addChild(backHeader)

            let sillLedgeMesh = MeshResource.generateBox(
                size: SIMD3<Float>(windowW + 0.10, 0.035, wallThickness + 0.08),
                cornerRadius: 0.005
            )
            let sillLedge = ModelEntity(mesh: sillLedgeMesh, materials: [trimMaterial])
            sillLedge.position = SIMD3<Float>(0, sillH + 0.0175, backWallZ + 0.02)
            backWallGroup.addChild(sillLedge)

            let frameCasingMesh = MeshResource.generateBox(
                size: SIMD3<Float>(windowW, windowH, 0.015),
                cornerRadius: 0.005
            )
            let glass = ModelEntity(mesh: frameCasingMesh, materials: [glassMaterial])
            let windowCenterY = sillH + (windowH / 2.0)
            glass.position = SIMD3<Float>(0, windowCenterY, backWallZ)
            backWallGroup.addChild(glass)

            let mullionHMesh = MeshResource.generateBox(size: SIMD3<Float>(windowW, 0.02, 0.025))
            let mullionH = ModelEntity(mesh: mullionHMesh, materials: [windowFrameMaterial])
            mullionH.position = SIMD3<Float>(0, windowCenterY, backWallZ)
            backWallGroup.addChild(mullionH)

            let mullionVMesh = MeshResource.generateBox(size: SIMD3<Float>(0.02, windowH, 0.025))
            let mullionV = ModelEntity(mesh: mullionVMesh, materials: [windowFrameMaterial])
            mullionV.position = SIMD3<Float>(0, windowCenterY, backWallZ)
            backWallGroup.addChild(mullionV)

            let backBaseboardMesh = MeshResource.generateBox(size: SIMD3<Float>(roomW, baseboardH, baseboardThickness))
            let backBaseboard = ModelEntity(mesh: backBaseboardMesh, materials: [trimMaterial])
            backBaseboard.position = SIMD3<Float>(0, baseboardH / 2.0, -halfL + (baseboardThickness / 2.0))
            backWallGroup.addChild(backBaseboard)

            shell.addChild(backWallGroup)

            // 2. Left Solid Perimeter Wall Group
            let leftWallGroup = Entity()
            leftWallGroup.name = "LeftWallGroup"

            let leftMesh = MeshResource.generateBox(size: SIMD3<Float>(wallThickness, roomH, roomL))
            let leftWall = ModelEntity(mesh: leftMesh, materials: [wallMaterial])
            leftWall.position = SIMD3<Float>(-halfW - (wallThickness / 2.0), roomH / 2.0, 0)
            leftWallGroup.addChild(leftWall)

            let leftBaseboardMesh = MeshResource.generateBox(size: SIMD3<Float>(baseboardThickness, baseboardH, roomL))
            let leftBaseboard = ModelEntity(mesh: leftBaseboardMesh, materials: [trimMaterial])
            leftBaseboard.position = SIMD3<Float>(-halfW + (baseboardThickness / 2.0), baseboardH / 2.0, 0)
            leftWallGroup.addChild(leftBaseboard)

            shell.addChild(leftWallGroup)

            // 3. Right Solid Perimeter Wall Group
            let rightWallGroup = Entity()
            rightWallGroup.name = "RightWallGroup"

            let rightMesh = MeshResource.generateBox(size: SIMD3<Float>(wallThickness, roomH, roomL))
            let rightWall = ModelEntity(mesh: rightMesh, materials: [wallMaterial])
            rightWall.position = SIMD3<Float>(halfW + (wallThickness / 2.0), roomH / 2.0, 0)
            rightWallGroup.addChild(rightWall)

            let rightBaseboardMesh = MeshResource.generateBox(size: SIMD3<Float>(baseboardThickness, baseboardH, roomL))
            let rightBaseboard = ModelEntity(mesh: rightBaseboardMesh, materials: [trimMaterial])
            rightBaseboard.position = SIMD3<Float>(halfW - (baseboardThickness / 2.0), baseboardH / 2.0, 0)
            rightWallGroup.addChild(rightBaseboard)

            shell.addChild(rightWallGroup)

            // 4. Front Wall Group (Door Opening with Cutaway Geometry)
            let frontWallGroup = Entity()
            frontWallGroup.name = "FrontWallGroup"

            let doorW: Float = 0.90
            let doorH: Float = min(2.10, roomH - 0.20)
            let doorCenterX: Float = -halfW * 0.35
            let doorMinX = doorCenterX - (doorW / 2.0)
            let doorMaxX = doorCenterX + (doorW / 2.0)
            let frontWallZ = halfL + (wallThickness / 2.0)

            let frontLeftW = doorMinX - (-halfW)
            if frontLeftW > 0.05 {
                let frontLeftMesh = MeshResource.generateBox(size: SIMD3<Float>(frontLeftW, roomH, wallThickness))
                let frontLeft = ModelEntity(mesh: frontLeftMesh, materials: [wallMaterial])
                frontLeft.position = SIMD3<Float>(-halfW + (frontLeftW / 2.0), roomH / 2.0, frontWallZ)
                frontWallGroup.addChild(frontLeft)

                let frontBaseboardLeftMesh = MeshResource.generateBox(size: SIMD3<Float>(frontLeftW, baseboardH, baseboardThickness))
                let frontBaseboardLeft = ModelEntity(mesh: frontBaseboardLeftMesh, materials: [trimMaterial])
                frontBaseboardLeft.position = SIMD3<Float>(-halfW + (frontLeftW / 2.0), baseboardH / 2.0, halfL - (baseboardThickness / 2.0))
                frontWallGroup.addChild(frontBaseboardLeft)
            }

            let frontRightW = halfW - doorMaxX
            if frontRightW > 0.05 {
                let frontRightMesh = MeshResource.generateBox(size: SIMD3<Float>(frontRightW, roomH, wallThickness))
                let frontRight = ModelEntity(mesh: frontRightMesh, materials: [wallMaterial])
                frontRight.position = SIMD3<Float>(doorMaxX + (frontRightW / 2.0), roomH / 2.0, frontWallZ)
                frontWallGroup.addChild(frontRight)

                let frontBaseboardRightMesh = MeshResource.generateBox(size: SIMD3<Float>(frontRightW, baseboardH, baseboardThickness))
                let frontBaseboardRight = ModelEntity(mesh: frontBaseboardRightMesh, materials: [trimMaterial])
                frontBaseboardRight.position = SIMD3<Float>(doorMaxX + (frontRightW / 2.0), baseboardH / 2.0, halfL - (baseboardThickness / 2.0))
                frontWallGroup.addChild(frontBaseboardRight)
            }

            let doorHeaderH = roomH - doorH
            let doorHeaderMesh = MeshResource.generateBox(size: SIMD3<Float>(doorW, doorHeaderH, wallThickness))
            let doorHeader = ModelEntity(mesh: doorHeaderMesh, materials: [wallMaterial])
            doorHeader.position = SIMD3<Float>(doorCenterX, doorH + (doorHeaderH / 2.0), frontWallZ)
            frontWallGroup.addChild(doorHeader)

            let doorFrameMesh = MeshResource.generateBox(size: SIMD3<Float>(doorW + 0.04, doorH + 0.02, wallThickness + 0.02), cornerRadius: 0.005)
            let doorFrame = ModelEntity(mesh: doorFrameMesh, materials: [doorFrameMaterial])
            doorFrame.position = SIMD3<Float>(doorCenterX, (doorH + 0.02) / 2.0, frontWallZ)
            frontWallGroup.addChild(doorFrame)

            let doorPanelMesh = MeshResource.generateBox(size: SIMD3<Float>(doorW - 0.02, doorH - 0.02, 0.035), cornerRadius: 0.005)
            let doorPanel = ModelEntity(mesh: doorPanelMesh, materials: [doorFrameMaterial])
            doorPanel.position = SIMD3<Float>(doorCenterX, doorH / 2.0, frontWallZ)
            frontWallGroup.addChild(doorPanel)

            shell.addChild(frontWallGroup)

            return shell
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
