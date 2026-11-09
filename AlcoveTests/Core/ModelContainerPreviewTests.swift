import Foundation
import SwiftData
import Testing
@testable import Alcove

@Suite("ModelContainer & Preview Tests") @MainActor
struct ModelContainerPreviewTests {

    @Test func inMemoryContainerCreation() throws {
        let container = try ModelContainer.createInMemoryContainer()
        #expect(!container.configurations.isEmpty)
    }

    @Test func previewContainerSeeding() throws {
        let container = try ModelContainer.createPreviewContainer()
        let context = container.mainContext

        let descriptor = FetchDescriptor<Room>()
        let rooms = try context.fetch(descriptor)

        #expect(rooms.count == 2)
        #expect(rooms.contains { $0.name == "Sample Studio Apartment" })
        #expect(rooms.contains { $0.name == "Cozy Master Bedroom" })
    }

    @Test func layoutFixturePersistenceRoundtrip() {
        let room = SampleData.createCozyBedroom()
        let layout = room.workingLayout
        #expect(layout != nil)

        let initialFixturesCount = layout?.lightFixtures.count ?? 0
        #expect(initialFixturesCount == 3)

        // Clone layout and verify fixtures are preserved
        let cloned = layout?.createCopy(name: "Cloned Layout", isBaseline: false)
        #expect(cloned?.lightFixtures.count == initialFixturesCount)
        #expect(cloned?.lightFixtures.first?.name == "Ceiling Flushmount")
    }
}
