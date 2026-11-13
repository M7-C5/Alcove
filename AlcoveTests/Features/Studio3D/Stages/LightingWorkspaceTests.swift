import Foundation
import SwiftData
import Testing
import simd
import RealityKit
import UIKit
@testable import Alcove

@Suite("Lighting workspace") @MainActor
struct LightingWorkspaceTests {
    @Test func sunlightSwitchIsIndependentAndCameraPresetsKeepSunFixed() throws {
        let room = makeBatchRoom()
        let scene = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room, fixtures: room.workingLayout?.lightFixtures ?? []))
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        var settings = LightingSimulationSettings()
        scene.apply(settings, preset: .front, in: view)
        let sun = try #require(scene.root.findEntity(named: "Sunlight"))
        let position = sun.position
        let orientation = sun.orientation.vector
        #expect(sun.isEnabled)
        scene.apply(settings, preset: .right, in: view)
        #expect(sun.position == position && sun.orientation.vector == orientation)
        settings.sunlightOn = false
        scene.apply(settings, preset: .right, in: view)
        #expect(!sun.isEnabled)
        let fixture = LightFixture(name: "Test", layer: .ambient)
        #expect(settings.output(for: fixture) == fixture.lumens)
        settings.artificialLightsOn = false
        settings.sunlightOn = true
        scene.apply(settings, preset: .right, in: view)
        #expect(sun.isEnabled)
        #expect(settings.output(for: fixture) == 0)
        #expect(sun.position == position && sun.orientation.vector == orientation)
    }

    @Test func dismissingSelectionExitsGroupModeWithoutChangingLights() {
        let editor = LightingSetupViewModel(room: makeBatchRoom())
        let before = editor.drafts
        editor.selectAll()
        editor.dismissSelection()
        #expect(editor.selectedIDs.isEmpty)
        #expect(!editor.isSelectingMultiple)
        #expect(editor.drafts == before)
        editor.selectAll()
        editor.deleteSelected()
        editor.toggleMultipleSelection()
        #expect(!editor.isSelectingMultiple)
        #expect(LightKind.lightingKinds == [.ceilingLight, .pendantLight, .wallLight])
    }

    @Test func freeformMovePreservesOffGridPositionAndSavedLayoutUntilSave() throws {
        let room = makeBatchRoom()
        let editor = LightingSetupViewModel(room: room)
        let original = editor.drafts
        let id = original[0].id
        editor.prepareForPlacement()
        editor.toggleMultipleSelection()
        editor.select(id)
        #expect(editor.isSelectingMultiple && editor.selectedIDs == [id])
        editor.move(id, x: 0.123, z: -0.237)
        #expect(editor.drafts[0].positionX == 0.123 && editor.drafts[0].positionZ == -0.237)
        #expect(editor.drafts[0].lumens == original[0].lumens)
        #expect(Array(editor.drafts.dropFirst()) == Array(original.dropFirst()))
        #expect(room.workingLayout?.lightFixtures == original)
        editor.move(id, x: .infinity, z: 0)
        #expect(editor.drafts[0].positionX == 0.123)
        editor.move(id, x: 100, z: -100)
        #expect(editor.drafts[0].positionX == (editor.geometry.width - 0.3) / 2)
        #expect(editor.drafts[0].positionZ == -(editor.geometry.length - 0.3) / 2)
        let context = ModelContext(try ModelContainer.createInMemoryContainer())
        context.insert(room)
        try editor.save(in: room, context: context)
        #expect(room.workingLayout?.lightFixtures == editor.drafts)
        #expect(room.baselineLayout?.lightFixtures.isEmpty == true)
    }

    @Test func multipleSelectionTogglesWithoutEditingFixturesAndDoneReturnsToOneLight() throws {
        let room = makeBatchRoom()
        let editor = LightingSetupViewModel(room: room)
        let original = editor.drafts
        editor.select(original[0].id)
        editor.select(original[1].id)
        #expect(editor.selectedIDs == [original[1].id])
        editor.toggleMultipleSelection()
        editor.select(original[0].id)
        #expect(editor.selectionCount == 2)
        editor.select(original[1].id)
        #expect(editor.selectedIDs == [original[0].id])
        editor.select(UUID())
        #expect(editor.selectionCount == 1)
        editor.selectAll()
        #expect(editor.selectionCount == 3)
        editor.toggleMultipleSelection()
        #expect(!editor.isSelectingMultiple)
        #expect(editor.selectedIDs == [original[0].id])
        editor.clearSelection()
        #expect(editor.selected == nil)
        #expect(editor.drafts == original && !editor.hasUnsavedChanges)
    }

    @Test func batchSlidersChangeOnlySelectedPropertyAndLeaveOtherLightsUntouched() throws {
        let room = makeBatchRoom()
        let editor = LightingSetupViewModel(room: room)
        let original = editor.drafts
        editor.select(original[0].id)
        editor.toggleMultipleSelection()
        editor.select(original[1].id)
        #expect(editor.commonKind == nil)
        #expect(editor.commonTemperature == nil && editor.commonBrightness == nil)
        #expect(editor.drafts == original)
        editor.updateSelected { $0.colorTemperatureKelvin = 4500 }
        #expect(editor.commonTemperature == 4500)
        #expect(editor.commonBrightness == nil)
        #expect(editor.drafts[0].lumens == original[0].lumens)
        #expect(editor.drafts[1].lumens == original[1].lumens)
        #expect(editor.drafts[1].isOn == original[1].isOn)
        editor.updateSelected { $0.lumens = 1500; $0.isOn = true }
        #expect(editor.commonBrightness == 1500)
        #expect(editor.selectedFixtures.allSatisfy { $0.isOn && $0.colorTemperatureKelvin == 4500 })
        #expect(editor.drafts[2] == original[2])
        #expect(room.workingLayout?.lightFixtures == original)
        #expect(room.baselineLayout?.lightFixtures.isEmpty == true)
        editor.updateSelected { $0.lumens = 0; $0.isOn = false }
        #expect(editor.selectedFixtures.allSatisfy { !$0.isOn && $0.lumens == 0 })
    }

    @Test func batchKindChangesKeepPositionsBrightnessAndUniqueNames() {
        let editor = LightingSetupViewModel(room: makeBatchRoom())
        let original = editor.drafts
        editor.selectAll()
        editor.chooseKind(.deskLamp)
        #expect(editor.commonKind == .deskLamp)
        #expect(Set(editor.drafts.map(\.name)).count == 3)
        for (fixture, before) in zip(editor.drafts, original) {
            #expect(fixture.id == before.id)
            #expect(fixture.positionX == before.positionX && fixture.positionZ == before.positionZ)
            #expect(fixture.lumens == before.lumens && fixture.colorTemperatureKelvin == before.colorTemperatureKelvin)
            #expect(fixture.isOn == before.isOn)
            #expect(fixture.layer == .task)
        }
    }

    @Test func batchSaveAndDeletePersistOnlySelectedLightsAndKeepBaseline() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let room = makeBatchRoom()
        container.mainContext.insert(room)
        let baseline = room.baselineLayout?.lightFixturesData
        let editor = LightingSetupViewModel(room: room)
        let original = editor.drafts
        editor.select(original[0].id)
        editor.toggleMultipleSelection()
        editor.select(original[1].id)
        editor.updateSelected { $0.colorTemperatureKelvin = 5000 }
        try editor.save(in: room, context: container.mainContext)
        let saved = try #require(ModelContext(container).fetch(FetchDescriptor<Room>()).first)
        #expect(saved.workingLayout?.lightFixtures.prefix(2).allSatisfy { $0.colorTemperatureKelvin == 5000 } == true)
        editor.deleteSelected()
        #expect(editor.selectionCount == 0)
        #expect(editor.drafts == [original[2]])
        try editor.save(in: room, context: container.mainContext)
        let remaining = try #require(ModelContext(container).fetch(FetchDescriptor<Room>()).first)
        #expect(remaining.workingLayout?.lightFixtures == [original[2]])
        #expect(room.baselineLayout?.lightFixturesData == baseline)
        editor.selectAll()
        editor.deleteSelected()
        #expect(!editor.isSelectingMultiple && editor.selectedIDs.isEmpty)
        try editor.save(in: room, context: container.mainContext)
        #expect(room.workingLayout?.lightFixtures.isEmpty == true)
    }

    @Test func placingAnotherLightEndsGroupSelectionAndEditsOnlyTheNewLight() throws {
        let editor = LightingSetupViewModel(room: makeBatchRoom())
        let original = editor.drafts
        editor.selectAll()
        editor.prepareForPlacement()
        #expect(editor.selectedIDs.isEmpty && !editor.isSelectingMultiple)
        editor.place(unitX: 0.5, unitZ: 0.5)
        #expect(editor.selectionCount == 1)
        editor.updateSelected { $0.lumens = 900 }
        #expect(Array(editor.drafts.prefix(3)) == original)
        #expect(editor.selected?.lumens == 900)
    }

    @Test func viewportSelectionOutlinesTrackEverySelectedLightAndKeepSavedFixturesUnchanged() throws {
        let room = makeBatchRoom()
        let fixtures = try #require(room.workingLayout?.lightFixtures)
        let scene = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room))
        scene.setSelection([fixtures[0].id, fixtures[2].id])
        for (index, fixture) in fixtures.enumerated() {
            let model = try #require(scene.root.findEntity(named: "LampModel-\(fixture.id)"))
            let outline = try #require(model.findEntity(named: "SelectionOutline"))
            #expect(outline.isEnabled == (index != 1))
        }
        scene.setSelection([])
        #expect(fixtures.allSatisfy {
            scene.root.findEntity(named: "LampModel-\($0.id)")?.findEntity(named: "SelectionOutline")?.isEnabled == false
        })
        #expect(room.workingLayout?.lightFixtures == fixtures)
    }

    private func makeBatchRoom() -> Room {
        let room = SampleData.createStarterRoom()
        room.workingLayout?.lightFixtures = [
            LightFixture(name: "Desk Lamp 1", layer: .task, positionX: -1, positionZ: -1, lumens: 600, colorTemperatureKelvin: 2700, kind: .deskLamp),
            LightFixture(name: "Table Lamp 1", layer: .task, positionX: 1, positionZ: -1, lumens: 1400, colorTemperatureKelvin: 4000, isOn: false, kind: .tableLamp),
            LightFixture(name: "Standing Lamp 1", layer: .task, positionX: 0, positionZ: 1, lumens: 2200, colorTemperatureKelvin: 6500, kind: .standingLamp)
        ]
        return room
    }

    @Test func horizontalSwipeTurnsRoomWithTheFinger() {
        let bounds = LightingRoomGeometry(width: 4, length: 5, height: 2.6)
        var navigation = LightingCameraNavigation()
        navigation.orbit(deltaX: 80, deltaY: 0)
        #expect(navigation.yaw < 0)
        #expect(navigation.position(preset: .front, geometry: bounds).x < 0)
        navigation.reset()
        navigation.orbit(deltaX: -80, deltaY: 0)
        #expect(navigation.yaw > 0)
        #expect(navigation.position(preset: .front, geometry: bounds).x > 0)
    }

    @Test func placementLocksTopViewAndRestoresChosenPreset() {
        let bounds = LightingRoomGeometry(width: 4, length: 5, height: 2.6)
        var placement = LightingPlacementState()
        placement.begin(from: .right)
        placement.begin(from: .top)
        #expect(placement.isActive)
        var navigation = LightingCameraNavigation()
        navigation.orbit(deltaX: 120, deltaY: 90)
        navigation.setLocked(true)
        let locked = navigation.position(preset: .right, geometry: bounds)
        #expect(locked.y > Float(bounds.height))
        #expect(locked.x == 0 && locked.z == 0)
        navigation.orbit(deltaX: 300, deltaY: 100)
        navigation.magnify(by: 2)
        navigation.reset()
        #expect(navigation.position(preset: .front, geometry: bounds) == locked)
        #expect(placement.finish() == .right)
        #expect(!placement.isActive)
        navigation.setLocked(false)
        navigation.orbit(deltaX: 80, deltaY: 0)
        #expect(navigation.yaw < 0)
    }

    @Test func whitePlacementLayerKeepsDragAvailableAndDisablesCameraNavigation() {
        let room = MockRoomGenerator.generateBedroomOfficeCombo()
        let scene = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room))
        let pan = UIPanGestureRecognizer()
        let pinch = UIPinchGestureRecognizer()
        let reset = UITapGestureRecognizer()
        scene.panGesture = pan
        scene.pinchGesture = pinch
        scene.resetGesture = reset
        #expect(!scene.placementOverlay.isEnabled)
        scene.setPlacementMode(true)
        #expect(scene.placementOverlay.isEnabled)
        #expect(scene.placementOverlay.position.y > Float(room.dimensionsHeight))
        #expect(pan.isEnabled && !pinch.isEnabled && !reset.isEnabled)
        scene.setPlacementMode(false)
        #expect(!scene.placementOverlay.isEnabled)
        #expect(pan.isEnabled && pinch.isEnabled && reset.isEnabled)
    }

    @Test func lampTypesChooseMountingDetailsAndKeepColorAndBrightness() throws {
        let room = SampleData.createStarterRoom()
        let editor = LightingSetupViewModel(room: room)
        editor.chooseKind(.deskLamp)
        editor.place(unitX: 0.25, unitZ: 0.75)
        let fixture = try #require(editor.selected)
        #expect(fixture.name == "Desk Lamp 1")
        #expect(fixture.kind == .deskLamp)
        #expect(fixture.elevationY == 0.85)
        #expect(fixture.layer == .task)
        editor.updateSelected { $0.colorTemperatureKelvin = 4500; $0.lumens = 1500 }
        editor.chooseKind(.standingLamp)
        #expect(editor.selected?.id == fixture.id)
        #expect(editor.selected?.name == "Standing Lamp 1")
        #expect(editor.selected?.elevationY == 1.6)
        #expect(editor.selected?.lumens == 1500)
        #expect(editor.selected?.colorTemperatureKelvin == 4500)
        #expect(room.workingLayout?.lightFixtures.isEmpty == true)
    }

    @Test func savedLampTypeRoundTripsAndOlderFixturesStillDecode() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let room = SampleData.createStarterRoom()
        container.mainContext.insert(room)
        let editor = LightingSetupViewModel(room: room)
        editor.chooseKind(.standingLamp)
        editor.place(unitX: 0.5, unitZ: 0.5)
        try editor.save(in: room, context: container.mainContext)
        let context = ModelContext(container)
        let saved = try #require(context.fetch(FetchDescriptor<Room>()).first)
        #expect(saved.workingLayout?.lightFixtures.first?.kind == .standingLamp)
        let older = LightFixture(name: "Old desk lamp", layer: .task)
        let payload = try JSONEncoder().encode(older)
        let dictionary = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(dictionary["kind"] == nil)
        let decoded = try JSONDecoder().decode(LightFixture.self, from: payload)
        #expect(decoded.kind == nil)
        #expect(decoded.resolvedKind == .deskLamp)
    }

    @Test(arguments: [912.0, 1024.0, 1194.0, 1366.0])
    func threeColumnWorkspaceReservesRoomSpace(width: Double) {
        let layout = LightingWorkspaceLayout(width: width)
        #expect(layout.usesColumns)
        #expect(layout.viewportWidth >= 300)
        #expect(layout.inspectorWidth <= 288)
        #expect(layout.sourceWidth == layout.inspectorWidth)
        #expect(layout.sourceWidth + layout.inspectorWidth + layout.viewportWidth + 2 * layout.inset + 2 * layout.spacing <= width + 0.001)
        #expect(!LightingWorkspaceLayout(width: width, accessibilityText: true).usesColumns)
    }

    @Test func previewReconcilesLiveFixturesWithoutRebuildingCameraOrRoom() throws {
        let room = MockRoomGenerator.generateBedroomOfficeCombo()
        let scene = LightingRoomScene(snapshot: LightingRoomSnapshot(room: room))
        let initialChildren = Array(scene.root.children)
        var fixture = LightFixture(name: "Live lamp", layer: .ambient)
        scene.updateFixtures([fixture])
        let entity = try #require(scene.root.findEntity(named: "LightingFixture-\(fixture.id)") as? SpotLight)
        fixture.positionX = 1.25
        fixture.colorTemperatureKelvin = 5000
        scene.updateFixtures([fixture])
        #expect(scene.root.findEntity(named: entity.name) === entity)
        #expect(entity.position.x == 1.25)
        #expect(scene.root.children.count == initialChildren.count + 2)
        #expect(initialChildren.allSatisfy { original in scene.root.children.contains { $0 === original } })
        scene.updateFixtures([])
        #expect(scene.root.children.count == initialChildren.count)
    }

    @Test func previewCanUseDraftsWhileSavedLayoutRemainsUnchanged() throws {
        let room = SampleData.createStarterRoom()
        let draft = LightFixture(name: "Unsaved light", layer: .task, lumens: 1200)
        let snapshot = LightingRoomSnapshot(room: room, fixtures: [draft])
        #expect(snapshot.fixtures.first?.id == draft.id)
        #expect(room.workingLayout?.lightFixtures.isEmpty == true)
        let container = try ModelContainer.createInMemoryContainer()
        container.mainContext.insert(room)
        let editor = LightingSetupViewModel(room: room)
        #expect(!editor.hasUnsavedChanges)
        editor.place(unitX: 0.25, unitZ: 0.75, layer: .task)
        #expect(editor.hasUnsavedChanges)
        try editor.save(in: room, context: container.mainContext)
        #expect(!editor.hasUnsavedChanges)
    }

    @Test func viewportFloorTapsMapToTheSamePlanAndRejectOutsideRoom() throws {
        let geometry = LightingRoomGeometry(width: 4, length: 5, height: 2.6)
        let unit = try #require(geometry.unitPosition(floorX: 1, floorZ: -1.25))
        #expect(unit.x == 0.75)
        #expect(unit.y == 0.25)
        let position = geometry.position(unitX: Double(unit.x), unitZ: Double(unit.y))
        #expect(position.x == 1)
        #expect(position.z == -1.25)
        #expect(geometry.unitPosition(floorX: 3, floorZ: 0) == nil)
        #expect(geometry.unitPosition(floorX: 0, floorZ: .nan) == nil)
    }

    @Test func draftEditsDoNotChangeSavedLightsAndKeepIdentity() throws {
        let room = SampleData.createCozyBedroom()
        let layout = try #require(room.workingLayout)
        let original = layout.lightFixtures
        let editor = LightingSetupViewModel(room: room)
        editor.selectedID = original.first?.id
        editor.updateSelected { $0.lumens = 1600; $0.colorTemperatureKelvin = 4500; $0.isOn = false }
        #expect(layout.lightFixtures == original)
        #expect(editor.selected?.id == original.first?.id)
        #expect(editor.selected?.lumens == 1600)
    }

    @Test func placementUsesRoomMetersAndSelectsOccupiedPoint() {
        let room = Room(name: "Wide room", dimensionsWidth: 8, dimensionsLength: 3, dimensionsHeight: 2.1)
        let editor = LightingSetupViewModel(room: room)
        editor.place(unitX: 1, unitZ: 0, layer: .ambient)
        let first = editor.selected
        #expect(abs((first?.positionX ?? 0) - 3.85) < 0.001)
        #expect(abs((first?.positionZ ?? 0) + 1.35) < 0.001)
        #expect(first?.elevationY == 2.02)
        editor.place(unitX: 1, unitZ: 0, layer: .task)
        #expect(editor.drafts.count == 1)
        #expect(editor.selectedID == first?.id)
        editor.updateSelected { $0.positionX = 100; $0.elevationY = -10; $0.colorTemperatureKelvin = 9000 }
        #expect(editor.selected?.positionX == 3.85)
        #expect(editor.selected?.elevationY == 0.05)
        #expect(editor.selected?.colorTemperatureKelvin == 6500)
    }

    @Test func arbitraryTapPlacesLightNearTapOnFineGrid() throws {
        let room = Room(name: "Freeform plan", dimensionsWidth: 4, dimensionsLength: 5)
        let editor = LightingSetupViewModel(room: room)
        editor.place(unitX: 0.634, unitZ: 0.231, layer: .task)
        let fixture = try #require(editor.selected)
        #expect(abs(fixture.positionX - 0.55) < 0.000001)
        #expect(abs(fixture.positionZ + 1.35) < 0.000001)
        // A tap at 63.4%, 23.1% maps directly into room meters, within half a grid step.
        #expect(abs(fixture.positionX - (0.634 - 0.5) * 4) <= 0.025)
        #expect(abs(fixture.positionZ - (0.231 - 0.5) * 5) <= 0.025)
        #expect(fixture.layer == .task)
        #expect(room.workingLayout == nil)
    }

    @Test func nearbyTapsInSameCellSelectButAdjacentCellsCanAddLights() throws {
        let editor = LightingSetupViewModel(room: Room(name: "Fine grid", dimensionsWidth: 5))
        editor.place(unitX: 0.5, unitZ: 0.5, layer: .ambient)
        let firstID = try #require(editor.selectedID)
        editor.place(unitX: 0.501, unitZ: 0.499, layer: .task)
        #expect(editor.drafts.count == 1)
        #expect(editor.selectedID == firstID)
        editor.place(unitX: 0.51, unitZ: 0.5, layer: .task)
        #expect(editor.drafts.count == 2)
        #expect(editor.selectedID != firstID)
        #expect(abs((editor.selected?.positionX ?? 0) - 0.05) < 0.000001)
    }

    @Test func edgeTapsStayOnGridAndInsideWallsForUnevenRoomDimensions() {
        let geometry = LightingRoomGeometry(width: 4.23, length: 3.37, height: 2.6)
        for unit in [-1.0, 0, 1, 2] {
            let point = geometry.position(unitX: unit, unitZ: unit)
            #expect(abs(point.x) <= geometry.width / 2 - 0.15)
            #expect(abs(point.z) <= geometry.length / 2 - 0.15)
            #expect(abs(point.x / 0.05 - (point.x / 0.05).rounded()) < 0.000001)
            #expect(abs(point.z / 0.05 - (point.z / 0.05).rounded()) < 0.000001)
        }
    }

    @Test func saveAndDeleteLastFixturePersistWithoutChangingBaseline() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let context = container.mainContext
        let room = SampleData.createStarterRoom()
        context.insert(room)
        try context.save()
        let baseline = room.baselineLayout?.lightFixturesData
        let editor = LightingSetupViewModel(room: room)
        editor.place(unitX: 0.25, unitZ: 0.75, layer: .accent)
        let id = editor.selectedID
        try editor.save(in: room, context: context)
        let otherContext = ModelContext(container)
        let saved = try #require(otherContext.fetch(FetchDescriptor<Room>()).first)
        #expect(saved.workingLayout?.lightFixtures.first?.id == id)
        #expect(saved.workingLayout?.lightFixtures.first?.layer == .accent)
        #expect(room.baselineLayout?.lightFixturesData == baseline)
        editor.deleteSelected()
        try editor.save(in: room, context: context)
        #expect(room.workingLayout?.lightFixtures.isEmpty == true)
        let deletionContext = ModelContext(container)
        #expect(try deletionContext.fetch(FetchDescriptor<Room>()).first?.workingLayout?.lightFixtures.isEmpty == true)
    }

    @Test func missingWorkingLayoutClonesBaselineOnlyOnSave() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let room = SampleData.createCozyBedroom()
        room.workingLayout = nil
        container.mainContext.insert(room)
        let original = room.baselineLayout?.lightFixtures
        let editor = LightingSetupViewModel(room: room)
        editor.place(unitX: 0.1, unitZ: 0.1, layer: .task)
        #expect(room.workingLayout == nil)
        try editor.save(in: room, context: container.mainContext)
        #expect(room.workingLayout !== room.baselineLayout)
        #expect(room.baselineLayout?.lightFixtures == original)
        #expect(room.workingLayout?.furnitures.count == room.baselineLayout?.furnitures.count)
        editor.place(unitX: 0.9, unitZ: 0.9, layer: .accent)
        try editor.save(in: room, context: container.mainContext)
        #expect(!editor.hasUnsavedChanges)
    }

    @Test func staleEditorCannotOverwriteResetLayout() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let room = SampleData.createCozyBedroom()
        container.mainContext.insert(room)
        let editor = LightingSetupViewModel(room: room)
        room.resetWorkingLayoutToBaseline()
        #expect(throws: LightingSetupViewModel.SaveError.layoutChanged) {
            try editor.save(in: room, context: container.mainContext)
        }
    }

    @Test func simulationSwitchesAreIndependentAndTimeIncludesNight() {
        var settings = LightingSimulationSettings(minuteOfDay: -90)
        let fixture = LightFixture(name: "Lamp", layer: .task, lumens: 1200, isOn: false)
        #expect(settings.timeLabel == "00:00")
        #expect(settings.output(for: fixture) == 0)
        var enabled = fixture
        enabled.isOn = true
        #expect(settings.output(for: enabled) == 1200)
        settings.artificialLightsOn = false
        #expect(settings.output(for: enabled) == 0)
        #expect(enabled.isOn)
        settings.minuteOfDay = 1500
        #expect(settings.timeLabel == "23:59")
        let engine = IlluminationSimulationEngine()
        #expect(engine.calculateDaylight(hourOfDay: 0).intensityLux == 0)
        #expect(engine.calculateDaylight(hourOfDay: 23).intensityLux == 0)
        #expect(engine.calculateDaylight(hourOfDay: 14).intensityLux > 9000)
    }

    @Test func rendererBudgetUsesBrightestEnabledFixtures() {
        let fixtures = (1...10).map { LightFixture(name: "Lamp \($0)", layer: .ambient, lumens: Double($0 * 100)) }
        var settings = LightingSimulationSettings()
        let rendered = settings.renderedFixtureIDs(in: fixtures)
        #expect(rendered.count == 7)
        #expect(rendered.contains(fixtures[9].id))
        #expect(!rendered.contains(fixtures[0].id))
        settings.layoutOnly = true
        #expect(settings.renderedFixtureIDs(in: fixtures).isEmpty)
    }

    @Test func baselineCannotBeUsedAsEditableLayout() throws {
        let container = try ModelContainer.createInMemoryContainer()
        let room = SampleData.createCozyBedroom()
        room.workingLayout = room.baselineLayout
        container.mainContext.insert(room)
        let original = room.baselineLayout?.lightFixturesData
        let editor = LightingSetupViewModel(room: room)
        editor.place(unitX: 0.1, unitZ: 0.1, layer: .ambient)
        #expect(throws: LightingSetupViewModel.SaveError.baselineIsReadOnly) {
            try editor.save(in: room, context: container.mainContext)
        }
        #expect(room.baselineLayout?.lightFixturesData == original)
    }

    @Test func previewSnapshotMatchesSavedPositionsAndExcludesArchivedFurniture() throws {
        let room = SampleData.createCozyBedroom()
        let layout = try #require(room.workingLayout)
        layout.furnitures.first?.isArchived = true
        let snapshot = LightingRoomSnapshot(room: room)
        #expect(snapshot.fixtures.map(\.id) == layout.lightFixtures.map(\.id))
        #expect(snapshot.furnishings.count == layout.furnitures.filter { !$0.isArchived }.count)
        #expect(snapshot.fixtures.allSatisfy { $0.elevationY <= room.dimensionsHeight - 0.08 })
        let original = snapshot.fixtures
        layout.lightFixtures = []
        #expect(snapshot.fixtures == original)
    }

    @Test func studioClockAndAppliedSimulationStayInSync() {
        let vm = Studio3DViewModel(room: SampleData.createStarterRoom(), stage: .illumination,
                                  mascotService: MockMascotAIService(), feedbackService: MockMascotFeedbackService())
        vm.lightingSettings = LightingSimulationSettings(artificialLightsOn: false, minuteOfDay: 1439)
        #expect(vm.daylightHour == 23 + 59.0 / 60)
        vm.daylightHour = 13 + 17.0 / 60
        #expect(vm.lightingSettings.timeLabel == "13:17")
        #expect(!vm.lightingSettings.artificialLightsOn)
    }

    @Test func cameraNavigationClampsZoomKeepsCameraAboveFloorAndResets() {
        let bounds = LightingRoomGeometry(width: 4, length: 5, height: 2.6)
        var navigation = LightingCameraNavigation()
        let initial = navigation.position(preset: .dollhouseIsometric, geometry: bounds)
        navigation.magnify(by: 100)
        #expect(navigation.zoom == 3)
        #expect(simd_distance(navigation.position(preset: .dollhouseIsometric, geometry: bounds), navigation.target(in: bounds))
                < simd_distance(initial, navigation.target(in: bounds)))
        navigation.orbit(deltaX: 200, deltaY: -10000)
        for preset in ViewportPreset.allCases {
            #expect(navigation.position(preset: preset, geometry: bounds).y > 0)
        }
        navigation.magnify(by: 0.001)
        #expect(navigation.zoom == 0.5)
        navigation.reset()
        #expect(navigation.position(preset: .dollhouseIsometric, geometry: bounds) == initial)
    }

    @Test func lightingCameraSupportsAllArchitecturalPresetsFromDev() {
        let bounds = LightingRoomGeometry(width: 4, length: 5, height: 2.6)
        let navigation = LightingCameraNavigation()
        #expect(navigation.position(preset: .front, geometry: bounds).z > 0)
        #expect(navigation.position(preset: .back, geometry: bounds).z < 0)
        #expect(navigation.position(preset: .left, geometry: bounds).x < 0)
        #expect(navigation.position(preset: .right, geometry: bounds).x > 0)
        #expect(navigation.position(preset: .top, geometry: bounds).y > Float(bounds.height))
    }
}
