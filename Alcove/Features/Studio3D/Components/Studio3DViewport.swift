import SwiftUI
import RealityKit
import UIKit
import simd

/// Interactive native RealityKit 3D viewport rendering a low-poly room and furniture layout.
public struct Studio3DViewport: View {
    public let room: Room
    @Binding public var selectedFurnitureID: UUID?

    // 45° Dollhouse Perspective (Pitch ~37°, Yaw ~ -30°)
    private static let defaultPitch: Float = 0.62
    private static let defaultYaw: Float = -0.52
    private static let defaultZoom: Float = 0.40

    @State private var pitch: Float = Studio3DViewport.defaultPitch
    @State private var yaw: Float = Studio3DViewport.defaultYaw
    @State private var zoomScale: Float = Studio3DViewport.defaultZoom

    @State private var dragStartPitch: Float = Studio3DViewport.defaultPitch
    @State private var dragStartYaw: Float = Studio3DViewport.defaultYaw
    @State private var baseZoomScale: Float = Studio3DViewport.defaultZoom

    public init(room: Room, selectedFurnitureID: Binding<UUID?> = .constant(nil)) {
        self.room = room
        self._selectedFurnitureID = selectedFurnitureID
    }

    public var body: some View {
        RealityView { content in
            let root = buildRoomScene()
            content.add(root)
        } update: { content in
            guard let root = content.entities.first(where: { $0.name == "DollhouseRoot" }) else { return }

            // Camera orbit and zoom transforms
            let yawQuat = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
            let pitchQuat = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
            let rootOrient = pitchQuat * yawQuat
            root.orientation = rootOrient
            root.scale = SIMD3<Float>(repeating: zoomScale)

            // Dynamic camera-facing wall cutaways
            updateWallCutaways(in: root, orientation: rootOrient, pitch: pitch)

            // Update selection halos
            updateSelectionHalos(in: root)
        }
        .gesture(orbitGesture)
        .simultaneousGesture(pinchGesture)
        .gesture(tapSelectionGesture)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: - Interactive Gestures

    /// Orbit Drag Gesture: Smoothly rotates camera pitch and yaw around room center.
    private var orbitGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                yaw = dragStartYaw + Float(value.translation.width) * 0.007
                let newPitch = dragStartPitch + Float(value.translation.height) * 0.005
                // Clamp pitch so camera cannot flip upside down or drop beneath floor
                pitch = min(max(newPitch, 0.10), 1.50)
            }
            .onEnded { _ in
                dragStartYaw = yaw
                dragStartPitch = pitch
            }
    }

    /// Pinch Zoom Gesture: Smoothly scales camera distance.
    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                let target = baseZoomScale * Float(scale)
                zoomScale = min(max(target, 0.20), 1.20)
            }
            .onEnded { _ in
                baseZoomScale = zoomScale
            }
    }

    /// Tap Gesture: Hit-tests furniture entities to toggle selection.
    private var tapSelectionGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                var target: Entity? = value.entity
                while let current = target {
                    if current.name.starts(with: "Furniture_") {
                        let idString = String(current.name.dropFirst("Furniture_".count))
                        if let uuid = UUID(uuidString: idString) {
                            withAnimation(.snappy(duration: 0.2)) {
                                selectedFurnitureID = (selectedFurnitureID == uuid) ? nil : uuid
                            }
                            return
                        }
                    }
                    target = current.parent
                }
                // Tapped empty space / floor: deselect
                withAnimation(.snappy(duration: 0.2)) {
                    selectedFurnitureID = nil
                }
            }
    }

    // MARK: - 3D Scene Assembly

    @MainActor
    private func buildRoomScene() -> Entity {
        let root = Entity()
        root.name = "DollhouseRoot"

        let maxDim = Float(max(room.dimensionsWidth, room.dimensionsLength, 3.0))
        root.position = SIMD3<Float>(0, -0.40, -maxDim * 0.88)

        // 1. Procedural Room Shell: Floor and 4 Walls (Front wall has cutaway for interior visibility)
        let roomShell = buildRoomShell()
        root.addChild(roomShell)

        // 2. Procedural Low-Poly Furniture Entities
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

        // 3. Directional Sunlight pouring through the back window
        let sun = DirectionalLight()
        sun.name = "SunLight"
        sun.light.intensity = 2800
        sun.light.color = .init(red: 1.0, green: 0.96, blue: 0.90, alpha: 1.0)
        sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 14.0, depthBias: 1.0)
        sun.position = SIMD3<Float>(2.5, 4.5, -4.5)
        sun.look(at: SIMD3<Float>(0, 0.4, 0), from: sun.position, relativeTo: nil)
        root.addChild(sun)

        // 4. Ambient Fill Light
        let fill = DirectionalLight()
        fill.name = "FillLight"
        fill.light.intensity = 800
        fill.light.color = .init(red: 0.88, green: 0.92, blue: 1.0, alpha: 1.0)
        fill.position = SIMD3<Float>(-3.5, 4.0, 3.5)
        fill.look(at: .zero, from: fill.position, relativeTo: nil)
        root.addChild(fill)

        // 5. Initial Camera-Facing Wall Cutaways
        let yawQuat = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        let pitchQuat = simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
        let initialOrient = pitchQuat * yawQuat
        root.orientation = initialOrient
        updateWallCutaways(in: root, orientation: initialOrient, pitch: pitch)

        return root
    }

    @MainActor
    private func buildRoomShell() -> Entity {
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

        // MARK: 1. Back Wall Group (Window Aperture + Baseboard)
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

        let vMullionMesh = MeshResource.generateBox(size: SIMD3<Float>(0.025, windowH, 0.03))
        let vMullion = ModelEntity(mesh: vMullionMesh, materials: [windowFrameMaterial])
        vMullion.position = SIMD3<Float>(0, windowCenterY, backWallZ)
        backWallGroup.addChild(vMullion)

        let hMullionMesh = MeshResource.generateBox(size: SIMD3<Float>(windowW, 0.025, 0.03))
        let hMullion = ModelEntity(mesh: hMullionMesh, materials: [windowFrameMaterial])
        hMullion.position = SIMD3<Float>(0, windowCenterY, backWallZ)
        backWallGroup.addChild(hMullion)

        let backBaseboardMesh = MeshResource.generateBox(size: SIMD3<Float>(roomW, baseboardH, baseboardThickness))
        let backBaseboard = ModelEntity(mesh: backBaseboardMesh, materials: [trimMaterial])
        backBaseboard.position = SIMD3<Float>(0, baseboardH / 2.0, -halfL + (baseboardThickness / 2.0))
        backWallGroup.addChild(backBaseboard)

        shell.addChild(backWallGroup)

        // MARK: 2. Left Wall Group
        let leftWallGroup = Entity()
        leftWallGroup.name = "LeftWallGroup"

        let leftWallMesh = MeshResource.generateBox(size: SIMD3<Float>(wallThickness, roomH, roomL + wallThickness))
        let leftWall = ModelEntity(mesh: leftWallMesh, materials: [wallMaterial])
        leftWall.position = SIMD3<Float>(-halfW - (wallThickness / 2.0), roomH / 2.0, -(wallThickness / 4.0))
        leftWallGroup.addChild(leftWall)

        let leftBaseboardMesh = MeshResource.generateBox(size: SIMD3<Float>(baseboardThickness, baseboardH, roomL))
        let leftBaseboard = ModelEntity(mesh: leftBaseboardMesh, materials: [trimMaterial])
        leftBaseboard.position = SIMD3<Float>(-halfW + (baseboardThickness / 2.0), baseboardH / 2.0, 0)
        leftWallGroup.addChild(leftBaseboard)

        shell.addChild(leftWallGroup)

        // MARK: 3. Right Wall Group
        let rightWallGroup = Entity()
        rightWallGroup.name = "RightWallGroup"

        let rightWallMesh = MeshResource.generateBox(size: SIMD3<Float>(wallThickness, roomH, roomL + wallThickness))
        let rightWall = ModelEntity(mesh: rightWallMesh, materials: [wallMaterial])
        rightWall.position = SIMD3<Float>(halfW + (wallThickness / 2.0), roomH / 2.0, -(wallThickness / 4.0))
        rightWallGroup.addChild(rightWall)

        let rightBaseboardMesh = MeshResource.generateBox(size: SIMD3<Float>(baseboardThickness, baseboardH, roomL))
        let rightBaseboard = ModelEntity(mesh: rightBaseboardMesh, materials: [trimMaterial])
        rightBaseboard.position = SIMD3<Float>(halfW - (baseboardThickness / 2.0), baseboardH / 2.0, 0)
        rightWallGroup.addChild(rightBaseboard)

        shell.addChild(rightWallGroup)

        // MARK: 4. Front Wall Group (Full Height with Doorway Aperture)
        let frontWallGroup = Entity()
        frontWallGroup.name = "FrontWallGroup"
        let frontWallZ = halfL + (wallThickness / 2.0)

        let doorW: Float = 0.90
        let doorH: Float = 2.10
        let doorCenterX: Float = min(1.20, halfW - 0.60)
        let doorMinX = doorCenterX - (doorW / 2.0)
        let doorMaxX = doorCenterX + (doorW / 2.0)

        // Left section of front wall
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

        // Right section of front wall
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

        // Header above doorway
        let doorHeaderH = roomH - doorH
        let doorHeaderMesh = MeshResource.generateBox(size: SIMD3<Float>(doorW, doorHeaderH, wallThickness))
        let doorHeader = ModelEntity(mesh: doorHeaderMesh, materials: [wallMaterial])
        doorHeader.position = SIMD3<Float>(doorCenterX, doorH + (doorHeaderH / 2.0), frontWallZ)
        frontWallGroup.addChild(doorHeader)

        // Door frame trim and door panel
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

    // MARK: - Dynamic Camera-Facing Wall Cutaways

    @MainActor
    private func updateWallCutaways(in root: Entity, orientation: simd_quatf, pitch: Float) {
        guard let shell = root.findEntity(named: "RoomShell") else { return }

        let walls: [(name: String, normal: SIMD3<Float>)] = [
            ("FrontWallGroup", WallCutawayEvaluator.frontNormal),
            ("BackWallGroup", WallCutawayEvaluator.backNormal),
            ("LeftWallGroup", WallCutawayEvaluator.leftNormal),
            ("RightWallGroup", WallCutawayEvaluator.rightNormal)
        ]

        for wall in walls {
            if let entity = shell.findEntity(named: wall.name) {
                let isHidden = WallCutawayEvaluator.isWallHidden(
                    wallNormal: wall.normal,
                    orientation: orientation,
                    pitch: pitch
                )
                entity.isEnabled = !isHidden
            }
        }
    }

    @MainActor
    private func buildFurnitureEntity(for item: Furniture) -> Entity {
        let container = Entity()
        container.name = "Furniture_\(item.id.uuidString)"
        container.position = SIMD3<Float>(Float(item.positionX), Float(item.positionY), Float(item.positionZ))
        container.orientation = simd_quatf(angle: Float(item.rotationYaw), axis: SIMD3<Float>(0, 1, 0))

        let width = Float(item.width)
        let height = Float(item.height)
        let length = Float(item.length)

        // Detailed procedural multi-part entity
        let model = ProceduralFurnitureBuilder.buildDetailedEntity(for: item)
        container.addChild(model)

        // Collision & Raycast target
        let boxShape = ShapeResource.generateBox(size: SIMD3<Float>(width, height, length))
        let offset = Transform(translation: SIMD3<Float>(0, height / 2.0, 0))
        container.components.set(CollisionComponent(shapes: [boxShape.offsetBy(rotation: offset.rotation, translation: offset.translation)]))
        container.components.set(InputTargetComponent())

        // Floor-level selection halo
        let haloMesh = MeshResource.generateBox(size: SIMD3<Float>(width + 0.08, 0.003, length + 0.08), cornerRadius: 0.02)
        let haloMat = SimpleMaterial(color: UIColor.systemBlue.withAlphaComponent(0.65), roughness: 0.2, isMetallic: false)
        let halo = ModelEntity(mesh: haloMesh, materials: [haloMat])
        halo.name = "SelectionHalo"
        halo.position = SIMD3<Float>(0, 0.002, 0)
        halo.isEnabled = (item.id == selectedFurnitureID)
        container.addChild(halo)

        return container
    }

    @MainActor
    private func updateSelectionHalos(in root: Entity) {
        guard let group = root.findEntity(named: "FurnitureGroup") else { return }
        for child in group.children {
            if child.name.starts(with: "Furniture_") {
                let idString = String(child.name.dropFirst("Furniture_".count))
                let isSelected = (idString == selectedFurnitureID?.uuidString)
                if let halo = child.findEntity(named: "SelectionHalo") {
                    halo.isEnabled = isSelected
                }
            }
        }
    }
}
