import Testing
import RealityKit
import UIKit
import simd
@testable import Alcove

@Suite("Lighting fixture models") @MainActor
struct LightingFixtureModelTests {
    @Test func previewUsesSharedShellAndDetailedFurnitureWithoutRebuildingOnFixtureEdits() throws {
        let room = MockRoomGenerator.generateBedroomOfficeCombo()
        let snapshot = LightingRoomSnapshot(room: room)
        let scene = LightingRoomScene(snapshot: snapshot)
        let shell = try #require(scene.root.findEntity(named: "RoomShell"))
        #expect(shell.findEntity(named: "WindowFrameCasing") != nil)
        #expect(shell.findEntity(named: "Ceiling") == nil)
        for name in ["FrontWallGroup", "BackWallGroup", "LeftWallGroup", "RightWallGroup"] {
            #expect(shell.findEntity(named: name) != nil)
        }
        let desk = try #require(snapshot.furnishings.first { $0.category == .table })
        let model = try #require(scene.root.findEntity(named: "Furniture-\(desk.id)"))
        #expect(!model.children.isEmpty)
        #expect(abs(model.position.y - (desk.position.y - desk.dimensions.y / 2)) < 0.001)
        #expect(simd_distance(model.orientation.act([0, 0, 1]), simd_quatf(angle: desk.yaw, axis: [0, 1, 0]).act([0, 0, 1])) < 0.001)
        scene.updateFixtures([LightFixture(name: "New lamp", layer: .task, kind: .deskLamp)])
        #expect(scene.root.findEntity(named: "RoomShell") === shell)
        #expect(scene.root.findEntity(named: model.name) === model)
    }

    @Test func cutawayWallsStayEnabledAndRestoreOpacityWhenCameraChanges() throws {
        guard #available(iOS 18.0, *) else { return }
        let scene = LightingRoomScene(snapshot: LightingRoomSnapshot(room: MockRoomGenerator.generateBedroomOfficeCombo()))
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        defer { view.scene.anchors.removeAll() }
        view.scene.addAnchor(scene.root)
        let front = try #require(scene.root.findEntity(named: "FrontWallGroup"))
        let back = try #require(scene.root.findEntity(named: "BackWallGroup"))
        scene.apply(LightingSimulationSettings(), preset: .front, in: view)
        #expect(front.isEnabled && back.isEnabled)
        #expect(front.components[OpacityComponent.self]?.opacity == 0)
        #expect(back.components[OpacityComponent.self] == nil)
        scene.apply(LightingSimulationSettings(), preset: .back, in: view)
        #expect(front.isEnabled && back.isEnabled)
        #expect(front.components[OpacityComponent.self] == nil)
        #expect(back.components[OpacityComponent.self]?.opacity == 0)
    }

    @Test(arguments: LightKind.allCases)
    func eachTypeHasRecognizableGeometryAndItsOwnEmitter(kind: LightKind) throws {
        let parts: [LightKind: String] = [.deskLamp: "LowerArm", .standingLamp: "FloorPole",
            .tableLamp: "CeramicBody", .ceilingLight: "CeilingHousing",
            .pendantLight: "PendantCord", .wallLight: "WallPlate"]
        let model = LightingFixtureModelBuilder.make(kind: kind)
        let name = try #require(parts[kind])
        #expect(model.findEntity(named: name) != nil)
        let lens = try #require(model.findEntity(named: "LampLens") as? ModelEntity)
        #expect(lens.collision != nil)
        let emitter = try #require(model.findEntity(named: "LightEmitter"))
        #expect(emitter.position == LightingFixtureOptics(kind: kind).emitterPosition)
        let clone = LightingFixtureModelBuilder.make(kind: kind)
        #expect(model !== clone)
        #expect(model.findEntity(named: name) !== clone.findEntity(named: name))
    }

    @Test func fixturesMountOnDeskFloorCeilingAndNearestWall() {
        let room = LightingRoomSnapshot(room: MockRoomGenerator.generateBedroomOfficeCombo())
        var fixture = LightFixture(name: "Desk", layer: .task, positionX: 1.3, positionZ: -1.1, kind: .deskLamp)
        let desk = LightingFixtureMount(fixture: fixture, room: room)
        #expect(abs(desk.position.y - 0.75) < 0.001)
        fixture.kind = .standingLamp
        #expect(LightingFixtureMount(fixture: fixture, room: room).position.y == 0)
        fixture.kind = .pendantLight
        #expect(abs(LightingFixtureMount(fixture: fixture, room: room).position.y - Float(room.geometry.height - 0.02)) < 0.001)
        fixture.kind = .wallLight
        fixture.positionX = -2
        fixture.positionZ = 0
        let wall = LightingFixtureMount(fixture: fixture, room: room)
        #expect(abs(wall.position.x + Float(room.geometry.width / 2 - 0.04)) < 0.001)
        #expect(simd_distance(wall.orientation.act([0, 0, 1]), [1, 0, 0]) < 0.001)
        #expect(fixture.positionX == -2)
    }

    @Test func sourceFollowsLampHeadAndPlacementLayerRestoresPhysicalMount() {
        let room = LightingRoomSnapshot(room: MockRoomGenerator.generateBedroomOfficeCombo())
        let fixture = LightFixture(name: "Desk", layer: .task, positionX: 1.3, positionZ: -1.1, kind: .deskLamp)
        let model = LightingFixtureModel(fixture: fixture, room: room)
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(model.root)
        let mounted = model.emitterPosition
        #expect(abs(mounted.y - (0.75 + model.optics.emitterPosition.y)) < 0.001)
        #expect(model.emissionDirection.y < 0 && model.emissionDirection.z < 0)
        model.present(onPlacementLayer: 3)
        #expect(model.root.visualBounds(relativeTo: anchor).min.y >= 3)
        model.present(onPlacementLayer: nil)
        #expect(simd_distance(model.emitterPosition, mounted) < 0.001)
    }

    @Test func taskLampUsesFocusedLightAndStandingLampUsesDiffuseLight() throws {
        let focused = LightingFixtureLight(optics: LightingFixtureOptics(kind: .deskLamp))
        let spot = try #require(focused.entity as? SpotLight)
        #expect(spot.light.outerAngleInDegrees == 52)
        focused.apply(output: 1000, kelvin: 2700, enabled: true)
        #expect(spot.isEnabled && spot.light.intensity == 12000)
        let warm = spot.light.color
        focused.apply(output: 500, kelvin: 6500, enabled: true)
        #expect(spot.light.intensity == 6000)
        #expect(spot.light.color != warm)
        focused.apply(output: 500, kelvin: 6500, enabled: false)
        #expect(!spot.isEnabled)
        focused.apply(output: 0, kelvin: 6500, enabled: true)
        #expect(!spot.isEnabled && spot.light.intensity == 0)
        let diffuse = LightingFixtureLight(optics: LightingFixtureOptics(kind: .standingLamp))
        #expect(diffuse.entity is PointLight)
    }

    @Test func colorAndBrightnessUpdateModelAndChangingKindReplacesOnlyFixture() throws {
        let snapshot = LightingRoomSnapshot(room: MockRoomGenerator.generateBedroomOfficeCombo())
        var fixture = LightFixture(name: "Desk", layer: .task, kind: .deskLamp)
        let model = LightingFixtureModel(fixture: fixture, room: snapshot)
        model.applyAppearance(output: 800, kelvin: 2700)
        let lens = try #require(model.root.findEntity(named: "LampLens") as? ModelEntity)
        let on = try #require(lens.model?.materials.first as? PhysicallyBasedMaterial)
        #expect(on.emissiveIntensity > 0)
        model.applyAppearance(output: 0, kelvin: 6500)
        let off = try #require(lens.model?.materials.first as? PhysicallyBasedMaterial)
        #expect(off.emissiveIntensity == 0)
        let scene = LightingRoomScene(snapshot: snapshot)
        scene.updateFixtures([fixture])
        let original = try #require(scene.root.findEntity(named: "LampModel-\(fixture.id)"))
        fixture.lumens = 1500
        fixture.colorTemperatureKelvin = 4500
        scene.updateFixtures([fixture])
        #expect(scene.root.findEntity(named: original.name) === original)
        fixture.kind = .standingLamp
        scene.updateFixtures([fixture])
        #expect(original.parent == nil)
        #expect(scene.root.findEntity(named: "LampModel-\(fixture.id)")?.findEntity(named: "FloorPole") != nil)
        #expect(scene.root.findEntity(named: "LightingFixture-\(fixture.id)") is PointLight)
        scene.updateFixtures([])
        #expect(scene.root.findEntity(named: "LampModel-\(fixture.id)") == nil)
    }
}
