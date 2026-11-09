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
}
