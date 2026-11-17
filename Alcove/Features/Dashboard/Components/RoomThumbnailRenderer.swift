import Foundation
import RealityKit
import SwiftUI
import UIKit
import simd

/// Renders an isometric 3D dollhouse snapshot of a `Room` with its preloaded procedural furniture
/// for use as the `DashboardView` room card thumbnail.
@MainActor
public enum RoomThumbnailRenderer {

    /// Captures a PNG snapshot of the room shell + active furniture from a warm isometric angle.
    public static func renderThumbnailData(
        for room: Room,
        size: CGSize = CGSize(width: 640, height: 420)
    ) async -> Data? {
        let arView = ARView(
            frame: CGRect(origin: .zero, size: size),
            cameraMode: .nonAR,
            automaticallyConfigureSession: false
        )
        let bgColor = UIColor(named: "AlcoveSurfaceElevated") ?? UIColor(red: 0.996, green: 0.965, blue: 0.929, alpha: 1.0)
        arView.environment.background = .color(bgColor)
        arView.renderOptions.insert([.disableMotionBlur, .disableDepthOfField])

        let root = Entity()
        root.components.set(EnvironmentLightingConfigurationComponent(environmentLightingWeight: 0))
        root.components.set(ImageBasedLightComponent(source: .none))
        root.components.set(ImageBasedLightReceiverComponent(imageBasedLight: root))

        // Directional key light + soft fill
        let sun = DirectionalLight()
        sun.light.intensity = 2600
        sun.light.color = .init(red: 1.0, green: 0.96, blue: 0.90, alpha: 1.0)
        sun.look(at: .zero, from: [1.5, 4.0, -3.0], relativeTo: root)
        root.addChild(sun)

        let fill = DirectionalLight()
        fill.light.intensity = 1200
        fill.light.color = .init(red: 0.93, green: 0.95, blue: 1.0, alpha: 1.0)
        fill.look(at: .zero, from: [-2.5, 3.5, 2.5], relativeTo: root)
        root.addChild(fill)

        // Room shell + cutaway front/side walls for clear dollhouse view
        let shell = ProceduralRoomShellBuilder.buildShell(for: room, includeCeiling: false)
        root.addChild(shell)

        // Preloaded procedural furniture matching the scanned room
        let layout = room.workingLayout ?? room.baselineLayout
        for item in (layout?.furnitures ?? []) where !item.isArchived {
            let entity = ProceduralFurnitureBuilder.buildDetailedEntity(for: item)
            entity.position = SIMD3<Float>(Float(item.positionX), Float(item.positionY), Float(item.positionZ))
            entity.orientation = simd_quatf(angle: Float(item.rotationYaw), axis: SIMD3<Float>(0, 1, 0))
            root.addChild(entity)
        }

        // Isometric camera
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 38
        let span = Float(max(room.dimensionsWidth, room.dimensionsLength, 3.2))
        let distance = min(14.0, max(5.2, span * 1.45))
        let yaw: Float = .pi * 0.22
        let pitch: Float = 0.68
        let target = SIMD3<Float>(0, Float(room.dimensionsHeight) * 0.25, 0)
        let offset = SIMD3<Float>(
            distance * cos(pitch) * sin(yaw),
            distance * sin(pitch),
            distance * cos(pitch) * cos(yaw)
        )
        camera.look(at: target, from: target + offset, relativeTo: nil)
        root.addChild(camera)

        // Hide camera-facing walls so furniture inside the dollhouse is visible
        let orientation = simd_quatf(angle: pitch, axis: [1, 0, 0]) * simd_quatf(angle: -yaw, axis: [0, 1, 0])
        let wallGroups: [(String, SIMD3<Float>)] = [
            ("FrontWallGroup", WallCutawayEvaluator.frontNormal),
            ("BackWallGroup", WallCutawayEvaluator.backNormal),
            ("LeftWallGroup", WallCutawayEvaluator.leftNormal),
            ("RightWallGroup", WallCutawayEvaluator.rightNormal)
        ]
        for (name, normal) in wallGroups {
            if let wall = shell.findEntity(named: name),
               WallCutawayEvaluator.isWallHidden(wallNormal: normal, orientation: orientation, pitch: pitch) {
                wall.isEnabled = false
            }
        }

        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(root)
        arView.scene.addAnchor(anchor)
        arView.layoutIfNeeded()

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                arView.snapshot(saveToHDR: false) { image in
                    let data = image?.pngData()
                    arView.scene.anchors.removeAll()
                    continuation.resume(returning: data)
                }
            }
        }
    }
}
