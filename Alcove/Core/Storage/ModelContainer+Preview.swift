import Foundation
import SwiftData

extension ModelContainer {
    /// Creates an isolated in-memory container for unit testing.
    @MainActor
    public static func createInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Room.self,
            Layout.self,
            Furniture.self,
            StageProgress.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    /// Creates an in-memory container seeded with rich sample rooms for SwiftUI Previews.
    @MainActor
    public static func createPreviewContainer() throws -> ModelContainer {
        let container = try createInMemoryContainer()
        let context = container.mainContext

        let studio = SampleData.createStarterRoom()
        let bedroom = SampleData.createCozyBedroom()

        context.insert(studio)
        context.insert(bedroom)
        try? context.save()

        return container
    }
}
