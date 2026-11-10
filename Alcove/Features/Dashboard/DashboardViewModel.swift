import Foundation
import SwiftData
import Observation

@Observable
@MainActor
public final class DashboardViewModel {
    public var showingScanSheet: Bool = false

    public init() {}

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
