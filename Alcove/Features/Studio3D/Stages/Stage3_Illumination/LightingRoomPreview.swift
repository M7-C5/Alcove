import SwiftUI
import RealityKit
import UIKit
import simd
import Combine

/// Immutable input: changing the clock never re-reads SwiftData or rebuilds furniture meshes.
struct LightingRoomSnapshot: Sendable {
    struct Furnishing: Sendable {
        let id: UUID
        let name: String
        let category: FurnitureCategory
        let position: SIMD3<Float>
        let dimensions: SIMD3<Float>
        let yaw: Float
    }
    let geometry: LightingRoomGeometry
    let fixtures: [LightFixture]
    let furnishings: [Furnishing]
    let compassOrientation: RoomCompassOrientation?

    @MainActor init(room: Room, fixtures draftFixtures: [LightFixture]? = nil) {
        let bounds = LightingRoomGeometry(width: room.dimensionsWidth, length: room.dimensionsLength,
                                          height: room.dimensionsHeight)
        geometry = bounds
        compassOrientation = room.compassOrientation
        let layout = room.workingLayout ?? room.baselineLayout
        fixtures = (draftFixtures ?? layout?.lightFixtures ?? []).map { bounds.clamped($0) }
        furnishings = (layout?.furnitures ?? []).filter { !$0.isArchived }.map {
            Furnishing(id: $0.id, name: $0.name, category: $0.category, position: [Float($0.positionX), Float(max(0, $0.positionY) + $0.height / 2), Float($0.positionZ)],
                       dimensions: [Float(max(0.05, $0.width)), Float(max(0.05, $0.height)), Float(max(0.05, $0.length))],
                       yaw: Float($0.rotationYaw))
        }
    }
}

struct LightingRoomPreview: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    let snapshot: LightingRoomSnapshot
    let settings: LightingSimulationSettings
    let preset: ViewportPreset
    var backgroundColor: UIColor = .init(white: 0.08, alpha: 1)
    var onPlaceLight: ((SIMD2<Float>) -> Void)?
    var onSelectLight: ((UUID) -> Void)?
    var onClearSelection: (() -> Void)?
    var onMoveLight: ((UUID, SIMD2<Float>) -> Void)?
    var isPlacementMode = false
    var selectedFixtureIDs: Set<UUID> = []
    var isSelectingMultiple = false

    func makeCoordinator() -> LightingRoomScene { LightingRoomScene(snapshot: snapshot) }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(resolvedBackground)
        view.scene.addAnchor(context.coordinator.root)
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(LightingRoomScene.orbit(_:)))
        pan.maximumNumberOfTouches = 1
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(LightingRoomScene.magnify(_:)))
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        let reset = UITapGestureRecognizer(target: context.coordinator, action: #selector(LightingRoomScene.resetCamera))
        reset.numberOfTapsRequired = 2
        view.addGestureRecognizer(reset)
        context.coordinator.panGesture = pan
        context.coordinator.pinchGesture = pinch
        context.coordinator.resetGesture = reset
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(LightingRoomScene.tapLayout(_:)))
        tap.require(toFail: reset)
        view.addGestureRecognizer(tap)
        context.coordinator.onPlaceLight = onPlaceLight
        context.coordinator.onSelectLight = onSelectLight
        context.coordinator.onClearSelection = onClearSelection
        context.coordinator.onMoveLight = onMoveLight
        context.coordinator.setPlacementMode(isPlacementMode)
        context.coordinator.setSelection(selectedFixtureIDs)
        context.coordinator.isSelectingMultiple = isSelectingMultiple
        context.coordinator.apply(settings, preset: preset, in: view)
        let coordinator = context.coordinator
        coordinator.badgeSubscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak coordinator, weak view] _ in
            guard let view else { return }
            coordinator?.updateMoveBadges(in: view)
        }
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        view.environment.background = .color(resolvedBackground)
        context.coordinator.onPlaceLight = onPlaceLight
        context.coordinator.onSelectLight = onSelectLight
        context.coordinator.onClearSelection = onClearSelection
        context.coordinator.onMoveLight = onMoveLight
        context.coordinator.setPlacementMode(isPlacementMode)
        context.coordinator.updateFixtures(snapshot.fixtures)
        context.coordinator.setSelection(selectedFixtureIDs)
        context.coordinator.isSelectingMultiple = isSelectingMultiple
        context.coordinator.apply(settings, preset: preset, in: view)
    }

    static func dismantleUIView(_ view: ARView, coordinator: LightingRoomScene) {
        coordinator.badgeSubscription?.cancel()
        coordinator.removeMoveBadges()
        view.scene.anchors.removeAll()
    }

    private var resolvedBackground: UIColor {
        backgroundColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light))
    }
}

@MainActor
final class LightingRoomScene: NSObject {
    let root = AnchorEntity(world: .zero)
    private let snapshot: LightingRoomSnapshot
    private let camera = PerspectiveCamera()
    private let sun = DirectionalLight()
    private var fixtures: [(definition: LightFixture, light: LightingFixtureLight, model: LightingFixtureModel)] = []
    private var previousSettings: LightingSimulationSettings?
    private var previousPreset: ViewportPreset?
    private var navigation = LightingCameraNavigation()
    private var walls: [(entity: Entity, normal: SIMD3<Float>)] = []
    private var fixtureDefinitions: [LightFixture] = []
    let placementOverlay = ModelEntity()
    private(set) var isPlacementMode = false
    var isSelectingMultiple = false
    weak var panGesture: UIPanGestureRecognizer?
    weak var pinchGesture: UIPinchGestureRecognizer?
    weak var resetGesture: UITapGestureRecognizer?
    var onPlaceLight: ((SIMD2<Float>) -> Void)?
    var onSelectLight: ((UUID) -> Void)?
    var onClearSelection: (() -> Void)?
    var onMoveLight: ((UUID, SIMD2<Float>) -> Void)?

    init(snapshot: LightingRoomSnapshot) {
        self.snapshot = snapshot
        super.init()
        buildRoom()
        buildPlacementOverlay()
        updateFixtures(snapshot.fixtures)
        camera.camera.fieldOfViewInDegrees = 50
        root.addChild(camera)
        sun.name = "Sunlight"
        sun.light.intensity = 0
        #if !targetEnvironment(simulator)
        let span = Float(max(snapshot.geometry.width, snapshot.geometry.length, snapshot.geometry.height))
        // A fixed projection stays anchored to the sun rather than following the camera frustum.
        sun.shadow = DirectionalLightComponent.Shadow(
            shadowProjection: .fixed(zNear: 0.01, zFar: span * 6, orthographicScale: span * 3),
            depthBias: 1
        )
        #endif
        root.addChild(sun)
    }

    func apply(_ settings: LightingSimulationSettings, preset: ViewportPreset, in view: ARView) {
        let effectivePreset: ViewportPreset = isPlacementMode ? .top : preset
        if previousPreset != effectivePreset {
            navigation.reset()
            positionCamera(effectivePreset)
            previousPreset = effectivePreset
        }
        guard previousSettings != settings else { return }
        previousSettings = settings
        let daylight = IlluminationSimulationEngine().calculateDaylight(hourOfDay: settings.hourOfDay)
        let fraction = settings.sunlightOn ? Float(daylight.intensityLux / 10000) : 0
        view.environment.lighting.intensityExponent = settings.layoutOnly || isPlacementMode ? 1 : -5 + fraction * 2
        sun.isEnabled = settings.sunlightOn && !settings.layoutOnly && !isPlacementMode && fraction > 0
        sun.light.intensity = Float(daylight.intensityLux)
        sun.light.color = color(kelvin: daylight.kelvin)
        let target: SIMD3<Float> = [0, 0, 0]
        let distance = Float(max(snapshot.geometry.width, snapshot.geometry.length, snapshot.geometry.height)) * 3
        let direction = IlluminationSimulationEngine().sunlightDirection(for: daylight, orientation: snapshot.compassOrientation)
        let source = simd_normalize(direction) * distance
        sun.look(at: target, from: source, relativeTo: root)
        let renderedIDs = settings.renderedFixtureIDs(in: fixtureDefinitions)
        for fixture in fixtures {
            let output = settings.output(for: fixture.definition)
            fixture.model.present(onPlacementLayer: isPlacementMode ? placementHeight : nil)
            fixture.light.position(at: fixture.model.emitterPosition, direction: fixture.model.emissionDirection)
            let enabled = !isPlacementMode && renderedIDs.contains(fixture.definition.id)
            fixture.light.apply(output: output, kelvin: fixture.definition.colorTemperatureKelvin, enabled: enabled)
            fixture.model.applyAppearance(output: enabled ? output : 0, kelvin: fixture.definition.colorTemperatureKelvin)
        }
    }

    private var placementHeight: Float { Float(snapshot.geometry.height) + 0.04 }

    var badgeSubscription: Cancellable?
    private var selectedIDs: Set<UUID> = []
    private var moveBadges: [UUID: UIImageView] = [:]
    private var drag: (id: UUID, height: Float, offset: SIMD2<Float>)?

    func removeMoveBadges() {
        for badge in moveBadges.values { badge.removeFromSuperview() }
        moveBadges.removeAll()
    }

    func updateMoveBadges(in view: ARView) {
        for id in Array(moveBadges.keys) where !selectedIDs.contains(id) {
            moveBadges.removeValue(forKey: id)?.removeFromSuperview()
        }
        for fixture in fixtures where selectedIDs.contains(fixture.definition.id) {
            let id = fixture.definition.id
            let badge: UIImageView
            if let existing = moveBadges[id] {
                badge = existing
            } else {
                badge = UIImageView(image: UIImage(systemName: "arrow.up.and.down.and.arrow.left.and.right"))
                badge.preferredSymbolConfiguration = .init(textStyle: .caption1)
                badge.tintColor = UIColor(named: "LightingInk") ?? .label
                badge.contentMode = .scaleAspectFit
                badge.isUserInteractionEnabled = false
                view.addSubview(badge)
                moveBadges[id] = badge
            }
            let bounds = fixture.model.root.visualBounds(relativeTo: nil)
            let corners = [bounds.min.x, bounds.max.x].flatMap { x in
                [bounds.min.y, bounds.max.y].flatMap { y in
                    [bounds.min.z, bounds.max.z].compactMap { z in view.project([x, y, z]) }
                }
            }
            if let right = corners.map(\.x).max(), let top = corners.map(\.y).min() {
                // A small hint beside the silhouette keeps the fixture itself unobstructed.
                badge.frame = CGRect(x: min(max(8, right + 8), max(8, view.bounds.width - 26)),
                                     y: min(max(8, top), max(8, view.bounds.height - 26)),
                                     width: 18, height: 18)
                badge.isHidden = false
            } else {
                badge.isHidden = true
            }
        }
    }

    func setSelection(_ ids: Set<UUID>) {
        selectedIDs = ids
        for fixture in fixtures { fixture.model.setSelected(ids.contains(fixture.definition.id)) }
    }

    func setPlacementMode(_ enabled: Bool) {
        guard isPlacementMode != enabled else { return }
        isPlacementMode = enabled
        navigation.setLocked(enabled)
        panGesture?.isEnabled = true
        pinchGesture?.isEnabled = !enabled
        resetGesture?.isEnabled = !enabled
        placementOverlay.isEnabled = enabled
        previousSettings = nil
        previousPreset = nil
    }

    private func buildPlacementOverlay() {
        var material = UnlitMaterial(applyPostProcessToneMap: false)
        material.color = .init(tint: .white)
        material.blending = .transparent(opacity: .init(floatLiteral: 0.3))
        placementOverlay.model = ModelComponent(
            mesh: .generatePlane(width: Float(snapshot.geometry.width), depth: Float(snapshot.geometry.length)),
            materials: [material]
        )
        placementOverlay.name = "LightingPlacementLayer"
        placementOverlay.position.y = placementHeight
        placementOverlay.components.set(DynamicLightShadowComponent(castsShadow: false))
        placementOverlay.isEnabled = false
        root.addChild(placementOverlay)
    }

    private func buildRoom() {
        let geometry = snapshot.geometry
        let shell = ProceduralRoomShellBuilder.buildShell(width: geometry.width, length: geometry.length,
                                                        height: geometry.height, includeCeiling: false)
        root.addChild(shell)
        let wallGroups: [(String, SIMD3<Float>)] = [
            ("FrontWallGroup", WallCutawayEvaluator.frontNormal),
            ("BackWallGroup", WallCutawayEvaluator.backNormal),
            ("LeftWallGroup", WallCutawayEvaluator.leftNormal),
            ("RightWallGroup", WallCutawayEvaluator.rightNormal)
        ]
        walls = wallGroups.compactMap { name, normal in
            shell.findEntity(named: name).map { (entity: $0, normal: normal) }
        }
        for item in snapshot.furnishings {
            let model = ProceduralFurnitureBuilder.buildDetailedEntity(name: item.name, category: item.category,
                                                                      dimensions: item.dimensions)
            model.name = "Furniture-\(item.id)"
            // Snapshot positions describe the bounding-box center; shared models start at the feet.
            model.position = item.position - SIMD3<Float>(0, item.dimensions.y / 2, 0)
            model.orientation = simd_quatf(angle: item.yaw, axis: [0, 1, 0])
            root.addChild(model)
        }
    }

    /// Reconcile fixtures while retaining the room meshes, camera and unchanged light identities.
    func updateFixtures(_ definitions: [LightFixture]) {
        guard definitions != fixtureDefinitions else { return }
        let previous = Dictionary(uniqueKeysWithValues: fixtures.map { ($0.definition.id, $0) })
        let retainedIDs = Set(definitions.map(\.id))
        for fixture in fixtures where !retainedIDs.contains(fixture.definition.id) {
            fixture.light.entity.removeFromParent()
            fixture.model.root.removeFromParent()
        }
        fixtures = definitions.map { fixture in
            let old = previous[fixture.id]
            let model: LightingFixtureModel
            if let existing = old?.model, existing.kind == fixture.resolvedKind {
                model = existing
                model.updateMount(fixture: fixture, room: snapshot)
            } else {
                old?.model.root.removeFromParent()
                model = LightingFixtureModel(fixture: fixture, room: snapshot)
            }
            let light: LightingFixtureLight
            if let existing = old?.light, existing.distribution == model.optics.distribution {
                light = existing
                light.configure(optics: model.optics)
            } else {
                old?.light.entity.removeFromParent()
                light = LightingFixtureLight(optics: model.optics)
            }
            light.entity.name = "LightingFixture-\(fixture.id)"
            if light.entity.parent == nil { root.addChild(light.entity) }
            if model.root.parent == nil { root.addChild(model.root) }
            model.present(onPlacementLayer: isPlacementMode ? placementHeight : nil)
            light.position(at: model.emitterPosition, direction: model.emissionDirection)
            return (fixture, light, model)
        }
        fixtureDefinitions = definitions
        previousSettings = nil
    }

    private func positionCamera(_ preset: ViewportPreset) {
        let target = navigation.target(in: snapshot.geometry)
        let position = navigation.position(preset: preset, geometry: snapshot.geometry)
        camera.look(at: target, from: position, upVector: isPlacementMode ? [0, 0, -1] : [0, 1, 0], relativeTo: root)
        let offset = position - target
        let yaw = atan2(offset.x, offset.z)
        let pitch = atan2(offset.y, hypot(offset.x, offset.z))
        let orientation = simd_quatf(angle: pitch, axis: [1, 0, 0]) * simd_quatf(angle: -yaw, axis: [0, 1, 0])
        for wall in walls {
            let hidden = WallCutawayEvaluator.isWallHidden(wallNormal: wall.normal,
                                                           orientation: orientation, pitch: pitch)
            if #available(iOS 18.0, *) {
                // Keep the complete wall group active for the shadow depth pass.
                wall.entity.isEnabled = true
                if hidden {
                    wall.entity.components.set(OpacityComponent(opacity: 0))
                } else {
                    wall.entity.components.remove(OpacityComponent.self)
                }
            } else {
                wall.entity.isEnabled = !hidden
            }
        }
    }

    /// A pan starting on a selected fixture moves it; a pan elsewhere turns the camera.
    @objc func orbit(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view as? ARView else { return }
        let point = gesture.location(in: view)
        switch gesture.state {
        case .began:
            if let id = fixtureID(at: point, in: view), selectedIDs.contains(id),
               let fixture = fixtures.first(where: { $0.definition.id == id }) {
                let height = fixture.model.root.position(relativeTo: nil).y
                if let start = planePoint(at: point, height: height, in: view) {
                    drag = (id, height, SIMD2<Float>(Float(fixture.definition.positionX), Float(fixture.definition.positionZ)) - start)
                }
            }
        case .changed:
            if let drag {
                if let position = planePoint(at: point, height: drag.height, in: view) {
                    onMoveLight?(drag.id, position + drag.offset)
                }
            } else if !isPlacementMode {
                let delta = gesture.translation(in: view)
                navigation.orbit(deltaX: delta.x, deltaY: delta.y)
                positionCamera(previousPreset ?? .dollhouseIsometric)
            }
            gesture.setTranslation(.zero, in: view)
        case .ended, .cancelled, .failed:
            drag = nil
        default: break
        }
    }

    private func planePoint(at point: CGPoint, height: Float, in view: ARView) -> SIMD2<Float>? {
        guard let ray = view.ray(through: point), abs(ray.direction.y) > 0.0001 else { return nil }
        let distance = (height - ray.origin.y) / ray.direction.y
        guard distance > 0 else { return nil }
        let world = ray.origin + ray.direction * distance
        return [world.x, world.z]
    }

    private func fixtureID(at point: CGPoint, in view: ARView) -> UUID? {
        if let badge = moveBadges.first(where: { !$0.value.isHidden && $0.value.frame.insetBy(dx: -13, dy: -13).contains(point) }) {
            return badge.key
        }
        var hit = view.entity(at: point)
        while let entity = hit {
            if let fixture = entity.components[LightingFixtureIDComponent.self] { return fixture.id }
            hit = entity.parent
        }
        return fixtures.compactMap { fixture -> (id: UUID, distance: CGFloat)? in
            guard let projected = view.project(fixture.model.root.position(relativeTo: nil)) else { return nil }
            return (fixture.definition.id, hypot(projected.x - point.x, projected.y - point.y))
        }.filter { $0.distance <= 22 }.min { $0.distance < $1.distance }?.id
    }

    @objc func magnify(_ gesture: UIPinchGestureRecognizer) {
        guard !isPlacementMode, gesture.state == .changed else { return }
        navigation.magnify(by: gesture.scale)
        gesture.scale = 1
        positionCamera(previousPreset ?? .dollhouseIsometric)
    }

    @objc func resetCamera() {
        guard !isPlacementMode else { return }
        navigation.reset()
        positionCamera(previousPreset ?? .dollhouseIsometric)
    }

    @objc func tapLayout(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view as? ARView else { return }
        let point = gesture.location(in: view)
        if let id = fixtureID(at: point, in: view) {
            onSelectLight?(id)
            return
        }
        if !selectedIDs.isEmpty || isSelectingMultiple || !isPlacementMode {
            onClearSelection?()
            return
        }
        guard isPlacementMode,
              let ray = view.ray(through: point), abs(ray.direction.y) > 0.0001 else { return }
        // Hit the visible white placement layer rather than the floor behind it.
        let distance = (placementHeight - ray.origin.y) / ray.direction.y
        guard distance > 0 else { return }
        let floor = ray.origin + ray.direction * distance
        guard let unit = snapshot.geometry.unitPosition(floorX: Double(floor.x), floorZ: Double(floor.z)) else { return }
        onPlaceLight?(unit)
    }

    private func color(kelvin: Int) -> UIColor {
        let rgb = IlluminationSimulationEngine().blackbodyRGB(kelvin: kelvin)
        return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
    }
}

/// A single real light per fixture keeps the viewport within its dynamic light budget.
@MainActor
final class LightingFixtureLight {
    let entity: Entity
    let distribution: LightingFixtureOptics.Distribution
    private let spot: SpotLight?
    private let point: PointLight?

    init(optics: LightingFixtureOptics) {
        distribution = optics.distribution
        switch distribution {
        case .focused:
            let light = SpotLight()
            spot = light
            point = nil
            entity = light
            #if !targetEnvironment(simulator)
            light.components.set(SpotLightComponent.Shadow())
            #endif
        case .diffuse:
            let light = PointLight()
            point = light
            spot = nil
            entity = light
        }
        configure(optics: optics)
    }

    func configure(optics: LightingFixtureOptics) {
        spot?.light.innerAngleInDegrees = optics.innerAngle
        spot?.light.outerAngleInDegrees = optics.outerAngle
        spot?.light.attenuationRadius = optics.reach
        point?.light.attenuationRadius = optics.reach
    }

    func position(at position: SIMD3<Float>, direction: SIMD3<Float>) {
        entity.position = position
        entity.orientation = simd_quatf(from: SIMD3<Float>(0, 0, -1), to: direction)
    }

    func apply(output: Double, kelvin: Int, enabled: Bool) {
        entity.isEnabled = enabled && output > 0
        let rgb = IlluminationSimulationEngine().blackbodyRGB(kelvin: kelvin)
        let color = UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        // Match viewport exposure; this is an educational preview, not calibrated photometry.
        let intensity = Float(max(0, output)) * 12
        spot?.light.color = color
        spot?.light.intensity = intensity
        point?.light.color = color
        point?.light.intensity = intensity
    }
}

// MARK: - Fixture optics and mounting

/// The mesh opening and the real light share this definition.
struct LightingFixtureOptics: Sendable {
    enum Distribution: Sendable, Equatable { case focused, diffuse }
    let distribution: Distribution
    let emitterPosition: SIMD3<Float>
    let direction: SIMD3<Float>
    let innerAngle: Float
    let outerAngle: Float
    let reach: Float
    let height: Float

    init(kind: LightKind) {
        switch kind {
        case .deskLamp:
            distribution = .focused
            direction = simd_normalize([0, -1, -0.35])
            emitterPosition = SIMD3<Float>(0, 0.40, -0.18) + direction * 0.015
            innerAngle = 25; outerAngle = 52; reach = 4; height = 0.57
        case .standingLamp:
            distribution = .diffuse
            emitterPosition = [0, 1.6, 0]; direction = [0, -1, 0]
            innerAngle = 55; outerAngle = 85; reach = 7; height = 1.76
        case .tableLamp:
            distribution = .diffuse
            emitterPosition = [0, 0.46, 0]; direction = [0, -1, 0]
            innerAngle = 55; outerAngle = 85; reach = 4; height = 0.58
        case .ceilingLight:
            distribution = .focused
            emitterPosition = [0, -0.07, 0]; direction = [0, -1, 0]
            innerAngle = 55; outerAngle = 85; reach = 10; height = 0.08
        case .pendantLight:
            distribution = .focused
            emitterPosition = [0, -0.68, 0]; direction = [0, -1, 0]
            innerAngle = 38; outerAngle = 70; reach = 8; height = 0.68
        case .wallLight:
            distribution = .focused
            direction = simd_normalize([0, -1, 0.35])
            emitterPosition = SIMD3<Float>(0, -0.1, 0.18) + direction * 0.015
            innerAngle = 30; outerAngle = 65; reach = 5; height = 0.35
        }
    }
}

struct LightingFixtureMount: Sendable {
    let position: SIMD3<Float>
    let orientation: simd_quatf
    let scale: Float

    init(fixture: LightFixture, room: LightingRoomSnapshot) {
        let kind = fixture.resolvedKind
        let optics = LightingFixtureOptics(kind: kind)
        let height = Float(room.geometry.height)
        let x = Float(fixture.positionX)
        let z = Float(fixture.positionZ)
        var position = SIMD3<Float>(x, 0, z)
        var orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        var availableHeight = height - 0.08

        switch kind {
        case .standingLamp:
            break
        case .deskLamp, .tableLamp:
            position.y = Self.supportHeight(x: x, z: z, furnishings: room.furnishings, roomHeight: height)
            availableHeight -= position.y
        case .ceilingLight, .pendantLight:
            position.y = height - 0.02
        case .wallLight:
            position.y = min(height - 0.2, max(0.2, Float(fixture.elevationY)))
            let halfWidth = Float(room.geometry.width) / 2 - 0.04
            let halfLength = Float(room.geometry.length) / 2 - 0.04
            let inward: SIMD3<Float>
            if halfWidth - abs(x) <= halfLength - abs(z) {
                position.x = x < 0 ? -halfWidth : halfWidth
                inward = [x < 0 ? 1 : -1, 0, 0]
            } else {
                position.z = z < 0 ? -halfLength : halfLength
                inward = [0, 0, z < 0 ? 1 : -1]
            }
            orientation = simd_quatf(from: SIMD3<Float>(0, 0, 1), to: inward)
        }
        self.position = position
        self.orientation = orientation
        scale = min(1, max(0.1, availableHeight / optics.height))
    }

    private static func supportHeight(x: Float, z: Float, furnishings: [LightingRoomSnapshot.Furnishing], roomHeight: Float) -> Float {
        furnishings.compactMap { item -> Float? in
            guard item.category == .table || (item.category == .storage && item.dimensions.y <= 1.2) else { return nil }
            let deltaX = x - item.position.x
            let deltaZ = z - item.position.z
            let localX = deltaX * cos(item.yaw) - deltaZ * sin(item.yaw)
            let localZ = deltaX * sin(item.yaw) + deltaZ * cos(item.yaw)
            guard abs(localX) <= item.dimensions.x / 2,
                  abs(localZ) <= item.dimensions.z / 2 else { return nil }
            let top = item.position.y + item.dimensions.y / 2
            return top < roomHeight - 0.3 ? max(0, top) : nil
        }.max() ?? 0
    }
}

// MARK: - Fixture models

struct LightingFixtureIDComponent: Component {
    let id: UUID
}

/// One cloned mesh hierarchy per fixture. Materials change without replacing its geometry.
@MainActor
final class LightingFixtureModel {
    private static let selectionEdgeMesh = MeshResource.generateBox(size: 1)
    private static let selectionEdgeMaterial = UnlitMaterial(color: .systemOrange)
    let root: Entity
    let kind: LightKind
    let optics: LightingFixtureOptics
    private let glowingParts: [ModelEntity]
    private let lowerBound: Float
    private let selectionOutline: Entity
    private var mount: LightingFixtureMount
    private var lastOutput: Double?
    private var lastKelvin: Int?

    init(fixture: LightFixture, room: LightingRoomSnapshot) {
        kind = fixture.resolvedKind
        optics = LightingFixtureOptics(kind: kind)
        root = LightingFixtureModelBuilder.make(kind: kind)
        root.name = "LampModel-\(fixture.id)"
        root.components.set(LightingFixtureIDComponent(id: fixture.id))
        glowingParts = Self.collectGlowingParts(in: root)
        let bounds = root.visualBounds(relativeTo: root)
        lowerBound = bounds.min.y
        selectionOutline = Self.makeSelectionOutline(bounds: bounds)
        root.addChild(selectionOutline)
        mount = LightingFixtureMount(fixture: fixture, room: room)
        updateMount(fixture: fixture, room: room)
    }

    var emitterPosition: SIMD3<Float> { root.convert(position: optics.emitterPosition, to: root.parent) }
    var emissionDirection: SIMD3<Float> { root.orientation.act(optics.direction) }

    func setSelected(_ selected: Bool) { selectionOutline.isEnabled = selected }

    private static func makeSelectionOutline(bounds: BoundingBox) -> Entity {
        let outline = Entity()
        outline.name = "SelectionOutline"
        outline.position = [bounds.center.x, bounds.max.y + 0.025, bounds.center.z]
        let width = max(0.22, bounds.extents.x) + 0.08
        let depth = max(0.22, bounds.extents.z) + 0.08
        let edges: [(size: SIMD3<Float>, position: SIMD3<Float>)] = [
            ([width, 0.008, 0.012], [0, 0, depth / 2]),
            ([width, 0.008, 0.012], [0, 0, -depth / 2]),
            ([0.012, 0.008, depth], [width / 2, 0, 0]),
            ([0.012, 0.008, depth], [-width / 2, 0, 0])
        ]
        for edge in edges {
            let bar = ModelEntity(mesh: selectionEdgeMesh, materials: [selectionEdgeMaterial])
            bar.scale = edge.size
            bar.position = edge.position
            bar.components.set(DynamicLightShadowComponent(castsShadow: false))
            bar.components.set(GroundingShadowComponent(castsShadow: false))
            outline.addChild(bar)
        }
        outline.isEnabled = false
        return outline
    }

    func updateMount(fixture: LightFixture, room: LightingRoomSnapshot) {
        mount = LightingFixtureMount(fixture: fixture, room: room)
        present(onPlacementLayer: nil)
    }

    func present(onPlacementLayer height: Float?) {
        var position = mount.position
        if let height { position.y = height + 0.03 - lowerBound * mount.scale }
        root.transform = Transform(scale: SIMD3<Float>(repeating: mount.scale),
                                   rotation: mount.orientation, translation: position)
    }

    func applyAppearance(output: Double, kelvin: Int) {
        guard lastOutput != output || lastKelvin != kelvin else { return }
        lastOutput = output
        lastKelvin = kelvin
        let rgb = IlluminationSimulationEngine().blackbodyRGB(kelvin: kelvin)
        let tint = UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        for part in glowingParts {
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: output > 0 ? tint : UIColor(white: 0.75, alpha: 1))
            material.roughness = 0.6
            material.emissiveColor = .init(color: tint)
            let softness: Float = part.name == "GlowingShade" ? 0.25 : 1
            material.emissiveIntensity = min(6, Float(max(0, output) / 800) * 1.5) * softness
            part.model?.materials = [material]
        }
    }

    private static func collectGlowingParts(in entity: Entity) -> [ModelEntity] {
        let own = (entity.name == "LampLens" || entity.name == "GlowingShade") ? [entity as? ModelEntity].compactMap { $0 } : []
        return own + entity.children.flatMap { collectGlowingParts(in: $0) }
    }
}

/// Six bounded prototypes share mesh and collision resources across cloned fixtures.
@MainActor
enum LightingFixtureModelBuilder {
    private static var prototypes: [LightKind: Entity] = [:]
    private static let steel = SimpleMaterial(color: UIColor(white: 0.18, alpha: 1), roughness: 0.35, isMetallic: true)
    private static let brass = SimpleMaterial(color: UIColor(red: 0.7, green: 0.51, blue: 0.27, alpha: 1), roughness: 0.4, isMetallic: true)
    private static let teal = SimpleMaterial(color: UIColor(red: 0.2, green: 0.43, blue: 0.43, alpha: 1), roughness: 0.45, isMetallic: false)
    private static let ivory = SimpleMaterial(color: UIColor(red: 0.9, green: 0.85, blue: 0.75, alpha: 1), roughness: 0.7, isMetallic: false)
    private static let clay = SimpleMaterial(color: UIColor(red: 0.64, green: 0.34, blue: 0.22, alpha: 1), roughness: 0.6, isMetallic: false)
    private static let lens = SimpleMaterial(color: UIColor(white: 0.8, alpha: 1), roughness: 0.6, isMetallic: false)

    static func make(kind: LightKind) -> Entity {
        if let prototype = prototypes[kind] { return prototype.clone(recursive: true) }
        let root = Entity()
        root.name = kind.rawValue
        switch kind {
        case .deskLamp: deskLamp(in: root)
        case .standingLamp: standingLamp(in: root)
        case .tableLamp: tableLamp(in: root)
        case .ceilingLight: ceilingLight(in: root)
        case .pendantLight: pendantLight(in: root)
        case .wallLight: wallLight(in: root)
        }
        let emitter = Entity()
        emitter.name = "LightEmitter"
        emitter.position = LightingFixtureOptics(kind: kind).emitterPosition
        root.addChild(emitter)
        disableFixtureShadows(in: root)
        root.generateCollisionShapes(recursive: true)
        prototypes[kind] = root
        return root.clone(recursive: true)
    }

    private static func disableFixtureShadows(in entity: Entity) {
        entity.components.set(DynamicLightShadowComponent(castsShadow: false))
        entity.components.set(GroundingShadowComponent(castsShadow: false))
        for child in entity.children { disableFixtureShadows(in: child) }
    }

    private static func deskLamp(in root: Entity) {
        cylinder("DeskBase", radius: 0.12, height: 0.025, at: [0, 0.0125, 0], material: teal, in: root)
        rod("LowerArm", from: [0, 0.025, 0], to: [0, 0.26, 0.09], radius: 0.012, material: steel, in: root)
        rod("UpperArm", from: [0, 0.26, 0.09], to: [0, 0.47, -0.13], radius: 0.012, material: steel, in: root)
        sphere("ElbowJoint", radius: 0.026, at: [0, 0.26, 0.09], material: brass, in: root)
        sphere("HeadJoint", radius: 0.024, at: [0, 0.47, -0.13], material: brass, in: root)
        shade("DeskHead", opening: [0, 0.40, -0.18], direction: LightingFixtureOptics(kind: .deskLamp).direction,
              radius: 0.12, height: 0.15, material: teal, in: root)
    }

    private static func standingLamp(in root: Entity) {
        cylinder("FloorBase", radius: 0.18, height: 0.035, at: [0, 0.0175, 0], material: brass, in: root)
        rod("FloorPole", from: [0, 0.035, 0], to: [0, 1.6, 0], radius: 0.016, material: brass, in: root)
        cylinder("GlowingShade", radius: 0.23, height: 0.28, at: [0, 1.6, 0], material: ivory, in: root)
        cylinder("ShadeTopRim", radius: 0.235, height: 0.012, at: [0, 1.746, 0], material: brass, in: root)
        cylinder("ShadeBottomRim", radius: 0.235, height: 0.012, at: [0, 1.454, 0], material: brass, in: root)
        cylinder("LampLens", radius: 0.215, height: 0.004, at: [0, 1.449, 0], material: lens, in: root)
    }

    private static func tableLamp(in root: Entity) {
        cylinder("TableBase", radius: 0.11, height: 0.025, at: [0, 0.0125, 0], material: brass, in: root)
        let body = sphere("CeramicBody", radius: 0.1, at: [0, 0.16, 0], material: teal, in: root)
        body.scale = [1, 1.4, 1]
        rod("TableStem", from: [0, 0.28, 0], to: [0, 0.46, 0], radius: 0.012, material: brass, in: root)
        cylinder("GlowingShade", radius: 0.16, height: 0.22, at: [0, 0.46, 0], material: ivory, in: root)
        cylinder("ShadeTopRim", radius: 0.164, height: 0.008, at: [0, 0.574, 0], material: brass, in: root)
        cylinder("LampLens", radius: 0.15, height: 0.004, at: [0, 0.347, 0], material: lens, in: root)
    }

    private static func ceilingLight(in root: Entity) {
        cylinder("CeilingHousing", radius: 0.21, height: 0.05, at: [0, -0.025, 0], material: ivory, in: root)
        cylinder("CeilingRing", radius: 0.215, height: 0.015, at: [0, -0.052, 0], material: brass, in: root)
        cylinder("LampLens", radius: 0.19, height: 0.006, at: [0, -0.063, 0], material: lens, in: root)
    }

    private static func pendantLight(in root: Entity) {
        cylinder("CeilingRose", radius: 0.08, height: 0.025, at: [0, -0.0125, 0], material: steel, in: root)
        rod("PendantCord", from: [0, -0.025, 0], to: [0, -0.45, 0], radius: 0.007, material: steel, in: root)
        shade("PendantShade", opening: [0, -0.665, 0], direction: [0, -1, 0],
              radius: 0.25, height: 0.22, material: clay, in: root)
    }

    private static func wallLight(in root: Entity) {
        let plate = ModelEntity(mesh: .generateBox(size: [0.16, 0.28, 0.035], cornerRadius: 0.02), materials: [brass])
        plate.name = "WallPlate"
        root.addChild(plate)
        rod("WallArm", from: [0, 0.03, 0.02], to: [0, 0.03, 0.18], radius: 0.015, material: brass, in: root)
        shade("WallShade", opening: [0, -0.1, 0.18], direction: LightingFixtureOptics(kind: .wallLight).direction,
              radius: 0.1, height: 0.14, material: ivory, in: root)
    }

    private static func shade(_ name: String, opening: SIMD3<Float>, direction: SIMD3<Float>,
                              radius: Float, height: Float, material: SimpleMaterial, in root: Entity) {
        let head = Entity()
        head.name = name
        head.position = opening
        head.orientation = simd_quatf(from: SIMD3<Float>(0, -1, 0), to: direction)
        let housing = ModelEntity(mesh: .generateCone(height: height, radius: radius), materials: [material])
        housing.name = "ShadeHousing"
        housing.position.y = height / 2
        head.addChild(housing)
        cylinder("LampLens", radius: radius * 0.88, height: 0.005, at: [0, -0.005, 0], material: lens, in: head)
        root.addChild(head)
    }

    @discardableResult
    private static func cylinder(_ name: String, radius: Float, height: Float, at position: SIMD3<Float>,
                                 material: SimpleMaterial, in root: Entity) -> ModelEntity {
        let entity = ModelEntity(mesh: .generateCylinder(height: height, radius: radius), materials: [material])
        entity.name = name
        entity.position = position
        root.addChild(entity)
        return entity
    }

    @discardableResult
    private static func sphere(_ name: String, radius: Float, at position: SIMD3<Float>,
                               material: SimpleMaterial, in root: Entity) -> ModelEntity {
        let entity = ModelEntity(mesh: .generateSphere(radius: radius), materials: [material])
        entity.name = name
        entity.position = position
        root.addChild(entity)
        return entity
    }

    private static func rod(_ name: String, from start: SIMD3<Float>, to end: SIMD3<Float>, radius: Float,
                            material: SimpleMaterial, in root: Entity) {
        let delta = end - start
        let entity = cylinder(name, radius: radius, height: simd_length(delta), at: (start + end) / 2, material: material, in: root)
        entity.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(delta))
    }
}
