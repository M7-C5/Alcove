import Foundation
import Testing
import SwiftData
@testable import Alcove

@Suite("Dashboard Slice Tests") @MainActor
struct DashboardViewModelTests {

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Room.self,
            Layout.self,
            Furniture.self,
            StageProgress.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test func viewModelInitialState() {
        let vm = DashboardViewModel()
        #expect(vm.showingScanSheet == false)
        #expect(vm.lightingTestSession == nil)
    }

    @Test func lightingShortcutOpensUnlockedMockRoomInTemporaryStore() throws {
        let mainContainer = try makeInMemoryContainer()
        let mainRoom = SampleData.createStarterRoom()
        mainContainer.mainContext.insert(mainRoom)
        try mainContainer.mainContext.save()
        let vm = DashboardViewModel()

        vm.startLightingTest()

        let session = try #require(vm.lightingTestSession)
        #expect(vm.lightingTestError == nil)
        #expect(session.room.name == "Lighting Playground")
        #expect(session.room.isUnlocked(.illumination))
        #expect(!session.room.isCompleted(.audit))
        #expect(!session.room.isCompleted(.rearrangement))
        #expect(session.room.workingLayout?.furnitures.count == 6)
        #expect(session.room.workingLayout?.lightFixtures.isEmpty == true)
        #expect(session.container.configurations.allSatisfy { $0.isStoredInMemoryOnly })

        let editor = LightingSetupViewModel(room: session.room)
        editor.place(unitX: 0.25, unitZ: 0.75, layer: .ambient)
        try editor.save(in: session.room, context: session.container.mainContext)
        #expect(session.room.workingLayout?.lightFixtures.count == 1)
        let mainRooms = try mainContainer.mainContext.fetch(FetchDescriptor<Room>())
        #expect(mainRooms.count == 1)
        #expect(mainRooms.first?.id == mainRoom.id)
        #expect(mainRoom.workingLayout?.lightFixtures.isEmpty == true)
    }

    @Test func reopeningLightingShortcutStartsFreshMockLayout() throws {
        let vm = DashboardViewModel()
        vm.startLightingTest()
        let first = try #require(vm.lightingTestSession)
        let editor = LightingSetupViewModel(room: first.room)
        editor.place(unitX: 0.5, unitZ: 0.5, layer: .ambient)
        try editor.save(in: first.room, context: first.container.mainContext)
        vm.lightingTestSession = nil

        vm.startLightingTest()

        let reopened = try #require(vm.lightingTestSession)
        #expect(reopened.room.id != first.room.id)
        #expect(reopened.room.workingLayout?.lightFixtures.isEmpty == true)
        #expect(reopened.router.isEmpty)
    }

    @Test func seedInitialDataWhenEmpty() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let vm = DashboardViewModel()

        vm.seedInitialDataIfNeeded(rooms: [], modelContext: context)

        let descriptor = FetchDescriptor<Room>()
        let rooms = try context.fetch(descriptor)
        #expect(rooms.count == 1)
        #expect(rooms.first?.name == "Sample Studio Apartment")
    }

    @Test func seedInitialDataWhenAlreadyPopulated() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let existingRoom = SampleData.createStarterRoom()
        context.insert(existingRoom)

        let vm = DashboardViewModel()
        vm.seedInitialDataIfNeeded(rooms: [existingRoom], modelContext: context, force: false)

        let descriptor = FetchDescriptor<Room>()
        let rooms = try context.fetch(descriptor)
        #expect(rooms.count == 1)
    }

    @Test func addScannedRoomInsertsAndDismissesSheet() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let vm = DashboardViewModel()
        vm.showingScanSheet = true

        let scanned = Room(name: "Scanned Bedroom")
        vm.addScannedRoom(scanned, modelContext: context)

        #expect(vm.showingScanSheet == false)
        let descriptor = FetchDescriptor<Room>()
        let rooms = try context.fetch(descriptor)
        #expect(rooms.contains { $0.name == "Scanned Bedroom" })
    }

    @Test func seedCozyBedroomInsertsMultiLayerRoom() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let vm = DashboardViewModel()

        vm.seedCozyBedroom(modelContext: context)

        let descriptor = FetchDescriptor<Room>()
        let rooms = try context.fetch(descriptor)
        #expect(rooms.count == 1)
        #expect(rooms.first?.name == "Cozy Master Bedroom")
        #expect(rooms.first?.workingLayout?.lightFixtures.count == 3)
    }

    @Test func seedBedroomOfficeComboInsertsMockRoom() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let vm = DashboardViewModel()

        vm.seedBedroomOfficeCombo(modelContext: context)

        let descriptor = FetchDescriptor<Room>()
        let rooms = try context.fetch(descriptor)
        #expect(rooms.count == 1)
        #expect(rooms.first?.name == "Bedroom & Office Combo")
        #expect(rooms.first?.workingLayout?.furnitures.count == 6)
    }
}
