import SwiftUI
import RealityKit
import ARKit
import Combine

/// 1:1 Life-Size AR Viewport wrapping RealityKit's `ARView(cameraMode: .ar)`.
/// Anchors the room on the physical floor plane with dynamic ceiling cutaways,
/// inward wall lighting, and physical placement reticle.
public struct ARWalkthroughViewport: UIViewRepresentable {
    public let room: Room
    public let viewModel: ARWalkthroughViewModel

    public init(room: Room, viewModel: ARWalkthroughViewModel) {
        self.room = room
        self.viewModel = viewModel
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(room: room, viewModel: viewModel)
    }

    public func makeUIView(context: Context) -> WalkthroughARView {
        let arView = WalkthroughARView(frame: .zero)
        arView.environment.background = .cameraFeed()

        context.coordinator.setup(in: arView)
        return arView
    }

    public func updateUIView(_ arView: WalkthroughARView, context: Context) {
        context.coordinator.syncPlacement()
        if arView.window != nil {
            context.coordinator.startSessionOnce(in: arView)
        }
    }

    public static func dismantleUIView(_ arView: WalkthroughARView, coordinator: Coordinator) {
        coordinator.teardown(in: arView)
    }

    // MARK: - Coordinator

    @MainActor
    public final class Coordinator: NSObject, ARSessionDelegate {
        weak var arView: ARView?
        let room: Room
        let viewModel: ARWalkthroughViewModel

        private var updateSubscription: (any Cancellable)?
        private var reticleEntity: ModelEntity?
        private var roomAnchor: AnchorEntity?
        private var roomShellEntity: Entity?
        private var isSessionRunning = false

        init(room: Room, viewModel: ARWalkthroughViewModel) {
            self.room = room
            self.viewModel = viewModel
            super.init()
        }

        func setup(in arView: WalkthroughARView) {
            self.arView = arView

            // Start session once window and metal pipeline are attached
            arView.onWindowAttached = { [weak self, weak arView] in
                guard let self, let arView else { return }
                self.startSessionOnce(in: arView)
            }

            if !ARWorldTrackingConfiguration.isSupported {
                // Simulator fallback: simulate placement candidate in front of camera
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.viewModel.updateCandidateHit(position: SIMD3<Float>(0, -0.4, -2.0))
                }
            } else if arView.window != nil {
                startSessionOnce(in: arView)
            }

            // Create Visual Placement Reticle
            setupPlacementReticle(in: arView)

            // Setup Tap Gesture for room placement
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            arView.addGestureRecognizer(tapGesture)

            // Frame Update Subscription: syncs reticle raycasting, ceiling occlusion & wall cutaways
            updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
                self?.onFrameUpdate()
            }
        }

        func startSessionOnce(in arView: ARView) {
            guard ARWorldTrackingConfiguration.isSupported else { return }
            guard !isSessionRunning else { return }

            let config = ARWorldTrackingConfiguration()
            config.planeDetection = [.horizontal]
            config.environmentTexturing = .automatic
            config.isLightEstimationEnabled = true
            arView.session.delegate = self
            arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            isSessionRunning = true
        }

        func teardown(in arView: ARView) {
            updateSubscription?.cancel()
            updateSubscription = nil
            isSessionRunning = false
            arView.session.pause()
            arView.scene.anchors.removeAll()
        }

        // MARK: - ARSessionDelegate

        public func session(_ session: ARSession, didFailWithError error: Error) {
            let nsError = error as NSError
            viewModel.sessionErrorMessage = "AR Error: \(error.localizedDescription) (\(nsError.code))"
        }

        public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            switch camera.trackingState {
            case .notAvailable:
                viewModel.trackingStatusMessage = "Tracking unavailable"
            case .limited(let reason):
                switch reason {
                case .initializing:
                    viewModel.trackingStatusMessage = "Initializing AR..."
                case .excessiveMotion:
                    viewModel.trackingStatusMessage = "Move iPad slower"
                case .insufficientFeatures:
                    viewModel.trackingStatusMessage = "Point at textured surface"
                case .relocalizing:
                    viewModel.trackingStatusMessage = "Relocalizing..."
                @unknown default:
                    viewModel.trackingStatusMessage = "Tracking limited"
                }
            case .normal:
                viewModel.trackingStatusMessage = nil
            }
        }

        public func sessionWasInterrupted(_ session: ARSession) {
            viewModel.trackingStatusMessage = "AR Session interrupted"
        }

        public func sessionInterruptionEnded(_ session: ARSession) {
            viewModel.trackingStatusMessage = nil
        }

        private func setupPlacementReticle(in arView: ARView) {
            let reticleMesh = MeshResource.generatePlane(width: 0.60, depth: 0.60, cornerRadius: 0.30)
            let reticleMat = SimpleMaterial(
                color: UIColor.systemBlue.withAlphaComponent(0.65),
                roughness: 0.2,
                isMetallic: false
            )
            let reticle = ModelEntity(mesh: reticleMesh, materials: [reticleMat])
            reticle.name = "PlacementReticle"
            reticle.isEnabled = false

            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(reticle)
            arView.scene.addAnchor(anchor)
            self.reticleEntity = reticle
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView else { return }
            guard !viewModel.isPlaced else { return }

            if case .readyToPlace(let position, _) = viewModel.placementState {
                anchorRoomAt(position: position)
            } else {
                // Raycast center
                let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
                if let hitPos = performFloorRaycast(from: center) {
                    anchorRoomAt(position: hitPos)
                }
            }
        }

        public func anchorRoomAt(position: SIMD3<Float>) {
            guard let arView else { return }
            viewModel.anchorRoom(at: position)

            // Remove existing room anchor if repositioning
            if let existing = roomAnchor {
                arView.scene.removeAnchor(existing)
            }

            // Build Room Anchor
            let anchor = AnchorEntity(world: position)
            anchor.orientation = simd_quatf(angle: viewModel.roomRotationYaw, axis: SIMD3<Float>(0, 1, 0))

            // Build 1:1 Room Shell with Dynamic Ceiling
            let shell = ProceduralRoomShellBuilder.buildShell(for: room, includeCeiling: true)
            anchor.addChild(shell)
            self.roomShellEntity = shell

            // Build Furniture items from working layout
            let furnitureGroup = Entity()
            furnitureGroup.name = "FurnitureGroup"
            let layout = room.workingLayout ?? room.baselineLayout
            if let layout {
                for item in layout.furnitures where !item.isArchived {
                    let entity = buildFurnitureEntity(for: item)
                    furnitureGroup.addChild(entity)
                }
            }
            anchor.addChild(furnitureGroup)

            // Realistic Directional Sun Pouring Through Window in 1:1 AR
            let sun = DirectionalLight()
            sun.name = "ARSunLight"
            sun.light.intensity = 2400
            sun.light.color = .init(red: 1.0, green: 0.96, blue: 0.90, alpha: 1.0)
            sun.look(at: .zero, from: [2.0, 3.5, -3.5], relativeTo: anchor)
            anchor.addChild(sun)

            arView.scene.addAnchor(anchor)
            self.roomAnchor = anchor

            reticleEntity?.isEnabled = false
            AudioServicesPlaySystemSound(1104)
        }

        private func buildFurnitureEntity(for item: Furniture) -> Entity {
            let container = Entity()
            container.name = "Furniture_\(item.id.uuidString)"
            container.position = SIMD3<Float>(Float(item.positionX), Float(item.positionY), Float(item.positionZ))
            container.orientation = simd_quatf(angle: Float(item.rotationYaw), axis: SIMD3<Float>(0, 1, 0))

            let model = ProceduralFurnitureBuilder.buildDetailedEntity(for: item)
            container.addChild(model)
            return container
        }

        func syncPlacement() {
            if !viewModel.isPlaced {
                // If reset to repositioning, remove placed room anchor
                if let existing = roomAnchor, let arView {
                    arView.scene.removeAnchor(existing)
                    roomAnchor = nil
                    roomShellEntity = nil
                }
            } else if let roomAnchor {
                roomAnchor.orientation = simd_quatf(angle: viewModel.roomRotationYaw, axis: SIMD3<Float>(0, 1, 0))
            }
        }

        private func onFrameUpdate() {
            guard let arView else { return }

            // If not yet placed, raycast floor for reticle
            if !viewModel.isPlaced {
                let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
                if let floorHit = performFloorRaycast(from: center) {
                    reticleEntity?.isEnabled = true
                    reticleEntity?.position = floorHit
                    viewModel.updateCandidateHit(position: floorHit)
                }
                return
            }

            // Once placed: evaluate Dynamic Ceiling & Wall Cutaways
            guard let roomAnchor, let shell = roomShellEntity else { return }

            let camTransform = arView.cameraTransform
            let camWorldPos = camTransform.translation

            let localCam = ARPlacementEngine.worldToLocal(
                worldPoint: camWorldPos,
                roomWorldPosition: roomAnchor.position,
                roomRotationYaw: viewModel.roomRotationYaw
            )

            viewModel.updateCameraPresence(localCameraPosition: localCam)

            let roomW = Float(room.dimensionsWidth)
            let roomL = Float(room.dimensionsLength)
            let roomH = Float(room.dimensionsHeight)

            // 1. Dynamic Ceiling Cutaway
            if let ceiling = shell.children.first(where: { $0.name == "Ceiling" }) {
                let hideCeiling = CeilingCutawayEvaluator.isCeilingHidden(
                    localCameraPosition: localCam,
                    roomWidth: roomW,
                    roomLength: roomL,
                    roomHeight: roomH
                )
                ceiling.isEnabled = !hideCeiling
            }

            // 2. Dynamic Wall Cutaways (when stepped outside room)
            let isInside = CeilingCutawayEvaluator.isCameraInsideRoom(
                localCameraPosition: localCam,
                roomWidth: roomW,
                roomLength: roomL,
                roomHeight: roomH
            )

            let walls: [(name: String, normal: SIMD3<Float>)] = [
                ("FrontWallGroup", WallCutawayEvaluator.frontNormal),
                ("BackWallGroup", WallCutawayEvaluator.backNormal),
                ("LeftWallGroup", WallCutawayEvaluator.leftNormal),
                ("RightWallGroup", WallCutawayEvaluator.rightNormal)
            ]

            for wall in walls {
                if let entity = shell.children.first(where: { $0.name == wall.name }) {
                    if isInside {
                        // User is inside: all walls surrounding user are visible
                        entity.isEnabled = true
                    } else {
                        // User is outside: cut away wall facing the camera
                        let toCamLocal = simd_normalize(localCam)
                        let dot = simd_dot(wall.normal, toCamLocal)
                        entity.isEnabled = (dot <= WallCutawayEvaluator.cutoff)
                    }
                }
            }
        }

        private func performFloorRaycast(from screenPoint: CGPoint) -> SIMD3<Float>? {
            guard let arView else { return nil }

            if ARWorldTrackingConfiguration.isSupported {
                let results = arView.raycast(from: screenPoint, allowing: .estimatedPlane, alignment: .horizontal)
                if let first = results.first {
                    let hitPos = SIMD3<Float>(
                        first.worldTransform.columns.3.x,
                        first.worldTransform.columns.3.y,
                        first.worldTransform.columns.3.z
                    )
                    if ARPlacementEngine.isValidPlacementDistance(cameraPosition: arView.cameraTransform.translation, hitPosition: hitPos) {
                        return hitPos
                    }
                }
            } else {
                // Simulator fallback horizontal plane at y = -0.4
                return SIMD3<Float>(0, -0.4, -2.0)
            }
            return nil
        }
    }
}

/// Custom RealityKit ARView subclass that coordinates session lifecycle with UIWindow presentation,
/// ensuring the view has established non-zero Metal frame bounds before ARKit camera frame streaming starts.
public final class WalkthroughARView: ARView {
    var onWindowAttached: (() -> Void)?

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            onWindowAttached?()
        }
    }
}
