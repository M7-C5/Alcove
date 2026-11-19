import Foundation
import RealityKit
import SwiftUI
import UIKit
import simd

/// Renders the live 3D RealityKit dollhouse model (room shell + preloaded procedural furniture)
/// at the default dollhouse camera angle (`yaw: 0`, `pitch: 0.62`) for `DashboardView` cards.
public struct RoomThumbnail3DView: UIViewRepresentable {
    public let room: Room
    public var onSnapshot: ((UIImage) -> Void)?

    public init(room: Room, onSnapshot: ((UIImage) -> Void)? = nil) {
        self.room = room
        self.onSnapshot = onSnapshot
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        let bg = UIColor(named: "AlcoveSurfaceElevated") ?? UIColor(red: 0.996, green: 0.965, blue: 0.929, alpha: 1.0)
        view.environment.background = .color(bg)
        view.renderOptions.insert([.disableMotionBlur, .disableDepthOfField])
        view.isUserInteractionEnabled = false

        context.coordinator.onSnapshot = onSnapshot
        context.coordinator.install(in: view, room: room)
        return view
    }

    public func updateUIView(_ view: ARView, context: Context) {
        context.coordinator.onSnapshot = onSnapshot
        context.coordinator.syncIfNeeded(in: view, room: room)
    }

    public static func dismantleUIView(_ view: ARView, coordinator: Coordinator) {
        coordinator.cancelPendingSnapshot()
        view.scene.anchors.removeAll()
    }

    @MainActor
    public final class Coordinator {
        private let root = Entity()
        private let furnitureGroup = Entity()
        private var lastFingerprint: String = ""
        private var snapshotTask: Task<Void, Never>?
        var onSnapshot: ((UIImage) -> Void)?

        func install(in view: ARView, room: Room) {
            root.name = "ThumbnailRoot"
            root.components.set(EnvironmentLightingConfigurationComponent(environmentLightingWeight: 0))
            root.components.set(ImageBasedLightComponent(source: .none))
            root.components.set(ImageBasedLightReceiverComponent(imageBasedLight: root))

            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(root)
            view.scene.addAnchor(anchor)

            rebuildScene(for: room)
            scheduleSnapshot(in: view)
        }

        func syncIfNeeded(in view: ARView, room: Room) {
            let fp = RoomThumbnailRenderer.layoutFingerprint(for: room)
            guard fp != lastFingerprint else { return }
            rebuildScene(for: room)
            scheduleSnapshot(in: view)
        }

        func cancelPendingSnapshot() {
            snapshotTask?.cancel()
            snapshotTask = nil
        }

        private func scheduleSnapshot(in view: ARView) {
            guard onSnapshot != nil else { return }
            snapshotTask?.cancel()
            snapshotTask = Task { @MainActor [weak self, weak view] in
                try? await Task.sleep(nanoseconds: 280_000_000)
                guard !Task.isCancelled, let self, let view, view.window != nil, view.bounds.width > 1 else { return }
                view.snapshot(saveToHDR: false) { [weak self] image in
                    guard let image else { return }
                    Task { @MainActor in
                        self?.onSnapshot?(image)
                    }
                }
            }
        }

        private func rebuildScene(for room: Room) {
            lastFingerprint = RoomThumbnailRenderer.layoutFingerprint(for: room)
            root.children.removeAll()
            furnitureGroup.children.removeAll()

            // Isometric 45° corner angle so both front and right walls cut away cleanly
            let camera = PerspectiveCamera()
            camera.camera.fieldOfViewInDegrees = 40
            camera.camera.near = 0.1
            camera.camera.far = 60

            let yaw: Float = .pi / 4.0
            let pitch: Float = 0.62
            let span = Float(max(room.dimensionsWidth, room.dimensionsLength, 3.0))
            let distance = min(12.0, max(3.6, span * 0.95))
            let target = SIMD3<Float>(0, Float(room.dimensionsHeight) * 0.28, 0)
            let offset = SIMD3<Float>(
                distance * cos(pitch) * sin(yaw),
                distance * sin(pitch),
                distance * cos(pitch) * cos(yaw)
            )
            camera.look(at: target, from: target + offset, relativeTo: nil)
            root.addChild(camera)

            // Directional sun + soft ambient fill matching Studio3DViewport
            let halfL = Float(room.dimensionsLength) / 2.0
            let windowCenterY: Float = 0.85 + (1.30 / 2.0)
            let windowZ: Float = -halfL

            let sun = DirectionalLight()
            sun.light.intensity = 2800
            sun.light.color = .init(red: 1.0, green: 0.96, blue: 0.90, alpha: 1.0)
            sun.look(at: SIMD3<Float>(-0.2, 0.0, windowZ + halfL * 0.9), from: SIMD3<Float>(0.4, windowCenterY + 0.9, windowZ - 2.5), relativeTo: root)
            root.addChild(sun)

            let fill = DirectionalLight()
            fill.light.intensity = 1100
            fill.light.color = .init(red: 0.92, green: 0.95, blue: 1.0, alpha: 1.0)
            fill.look(at: .zero, from: [-2.0, 3.5, 2.5], relativeTo: root)
            root.addChild(fill)

            // Room shell + cutaway front wall
            let shell = ProceduralRoomShellBuilder.buildShell(for: room, includeCeiling: false)
            root.addChild(shell)

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
                    if #available(iOS 18.0, *) {
                        wall.components.set(OpacityComponent(opacity: 0.0))
                    } else {
                        wall.isEnabled = false
                    }
                }
            }

            // Preloaded 3D procedural furniture
            furnitureGroup.name = "ThumbnailFurnitureGroup"
            let layout = room.workingLayout ?? room.baselineLayout
            for item in (layout?.furnitures ?? []) where !item.isArchived {
                let entity = ProceduralFurnitureBuilder.buildDetailedEntity(for: item)
                entity.position = SIMD3<Float>(Float(item.positionX), Float(item.positionY), Float(item.positionZ))
                entity.orientation = simd_quatf(angle: Float(item.rotationYaw), axis: SIMD3<Float>(0, 1, 0))
                furnitureGroup.addChild(entity)
            }
            root.addChild(furnitureGroup)
        }
    }
}

/// Layout fingerprint helper used to detect when a room's 3D thumbnail needs refreshing.
@MainActor
public enum RoomThumbnailRenderer {
    public static func layoutFingerprint(for room: Room) -> String {
        let layout = room.workingLayout ?? room.baselineLayout
        let items = (layout?.furnitures ?? [])
            .filter { !$0.isArchived }
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { item in
                String(
                    format: "%@:%@:%.2f,%.2f,%.2f:%.2f:%.2f,%.2f,%.2f",
                    item.id.uuidString,
                    item.categoryRaw,
                    item.positionX,
                    item.positionY,
                    item.positionZ,
                    item.rotationYaw,
                    item.width,
                    item.length,
                    item.height
                )
            }
            .joined(separator: "|")
        return String(
            format: "%.2fx%.2fx%.2f|%@",
            room.dimensionsWidth,
            room.dimensionsLength,
            room.dimensionsHeight,
            items
        )
    }
}
