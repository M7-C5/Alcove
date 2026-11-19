import UIKit
import RealityKit

/// Procedural architectural shell builder constructing floor, perimeter drywall, baseboards,
/// window apertures, and dynamic ceiling planes.
public struct ProceduralRoomShellBuilder {

    /// Constructs a 3D architectural room shell entity.
    /// Uses real scanned walls & openings when `room.planSnapshot` is present;
    /// otherwise builds the generic sample room shell.
    public static func buildShell(for room: Room, includeCeiling: Bool = false) -> Entity {
        buildShell(
            width: room.dimensionsWidth,
            length: room.dimensionsLength,
            height: room.dimensionsHeight,
            planSnapshot: room.planSnapshot,
            includeCeiling: includeCeiling
        )
    }

    /// Value-based entry point supporting persisted scanned room geometry when available.
    public static func buildShell(
        width: Double,
        length: Double,
        height: Double,
        planSnapshot: RoomPlanSnapshot?,
        includeCeiling: Bool = false
    ) -> Entity {
        if let snapshot = planSnapshot, !snapshot.wallSegments.isEmpty {
            return buildScannedShell(
                snapshot: snapshot,
                fallbackWidth: width,
                fallbackLength: length,
                height: height,
                includeCeiling: includeCeiling
            )
        }
        return buildShell(
            width: width,
            length: length,
            height: height,
            includeCeiling: includeCeiling
        )
    }

    private static func buildScannedShell(
        snapshot: RoomPlanSnapshot,
        fallbackWidth: Double,
        fallbackLength: Double,
        height: Double,
        includeCeiling: Bool
    ) -> Entity {
        let shell = Entity()
        shell.name = "RoomShell"

        let bounds = RoomPlanBounds(
            snapshot: snapshot,
            fallbackWidth: Float(fallbackWidth),
            fallbackLength: Float(fallbackLength)
        )
        let roomW = bounds.width
        let roomL = bounds.length
        let centerX = bounds.minX + roomW / 2.0
        let centerZ = bounds.minZ + roomL / 2.0
        let wallThickness: Float = 0.12

        // Floor Plane matching the scanned room footprint
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
        floorEntity.position = SIMD3<Float>(centerX, -0.01, centerZ)
        shell.addChild(floorEntity)

        if includeCeiling {
            let ceiling = buildCeiling(width: Double(roomW), length: Double(roomL), height: height)
            ceiling.position = SIMD3<Float>(centerX, Float(height) + 0.01, centerZ)
            shell.addChild(ceiling)
        }

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

        let backGroup = Entity()
        backGroup.name = "BackWallGroup"
        let frontGroup = Entity()
        frontGroup.name = "FrontWallGroup"
        let leftGroup = Entity()
        leftGroup.name = "LeftWallGroup"
        let rightGroup = Entity()
        rightGroup.name = "RightWallGroup"

        for segment in snapshot.wallSegments {
            let dx = segment.endX - segment.startX
            let dz = segment.endZ - segment.startZ
            let segLength = hypot(dx, dz)
            guard segLength > 0.1 else { continue }

            let midX = (segment.startX + segment.endX) / 2.0
            let midZ = (segment.startZ + segment.endZ) / 2.0
            let segH = max(Float(height), segment.height)
            let angle = -atan2(dz, dx)

            let wallContainer = Entity()
            wallContainer.position = SIMD3<Float>(midX, 0, midZ)
            wallContainer.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))

            let wallMesh = MeshResource.generateBox(size: SIMD3<Float>(segLength, segH, wallThickness))
            let wallEntity = ModelEntity(mesh: wallMesh, materials: [wallMaterial])
            wallEntity.position = SIMD3<Float>(0, segH / 2.0, 0)
            wallContainer.addChild(wallEntity)

            let baseboardMesh = MeshResource.generateBox(size: SIMD3<Float>(segLength, 0.08, wallThickness + 0.016))
            let baseboard = ModelEntity(mesh: baseboardMesh, materials: [trimMaterial])
            baseboard.position = SIMD3<Float>(0, 0.04, 0)
            wallContainer.addChild(baseboard)

            // Assign to cardinal cutaway group based on vector from room center to wall midpoint
            let relX = midX - centerX
            let relZ = midZ - centerZ
            if abs(relZ) >= abs(relX) {
                if relZ < 0 {
                    backGroup.addChild(wallContainer)
                } else {
                    frontGroup.addChild(wallContainer)
                }
            } else {
                if relX < 0 {
                    leftGroup.addChild(wallContainer)
                } else {
                    rightGroup.addChild(wallContainer)
                }
            }
        }

        // Add subtle visual markers for real scanned doors/windows (no forced fake openings)
        var glassMaterial = PhysicallyBasedMaterial()
        glassMaterial.baseColor.tint = UIColor(red: 0.78, green: 0.88, blue: 0.96, alpha: 0.45)
        glassMaterial.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: 0.1)
        glassMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.45))

        let doorMaterial = SimpleMaterial(
            color: UIColor(red: 0.45, green: 0.31, blue: 0.21, alpha: 1.0),
            roughness: 0.45,
            isMetallic: false
        )

        var passageMaterial = PhysicallyBasedMaterial()
        passageMaterial.baseColor.tint = UIColor(red: 0.88, green: 0.86, blue: 0.82, alpha: 0.28)
        passageMaterial.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: 0.8)
        passageMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.28))

        for opening in snapshot.openings {
            let material: any RealityKit.Material
            switch opening.type {
            case "window":
                material = glassMaterial
            case "opening":
                material = passageMaterial
            default:
                material = doorMaterial
            }
            let mesh = MeshResource.generateBox(size: SIMD3<Float>(opening.width, opening.height, wallThickness + 0.02))
            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position = SIMD3<Float>(opening.centerX, opening.bottomY + opening.height / 2.0, opening.centerZ)
            entity.orientation = simd_quatf(angle: opening.yaw, axis: SIMD3<Float>(0, 1, 0))

            let relX = opening.centerX - centerX
            let relZ = opening.centerZ - centerZ
            if abs(relZ) >= abs(relX) {
                if relZ < 0 { backGroup.addChild(entity) } else { frontGroup.addChild(entity) }
            } else {
                if relX < 0 { leftGroup.addChild(entity) } else { rightGroup.addChild(entity) }
            }
        }

        shell.addChild(backGroup)
        shell.addChild(frontGroup)
        shell.addChild(leftGroup)
        shell.addChild(rightGroup)
        return shell
    }

    /// Shared ceiling geometry; viewports may use it as a visually cutaway shadow occluder.
    public static func buildCeiling(width: Double, length: Double, height: Double) -> ModelEntity {
        let roomW = Float(width)
        let roomL = Float(length)
        let roomH = Float(height)
        let ceilingMesh = MeshResource.generateBox(
            size: SIMD3<Float>(roomW, 0.02, roomL),
            cornerRadius: 0.005
        )
        let ceilingMaterial = SimpleMaterial(
            color: UIColor(red: 0.96, green: 0.96, blue: 0.95, alpha: 1.0),
            roughness: 0.90,
            isMetallic: false
        )
        let ceilingEntity = ModelEntity(mesh: ceilingMesh, materials: [ceilingMaterial])
        ceilingEntity.name = "Ceiling"
        ceilingEntity.position = SIMD3<Float>(0, roomH + 0.01, 0)
        return ceilingEntity
    }

    /// Value-based entry point for immutable viewport snapshots.
    public static func buildShell(width: Double, length: Double, height: Double,
                                  includeCeiling: Bool = false) -> Entity {
        let shell = Entity()
        shell.name = "RoomShell"

        let roomW = Float(width)
        let roomL = Float(length)
        let roomH = Float(height)
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

        // Architectural Drywall & Trim Materials
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
        var glassMaterial = PhysicallyBasedMaterial()
        glassMaterial.baseColor.tint = UIColor(red: 0.85, green: 0.92, blue: 0.98, alpha: 0.25)
        glassMaterial.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: 0.05)
        glassMaterial.metallic = PhysicallyBasedMaterial.Metallic(floatLiteral: 0.1)
        glassMaterial.blending = .transparent(opacity: .init(floatLiteral: 0.25))
        let doorFrameMaterial = SimpleMaterial(
            color: UIColor(red: 0.38, green: 0.26, blue: 0.18, alpha: 1.0),
            roughness: 0.40,
            isMetallic: false
        )

        let baseboardH: Float = 0.08
        let baseboardThickness: Float = 0.015

        // Optional Dynamic Ceiling Plane
        if includeCeiling {
            shell.addChild(buildCeiling(width: width, length: length, height: height))
        }

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

        // Window Glass Pane (PhysicallyBased Transparent)
        let glassMesh = MeshResource.generateBox(
            size: SIMD3<Float>(windowW, windowH, 0.005),
            cornerRadius: 0.002
        )
        let glass = ModelEntity(mesh: glassMesh, materials: [glassMaterial])
        glass.position = SIMD3<Float>(0, sillH + (windowH / 2.0), backWallZ)
        backWallGroup.addChild(glass)

        // Architectural Hollow Frame Casing (Perimeter Border + Grid Mullions)
        let frameCasing = Entity()
        frameCasing.name = "WindowFrameCasing"
        let casingThickness: Float = 0.04
        let casingDepth: Float = 0.03

        // Top Frame
        let topFrameMesh = MeshResource.generateBox(size: SIMD3<Float>(windowW + casingThickness * 2, casingThickness, casingDepth))
        let topFrame = ModelEntity(mesh: topFrameMesh, materials: [windowFrameMaterial])
        topFrame.position = SIMD3<Float>(0, sillH + windowH + (casingThickness / 2.0), backWallZ)
        frameCasing.addChild(topFrame)

        // Bottom Frame
        let bottomFrameMesh = MeshResource.generateBox(size: SIMD3<Float>(windowW + casingThickness * 2, casingThickness, casingDepth))
        let bottomFrame = ModelEntity(mesh: bottomFrameMesh, materials: [windowFrameMaterial])
        bottomFrame.position = SIMD3<Float>(0, sillH - (casingThickness / 2.0), backWallZ)
        frameCasing.addChild(bottomFrame)

        // Left Frame
        let leftFrameMesh = MeshResource.generateBox(size: SIMD3<Float>(casingThickness, windowH, casingDepth))
        let leftFrame = ModelEntity(mesh: leftFrameMesh, materials: [windowFrameMaterial])
        leftFrame.position = SIMD3<Float>(-(windowW / 2.0) - (casingThickness / 2.0), sillH + (windowH / 2.0), backWallZ)
        frameCasing.addChild(leftFrame)

        // Right Frame
        let rightFrameMesh = MeshResource.generateBox(size: SIMD3<Float>(casingThickness, windowH, casingDepth))
        let rightFrame = ModelEntity(mesh: rightFrameMesh, materials: [windowFrameMaterial])
        rightFrame.position = SIMD3<Float>((windowW / 2.0) + (casingThickness / 2.0), sillH + (windowH / 2.0), backWallZ)
        frameCasing.addChild(rightFrame)

        // Vertical Center Mullion
        let vertMullionMesh = MeshResource.generateBox(size: SIMD3<Float>(0.025, windowH, casingDepth * 0.8))
        let vertMullion = ModelEntity(mesh: vertMullionMesh, materials: [windowFrameMaterial])
        vertMullion.position = SIMD3<Float>(0, sillH + (windowH / 2.0), backWallZ)
        frameCasing.addChild(vertMullion)

        // Horizontal Center Transom
        let horizMullionMesh = MeshResource.generateBox(size: SIMD3<Float>(windowW, 0.025, casingDepth * 0.8))
        let horizMullion = ModelEntity(mesh: horizMullionMesh, materials: [windowFrameMaterial])
        horizMullion.position = SIMD3<Float>(0, sillH + (windowH / 2.0), backWallZ)
        frameCasing.addChild(horizMullion)

        backWallGroup.addChild(frameCasing)

        let backBaseboardLeftMesh = MeshResource.generateBox(size: SIMD3<Float>(sideW, baseboardH, baseboardThickness))
        let backBaseboardLeft = ModelEntity(mesh: backBaseboardLeftMesh, materials: [trimMaterial])
        backBaseboardLeft.position = SIMD3<Float>(-halfW + (sideW / 2.0), baseboardH / 2.0, -halfL + (baseboardThickness / 2.0))
        backWallGroup.addChild(backBaseboardLeft)

        let backBaseboardRightMesh = MeshResource.generateBox(size: SIMD3<Float>(sideW, baseboardH, baseboardThickness))
        let backBaseboardRight = ModelEntity(mesh: backBaseboardRightMesh, materials: [trimMaterial])
        backBaseboardRight.position = SIMD3<Float>(halfW - (sideW / 2.0), baseboardH / 2.0, -halfL + (baseboardThickness / 2.0))
        backWallGroup.addChild(backBaseboardRight)

        shell.addChild(backWallGroup)

        // 2. Left Wall Group (Full Solid Drywall + Baseboard)
        let leftWallGroup = Entity()
        leftWallGroup.name = "LeftWallGroup"

        let leftWallMesh = MeshResource.generateBox(size: SIMD3<Float>(wallThickness, roomH, roomL))
        let leftWall = ModelEntity(mesh: leftWallMesh, materials: [wallMaterial])
        leftWall.position = SIMD3<Float>(-halfW - (wallThickness / 2.0), roomH / 2.0, 0)
        leftWallGroup.addChild(leftWall)

        let leftBaseboardMesh = MeshResource.generateBox(size: SIMD3<Float>(baseboardThickness, baseboardH, roomL))
        let leftBaseboard = ModelEntity(mesh: leftBaseboardMesh, materials: [trimMaterial])
        leftBaseboard.position = SIMD3<Float>(-halfW + (baseboardThickness / 2.0), baseboardH / 2.0, 0)
        leftWallGroup.addChild(leftBaseboard)

        shell.addChild(leftWallGroup)

        // 3. Right Wall Group (Full Solid Drywall + Baseboard)
        let rightWallGroup = Entity()
        rightWallGroup.name = "RightWallGroup"

        let rightWallMesh = MeshResource.generateBox(size: SIMD3<Float>(wallThickness, roomH, roomL))
        let rightWall = ModelEntity(mesh: rightWallMesh, materials: [wallMaterial])
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
}
