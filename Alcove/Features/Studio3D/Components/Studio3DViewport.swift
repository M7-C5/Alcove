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
            root.orientation = pitchQuat * yawQuat
            root.scale = SIMD3<Float>(repeating: zoomScale)

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

        // Wall & Trim Materials
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

        // 1. Back Wall with Architectural Window Aperture
        let windowW: Float = min(1.8, roomW * 0.40)
        let windowH: Float = 1.30
        let sillH: Float = 0.85
        let headerH = roomH - (sillH + windowH)
        let sideW = (roomW - windowW) / 2.0
        let backWallZ = -halfL - (wallThickness / 2.0)

        // Left section of back wall
        let backLeftMesh = MeshResource.generateBox(size: SIMD3<Float>(sideW, roomH, wallThickness))
        let backLeft = ModelEntity(mesh: backLeftMesh, materials: [wallMaterial])
        backLeft.position = SIMD3<Float>(-halfW + (sideW / 2.0), roomH / 2.0, backWallZ)
        shell.addChild(backLeft)

        // Right section of back wall
        let backRightMesh = MeshResource.generateBox(size: SIMD3<Float>(sideW, roomH, wallThickness))
        let backRight = ModelEntity(mesh: backRightMesh, materials: [wallMaterial])
        backRight.position = SIMD3<Float>(halfW - (sideW / 2.0), roomH / 2.0, backWallZ)
        shell.addChild(backRight)

        // Bottom sill section of back wall
        let backSillMesh = MeshResource.generateBox(size: SIMD3<Float>(windowW, sillH, wallThickness))
        let backSill = ModelEntity(mesh: backSillMesh, materials: [wallMaterial])
        backSill.position = SIMD3<Float>(0, sillH / 2.0, backWallZ)
        shell.addChild(backSill)

        // Top header section of back wall
        let backHeaderMesh = MeshResource.generateBox(size: SIMD3<Float>(windowW, headerH, wallThickness))
        let backHeader = ModelEntity(mesh: backHeaderMesh, materials: [wallMaterial])
        backHeader.position = SIMD3<Float>(0, roomH - (headerH / 2.0), backWallZ)
        shell.addChild(backHeader)

        // Window Sill Projecting Ledge
        let sillLedgeMesh = MeshResource.generateBox(
            size: SIMD3<Float>(windowW + 0.10, 0.035, wallThickness + 0.08),
            cornerRadius: 0.005
        )
        let sillLedge = ModelEntity(mesh: sillLedgeMesh, materials: [trimMaterial])
        sillLedge.position = SIMD3<Float>(0, sillH + 0.0175, backWallZ + 0.02)
        shell.addChild(sillLedge)

        // Window Glass Pane
        let frameCasingMesh = MeshResource.generateBox(
            size: SIMD3<Float>(windowW, windowH, 0.015),
            cornerRadius: 0.005
        )
        let glass = ModelEntity(mesh: frameCasingMesh, materials: [glassMaterial])
        let windowCenterY = sillH + (windowH / 2.0)
        glass.position = SIMD3<Float>(0, windowCenterY, backWallZ)
        shell.addChild(glass)

        // Vertical Mullion Bar
        let vMullionMesh = MeshResource.generateBox(size: SIMD3<Float>(0.025, windowH, 0.03))
        let vMullion = ModelEntity(mesh: vMullionMesh, materials: [windowFrameMaterial])
        vMullion.position = SIMD3<Float>(0, windowCenterY, backWallZ)
        shell.addChild(vMullion)

        // Horizontal Mullion Bar
        let hMullionMesh = MeshResource.generateBox(size: SIMD3<Float>(windowW, 0.025, 0.03))
        let hMullion = ModelEntity(mesh: hMullionMesh, materials: [windowFrameMaterial])
        hMullion.position = SIMD3<Float>(0, windowCenterY, backWallZ)
        shell.addChild(hMullion)

        // 2. Left Wall (X = -halfW, Full Height)
        let leftWallMesh = MeshResource.generateBox(size: SIMD3<Float>(wallThickness, roomH, roomL + wallThickness))
        let leftWall = ModelEntity(mesh: leftWallMesh, materials: [wallMaterial])
        leftWall.name = "LeftWall"
        leftWall.position = SIMD3<Float>(-halfW - (wallThickness / 2.0), roomH / 2.0, -(wallThickness / 4.0))
        shell.addChild(leftWall)

        // 3. Right Wall (X = +halfW, Full Height)
        let rightWallMesh = MeshResource.generateBox(size: SIMD3<Float>(wallThickness, roomH, roomL + wallThickness))
        let rightWall = ModelEntity(mesh: rightWallMesh, materials: [wallMaterial])
        rightWall.name = "RightWall"
        rightWall.position = SIMD3<Float>(halfW + (wallThickness / 2.0), roomH / 2.0, -(wallThickness / 4.0))
        shell.addChild(rightWall)

        // 4. Front Wall (Z = +halfL, Cutaway height ~0.35m for dollhouse viewing)
        let frontCurbHeight: Float = 0.35
        let frontWallMesh = MeshResource.generateBox(size: SIMD3<Float>(roomW, frontCurbHeight, wallThickness))
        let frontWall = ModelEntity(mesh: frontWallMesh, materials: [wallMaterial])
        frontWall.name = "FrontWall"
        frontWall.position = SIMD3<Float>(0, frontCurbHeight / 2.0, halfL + (wallThickness / 2.0))
        shell.addChild(frontWall)

        // 5. Perimeter Baseboards (Skirting Boards)
        let baseboardH: Float = 0.08
        let baseboardThickness: Float = 0.015

        // Back baseboard
        let backBaseboardMesh = MeshResource.generateBox(size: SIMD3<Float>(roomW, baseboardH, baseboardThickness))
        let backBaseboard = ModelEntity(mesh: backBaseboardMesh, materials: [trimMaterial])
        backBaseboard.position = SIMD3<Float>(0, baseboardH / 2.0, -halfL + (baseboardThickness / 2.0))
        shell.addChild(backBaseboard)

        // Left baseboard
        let leftBaseboardMesh = MeshResource.generateBox(size: SIMD3<Float>(baseboardThickness, baseboardH, roomL))
        let leftBaseboard = ModelEntity(mesh: leftBaseboardMesh, materials: [trimMaterial])
        leftBaseboard.position = SIMD3<Float>(-halfW + (baseboardThickness / 2.0), baseboardH / 2.0, 0)
        shell.addChild(leftBaseboard)

        // Right baseboard
        let rightBaseboardMesh = MeshResource.generateBox(size: SIMD3<Float>(baseboardThickness, baseboardH, roomL))
        let rightBaseboard = ModelEntity(mesh: rightBaseboardMesh, materials: [trimMaterial])
        rightBaseboard.position = SIMD3<Float>(halfW - (baseboardThickness / 2.0), baseboardH / 2.0, 0)
        shell.addChild(rightBaseboard)

        return shell
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
