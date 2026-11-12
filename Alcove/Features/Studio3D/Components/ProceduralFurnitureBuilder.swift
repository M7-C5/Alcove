import RealityKit
import UIKit
import simd

/// Procedural architectural 3D geometry builder for Alcove furniture entities in RealityKit.
/// Constructs realistic multi-part meshes (frames, legs, cushions, pulls, shades) in pure code.
@MainActor
public struct ProceduralFurnitureBuilder {

    // MARK: - Reusable Materials
    private static let walnutWood = SimpleMaterial(
        color: UIColor(red: 0.42, green: 0.28, blue: 0.18, alpha: 1.0),
        roughness: 0.40,
        isMetallic: false
    )

    private static let oakWood = SimpleMaterial(
        color: UIColor(red: 0.72, green: 0.58, blue: 0.42, alpha: 1.0),
        roughness: 0.45,
        isMetallic: false
    )

    private static let whiteLacquer = SimpleMaterial(
        color: UIColor(red: 0.94, green: 0.94, blue: 0.93, alpha: 1.0),
        roughness: 0.22,
        isMetallic: false
    )

    private static let mattressFabric = SimpleMaterial(
        color: UIColor(red: 0.95, green: 0.95, blue: 0.93, alpha: 1.0),
        roughness: 0.85,
        isMetallic: false
    )

    private static let pillowFabric = SimpleMaterial(
        color: UIColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1.0),
        roughness: 0.80,
        isMetallic: false
    )

    private static let duvetFabric = SimpleMaterial(
        color: UIColor(red: 0.25, green: 0.33, blue: 0.48, alpha: 1.0),
        roughness: 0.80,
        isMetallic: false
    )

    private static let charcoalFabric = SimpleMaterial(
        color: UIColor(red: 0.22, green: 0.24, blue: 0.27, alpha: 1.0),
        roughness: 0.70,
        isMetallic: false
    )

    private static let darkMetal = SimpleMaterial(
        color: UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0),
        roughness: 0.35,
        isMetallic: true
    )

    private static let brushedBrass = SimpleMaterial(
        color: UIColor(red: 0.84, green: 0.70, blue: 0.38, alpha: 1.0),
        roughness: 0.25,
        isMetallic: true
    )

    private static let brushedAluminum = SimpleMaterial(
        color: UIColor(red: 0.84, green: 0.85, blue: 0.86, alpha: 1.0),
        roughness: 0.20,
        isMetallic: true
    )

    private static let glowingShade = UnlitMaterial(
        color: UIColor(red: 1.0, green: 0.96, blue: 0.86, alpha: 1.0)
    )

    // MARK: - Main Dispatcher

    /// Builds a detailed multi-part Entity corresponding to the furniture item.
    public static func buildDetailedEntity(for item: Furniture) -> Entity {
        buildDetailedEntity(name: item.name, category: item.category,
                            dimensions: [Float(item.width), Float(item.height), Float(item.length)])
    }

    /// Builds the same geometry from a value snapshot without retaining SwiftData models.
    public static func buildDetailedEntity(name: String, category: FurnitureCategory,
                                          dimensions: SIMD3<Float>) -> Entity {
        let root = Entity()
        root.name = "DetailedModel"

        let w = dimensions.x
        let l = dimensions.z
        let h = dimensions.y

        switch category {
        case .bed:
            root.addChild(buildBed(width: w, length: l, height: h))
        case .table:
            if name.localizedCaseInsensitiveContains("nightstand") || l < 0.6 {
                root.addChild(buildNightstand(width: w, length: l, height: h))
            } else {
                root.addChild(buildDesk(width: w, length: l, height: h))
            }
        case .seating:
            root.addChild(buildErgonomicChair(width: w, length: l, height: h))
        case .storage:
            root.addChild(buildWardrobeCupboard(width: w, length: l, height: h))
        case .lighting:
            root.addChild(buildFloorLamp(width: w, length: l, height: h))
        default:
            root.addChild(buildGenericBox(width: w, length: l, height: h))
        }

        return root
    }

    // MARK: - 1. Detailed Bed

    private static func buildBed(width w: Float, length l: Float, height h: Float) -> Entity {
        let bed = Entity()
        bed.name = "Bed"

        // 1. Headboard against back edge (Z < 0)
        let headboardH = h
        let headboardThickness: Float = 0.08
        let headboardMesh = MeshResource.generateBox(
            size: SIMD3<Float>(w, headboardH, headboardThickness),
            cornerRadius: 0.01
        )
        let headboard = ModelEntity(mesh: headboardMesh, materials: [walnutWood])
        headboard.position = SIMD3<Float>(0, headboardH / 2.0, -l / 2.0 + (headboardThickness / 2.0))
        bed.addChild(headboard)

        // 2. Bed Base Platform (Wood)
        let platformH: Float = 0.16
        let legH: Float = 0.10
        let platformL = l - headboardThickness - 0.02
        let platformMesh = MeshResource.generateBox(
            size: SIMD3<Float>(w, platformH, platformL),
            cornerRadius: 0.01
        )
        let platform = ModelEntity(mesh: platformMesh, materials: [walnutWood])
        platform.position = SIMD3<Float>(0, legH + (platformH / 2.0), (headboardThickness / 2.0))
        bed.addChild(platform)

        // 3. Four Bed Legs
        let legMesh = MeshResource.generateCylinder(height: legH, radius: 0.03)
        let legOffsets: [(Float, Float)] = [
            (-w / 2.0 + 0.08, -l / 2.0 + 0.14),
            (w / 2.0 - 0.08, -l / 2.0 + 0.14),
            (-w / 2.0 + 0.08, l / 2.0 - 0.08),
            (w / 2.0 - 0.08, l / 2.0 - 0.08)
        ]
        for (x, z) in legOffsets {
            let leg = ModelEntity(mesh: legMesh, materials: [darkMetal])
            leg.position = SIMD3<Float>(x, legH / 2.0, z)
            bed.addChild(leg)
        }

        // 4. Plush Mattress (Inset slightly)
        let mattressH: Float = 0.22
        let mattressW = w - 0.08
        let mattressL = platformL - 0.04
        let mattressMesh = MeshResource.generateBox(
            size: SIMD3<Float>(mattressW, mattressH, mattressL),
            cornerRadius: 0.03
        )
        let mattress = ModelEntity(mesh: mattressMesh, materials: [mattressFabric])
        let mattressY = legH + platformH + (mattressH / 2.0)
        mattress.position = SIMD3<Float>(0, mattressY, (headboardThickness / 2.0))
        bed.addChild(mattress)

        // 5. Twin Pillows
        let pillowW: Float = (mattressW / 2.0) - 0.08
        let pillowL: Float = 0.38
        let pillowH: Float = 0.12
        let pillowMesh = MeshResource.generateBox(
            size: SIMD3<Float>(pillowW, pillowH, pillowL),
            cornerRadius: 0.03
        )
        let pillowY = mattressY + (mattressH / 2.0) + (pillowH / 2.0) - 0.02
        let pillowZ = -l / 2.0 + headboardThickness + (pillowL / 2.0) + 0.06

        let leftPillow = ModelEntity(mesh: pillowMesh, materials: [pillowFabric])
        leftPillow.position = SIMD3<Float>(-pillowW / 2.0 - 0.03, pillowY, pillowZ)
        leftPillow.orientation = simd_quatf(angle: -0.12, axis: SIMD3<Float>(1, 0, 0))
        bed.addChild(leftPillow)

        let rightPillow = ModelEntity(mesh: pillowMesh, materials: [pillowFabric])
        rightPillow.position = SIMD3<Float>(pillowW / 2.0 + 0.03, pillowY, pillowZ)
        rightPillow.orientation = simd_quatf(angle: -0.12, axis: SIMD3<Float>(1, 0, 0))
        bed.addChild(rightPillow)

        // 6. Folded Duvet / Bedspread (Covering lower 60%)
        let duvetL = mattressL * 0.62
        let duvetH: Float = 0.04
        let duvetMesh = MeshResource.generateBox(
            size: SIMD3<Float>(mattressW + 0.02, duvetH, duvetL),
            cornerRadius: 0.02
        )
        let duvet = ModelEntity(mesh: duvetMesh, materials: [duvetFabric])
        let duvetZ = (l / 2.0) - (duvetL / 2.0) - 0.02
        duvet.position = SIMD3<Float>(0, mattressY + (mattressH / 2.0) + (duvetH / 2.0), duvetZ)
        bed.addChild(duvet)

        return bed
    }

    // MARK: - 2. Detailed Home Office Desk

    private static func buildDesk(width w: Float, length l: Float, height h: Float) -> Entity {
        let desk = Entity()
        desk.name = "Desk"

        let topThickness: Float = 0.035
        let legH = h - topThickness

        // 1. Walnut Desktop Slab
        let topMesh = MeshResource.generateBox(
            size: SIMD3<Float>(w, topThickness, l),
            cornerRadius: 0.008
        )
        let top = ModelEntity(mesh: topMesh, materials: [walnutWood])
        top.position = SIMD3<Float>(0, h - (topThickness / 2.0), 0)
        desk.addChild(top)

        // 2. Four Cylindrical Metal Legs
        let legRadius: Float = 0.02
        let legMesh = MeshResource.generateCylinder(height: legH, radius: legRadius)
        let insetX = w / 2.0 - 0.06
        let insetZ = l / 2.0 - 0.06
        let legPositions: [(Float, Float)] = [
            (-insetX, -insetZ),
            (insetX, -insetZ),
            (-insetX, insetZ),
            (insetX, insetZ)
        ]
        for (x, z) in legPositions {
            let leg = ModelEntity(mesh: legMesh, materials: [darkMetal])
            leg.position = SIMD3<Float>(x, legH / 2.0, z)
            desk.addChild(leg)
        }

        // 3. Back Modesty Panel (Strengthens structural silhouette)
        let modestyH: Float = 0.22
        let modestyThickness: Float = 0.016
        let modestyMesh = MeshResource.generateBox(
            size: SIMD3<Float>(w - 0.16, modestyH, modestyThickness),
            cornerRadius: 0.005
        )
        let modesty = ModelEntity(mesh: modestyMesh, materials: [darkMetal])
        modesty.position = SIMD3<Float>(0, h - topThickness - (modestyH / 2.0) - 0.04, -insetZ)
        desk.addChild(modesty)

        // 4. Felt Desk Mat
        let matW: Float = min(0.70, w - 0.20)
        let matL: Float = min(0.38, l - 0.15)
        let matMesh = MeshResource.generateBox(
            size: SIMD3<Float>(matW, 0.004, matL),
            cornerRadius: 0.005
        )
        let mat = ModelEntity(mesh: matMesh, materials: [charcoalFabric])
        mat.position = SIMD3<Float>(0, h + 0.002, 0.02)
        desk.addChild(mat)

        // 5. Aluminum Laptop Slab
        let laptopMesh = MeshResource.generateBox(
            size: SIMD3<Float>(0.30, 0.012, 0.21),
            cornerRadius: 0.004
        )
        let laptop = ModelEntity(mesh: laptopMesh, materials: [brushedAluminum])
        laptop.position = SIMD3<Float>(0, h + 0.01, 0.02)
        desk.addChild(laptop)

        return desk
    }

    // MARK: - 3. Detailed Ergonomic Desk Chair

    private static func buildErgonomicChair(width w: Float, length l: Float, height h: Float) -> Entity {
        let chair = Entity()
        chair.name = "Chair"

        // 1. Five-Star Caster Base
        let baseHubRadius: Float = 0.04
        let baseHubH: Float = 0.04
        let hubMesh = MeshResource.generateCylinder(height: baseHubH, radius: baseHubRadius)
        let hub = ModelEntity(mesh: hubMesh, materials: [darkMetal])
        hub.position = SIMD3<Float>(0, 0.05, 0)
        chair.addChild(hub)

        // 5 Radiating Spokes
        let spokeMesh = MeshResource.generateBox(size: SIMD3<Float>(0.03, 0.02, 0.24), cornerRadius: 0.005)
        for i in 0..<5 {
            let angle = (Float(i) / 5.0) * Float.pi * 2.0
            let spoke = ModelEntity(mesh: spokeMesh, materials: [darkMetal])
            spoke.position = SIMD3<Float>(sin(angle) * 0.12, 0.04, cos(angle) * 0.12)
            spoke.orientation = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
            chair.addChild(spoke)
        }

        // 2. Pneumatic Gas Lift Column
        let columnH: Float = 0.38
        let columnMesh = MeshResource.generateCylinder(height: columnH, radius: 0.025)
        let column = ModelEntity(mesh: columnMesh, materials: [darkMetal])
        column.position = SIMD3<Float>(0, 0.05 + (columnH / 2.0), 0)
        chair.addChild(column)

        // 3. Contoured Seat Cushion
        let seatY: Float = 0.45
        let seatMesh = MeshResource.generateBox(
            size: SIMD3<Float>(0.48, 0.07, 0.46),
            cornerRadius: 0.02
        )
        let seat = ModelEntity(mesh: seatMesh, materials: [charcoalFabric])
        seat.position = SIMD3<Float>(0, seatY, 0.02)
        chair.addChild(seat)

        // 4. Ergonomic Backrest
        let backrestH: Float = 0.44
        let backrestMesh = MeshResource.generateBox(
            size: SIMD3<Float>(0.44, backrestH, 0.035),
            cornerRadius: 0.02
        )
        let backrest = ModelEntity(mesh: backrestMesh, materials: [charcoalFabric])
        backrest.position = SIMD3<Float>(0, seatY + 0.05 + (backrestH / 2.0), -0.19)
        backrest.orientation = simd_quatf(angle: 0.08, axis: SIMD3<Float>(1, 0, 0))
        chair.addChild(backrest)

        // 5. Minimalist Loop Armrests
        let armMesh = MeshResource.generateBox(size: SIMD3<Float>(0.04, 0.18, 0.22), cornerRadius: 0.01)
        let leftArm = ModelEntity(mesh: armMesh, materials: [darkMetal])
        leftArm.position = SIMD3<Float>(-0.24, seatY + 0.10, 0.02)
        chair.addChild(leftArm)

        let rightArm = ModelEntity(mesh: armMesh, materials: [darkMetal])
        rightArm.position = SIMD3<Float>(0.24, seatY + 0.10, 0.02)
        chair.addChild(rightArm)

        return chair
    }

    // MARK: - 4. Detailed Wardrobe Cupboard

    private static func buildWardrobeCupboard(width w: Float, length l: Float, height h: Float) -> Entity {
        let wardrobe = Entity()
        wardrobe.name = "Wardrobe"

        let plinthH: Float = 0.08
        let bodyH = h - plinthH

        // 1. Recessed Base Plinth
        let plinthMesh = MeshResource.generateBox(
            size: SIMD3<Float>(w - 0.04, plinthH, l - 0.04),
            cornerRadius: 0.005
        )
        let plinth = ModelEntity(mesh: plinthMesh, materials: [darkMetal])
        plinth.position = SIMD3<Float>(0, plinthH / 2.0, 0)
        wardrobe.addChild(plinth)

        // 2. White Lacquer Main Body
        let bodyMesh = MeshResource.generateBox(
            size: SIMD3<Float>(w, bodyH, l),
            cornerRadius: 0.015
        )
        let body = ModelEntity(mesh: bodyMesh, materials: [whiteLacquer])
        let bodyY = plinthH + (bodyH / 2.0)
        body.position = SIMD3<Float>(0, bodyY, 0)
        wardrobe.addChild(body)

        // 3. Center Door Division Seam (Shadow Groove)
        let seamMesh = MeshResource.generateBox(
            size: SIMD3<Float>(0.006, bodyH - 0.04, 0.008),
            cornerRadius: 0.001
        )
        let seam = ModelEntity(mesh: seamMesh, materials: [darkMetal])
        seam.position = SIMD3<Float>(0, bodyY, (l / 2.0) + 0.002)
        wardrobe.addChild(seam)

        // 4. Two Brushed Aluminum Vertical Handles
        let handleH: Float = 0.28
        let handleRadius: Float = 0.009
        let handleMesh = MeshResource.generateCylinder(height: handleH, radius: handleRadius)

        let leftHandle = ModelEntity(mesh: handleMesh, materials: [brushedAluminum])
        leftHandle.position = SIMD3<Float>(-0.035, bodyY, (l / 2.0) + 0.02)
        wardrobe.addChild(leftHandle)

        let rightHandle = ModelEntity(mesh: handleMesh, materials: [brushedAluminum])
        rightHandle.position = SIMD3<Float>(0.035, bodyY, (l / 2.0) + 0.02)
        wardrobe.addChild(rightHandle)

        return wardrobe
    }

    // MARK: - 5. Detailed Nightstand

    private static func buildNightstand(width w: Float, length l: Float, height h: Float) -> Entity {
        let nightstand = Entity()
        nightstand.name = "Nightstand"

        let legH: Float = 0.12
        let bodyH = h - legH

        // 1. Four Slim Angled Brass Legs
        let legMesh = MeshResource.generateCylinder(height: legH, radius: 0.015)
        let insetX = w / 2.0 - 0.05
        let insetZ = l / 2.0 - 0.05
        let legPositions: [(Float, Float)] = [
            (-insetX, -insetZ),
            (insetX, -insetZ),
            (-insetX, insetZ),
            (insetX, insetZ)
        ]
        for (x, z) in legPositions {
            let leg = ModelEntity(mesh: legMesh, materials: [brushedBrass])
            leg.position = SIMD3<Float>(x, legH / 2.0, z)
            nightstand.addChild(leg)
        }

        // 2. Walnut Two-Drawer Cabinet
        let bodyMesh = MeshResource.generateBox(
            size: SIMD3<Float>(w, bodyH, l),
            cornerRadius: 0.01
        )
        let body = ModelEntity(mesh: bodyMesh, materials: [walnutWood])
        let bodyY = legH + (bodyH / 2.0)
        body.position = SIMD3<Float>(0, bodyY, 0)
        nightstand.addChild(body)

        // 3. Two Drawer Pulls (Horizontal Brass Bars)
        let pullMesh = MeshResource.generateBox(
            size: SIMD3<Float>(0.08, 0.012, 0.015),
            cornerRadius: 0.002
        )
        let topPull = ModelEntity(mesh: pullMesh, materials: [brushedBrass])
        topPull.position = SIMD3<Float>(0, bodyY + (bodyH * 0.22), (l / 2.0) + 0.01)
        nightstand.addChild(topPull)

        let bottomPull = ModelEntity(mesh: pullMesh, materials: [brushedBrass])
        bottomPull.position = SIMD3<Float>(0, bodyY - (bodyH * 0.22), (l / 2.0) + 0.01)
        nightstand.addChild(bottomPull)

        // 4. Bedside Table Lamp
        let lampBaseMesh = MeshResource.generateCylinder(height: 0.015, radius: 0.05)
        let lampBase = ModelEntity(mesh: lampBaseMesh, materials: [brushedBrass])
        let tableTopY = legH + bodyH
        lampBase.position = SIMD3<Float>(0, tableTopY + 0.0075, 0)
        nightstand.addChild(lampBase)

        let lampStemMesh = MeshResource.generateCylinder(height: 0.14, radius: 0.008)
        let lampStem = ModelEntity(mesh: lampStemMesh, materials: [brushedBrass])
        lampStem.position = SIMD3<Float>(0, tableTopY + 0.08, 0)
        nightstand.addChild(lampStem)

        let lampShadeMesh = MeshResource.generateCylinder(height: 0.11, radius: 0.075)
        let lampShade = ModelEntity(mesh: lampShadeMesh, materials: [glowingShade])
        lampShade.position = SIMD3<Float>(0, tableTopY + 0.18, 0)
        nightstand.addChild(lampShade)

        return nightstand
    }

    // MARK: - 6. Detailed Floor Lamp

    private static func buildFloorLamp(width w: Float, length l: Float, height h: Float) -> Entity {
        let lamp = Entity()
        lamp.name = "FloorLamp"

        // 1. Heavy Circular Brass Base
        let baseH: Float = 0.025
        let baseRadius: Float = min(w, l) / 2.0 - 0.02
        let baseMesh = MeshResource.generateCylinder(height: baseH, radius: baseRadius)
        let base = ModelEntity(mesh: baseMesh, materials: [brushedBrass])
        base.position = SIMD3<Float>(0, baseH / 2.0, 0)
        lamp.addChild(base)

        // 2. Slender Brass Pole
        let poleH = h - 0.28
        let poleMesh = MeshResource.generateCylinder(height: poleH, radius: 0.012)
        let pole = ModelEntity(mesh: poleMesh, materials: [brushedBrass])
        pole.position = SIMD3<Float>(0, baseH + (poleH / 2.0), 0)
        lamp.addChild(pole)

        // 3. Glowing Translucent Drum Shade
        let shadeH: Float = 0.26
        let shadeRadius: Float = baseRadius + 0.02
        let shadeMesh = MeshResource.generateCylinder(height: shadeH, radius: shadeRadius)
        let shade = ModelEntity(mesh: shadeMesh, materials: [glowingShade])
        let shadeY = h - (shadeH / 2.0)
        shade.position = SIMD3<Float>(0, shadeY, 0)
        lamp.addChild(shade)

        // 4. Functional Warm Point Light inside the shade
        let light = PointLight()
        light.name = "LampBulb"
        light.light.color = UIColor(red: 1.0, green: 0.92, blue: 0.80, alpha: 1.0)
        light.light.intensity = 850
        light.light.attenuationRadius = 3.8
        light.position = SIMD3<Float>(0, shadeY, 0)
        lamp.addChild(light)

        return lamp
    }

    // MARK: - Generic Fallback

    private static func buildGenericBox(width w: Float, length l: Float, height h: Float) -> Entity {
        let mesh = MeshResource.generateBox(size: SIMD3<Float>(w, h, l), cornerRadius: 0.02)
        let model = ModelEntity(mesh: mesh, materials: [oakWood])
        model.position = SIMD3<Float>(0, h / 2.0, 0)
        return model
    }
}
