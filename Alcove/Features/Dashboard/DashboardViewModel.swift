import Foundation
import SwiftData
import Observation

@Observable
@MainActor
public final class DashboardViewModel {
    public var showingScanSheet: Bool = false
    var lightingTestSession: LightingTestSession?
    var lightingTestError: String?

    public init() {}

    func startLightingTest() {
        do {
            let container = try ModelContainer.createInMemoryContainer()
            let room = MockRoomGenerator.generateBedroomOfficeCombo(name: "Lighting Playground")
            room.progress(for: .illumination)?.isUnlocked = true
            container.mainContext.insert(room)
            try container.mainContext.save()
            lightingTestError = nil
            lightingTestSession = LightingTestSession(room: room, container: container)
        } catch {
            lightingTestError = error.localizedDescription
        }
    }

    public func seedInitialDataIfNeeded(rooms: [Room], modelContext: ModelContext, force: Bool = false) {
        if rooms.isEmpty || force {
            let sample = SampleData.createStarterRoom()
            modelContext.insert(sample)
        }
    }

    public func seedCozyBedroom(modelContext: ModelContext) {
        let bedroom = SampleData.createCozyBedroom()
        modelContext.insert(bedroom)
    }

    public func seedBedroomOfficeCombo(modelContext: ModelContext) {
        let bedroomOffice = MockRoomGenerator.generateBedroomOfficeCombo()
        modelContext.insert(bedroomOffice)
    }

    public func addScannedRoom(_ room: Room, modelContext: ModelContext) {
        modelContext.insert(room)
        showingScanSheet = false
    }
}

/// A temporary lighting playground with its own SwiftData lifetime.
@MainActor
struct LightingTestSession: Identifiable {
    let id = UUID()
    let room: Room
    let container: ModelContainer
    let router = NavigationRouter()
}
