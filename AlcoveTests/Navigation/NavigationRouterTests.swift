import Foundation
import Testing
@testable import Alcove

@Suite("Navigation Router Tests") @MainActor
struct NavigationRouterTests {

    @Test func initializationState() {
        let router = NavigationRouter()
        #expect(router.isEmpty)
        #expect(router.count == 0)
        #expect(router.routes.isEmpty)
    }

    @Test func pushAndPopRoutes() {
        let router = NavigationRouter()
        let room = SampleData.createStarterRoom()

        router.push(.stageList(room))
        #expect(!router.isEmpty)
        #expect(router.count == 1)
        #expect(router.routes.first == .stageList(room))

        router.push(.studio(room: room, stage: .rearrangement))
        #expect(router.count == 2)
        #expect(router.routes.last == .studio(room: room, stage: .rearrangement))

        router.pop()
        #expect(router.count == 1)
        #expect(router.routes.last == .stageList(room))

        router.pop()
        #expect(router.isEmpty)
        #expect(router.count == 0)

        // Extra pop on empty router does not crash
        router.pop()
        #expect(router.isEmpty)
    }

    @Test func popToRootResetsAllRoutes() {
        let router = NavigationRouter()
        let room = SampleData.createStarterRoom()

        router.push(.stageList(room))
        router.push(.studio(room: room, stage: .audit))
        router.push(.studio(room: room, stage: .illumination))
        #expect(router.count == 3)

        router.popToRoot()
        #expect(router.isEmpty)
        #expect(router.count == 0)
        #expect(router.routes.isEmpty)
    }

    @Test func alcoveRouteEqualityAndHash() {
        let roomA = SampleData.createStarterRoom()
        let roomB = SampleData.createStarterRoom()

        let route1 = AlcoveRoute.stageList(roomA)
        let route2 = AlcoveRoute.stageList(roomA)
        let route3 = AlcoveRoute.stageList(roomB)

        #expect(route1 == route2)
        #expect(route1 != route3)

        let studioRoute1 = AlcoveRoute.studio(room: roomA, stage: .audit)
        let studioRoute2 = AlcoveRoute.studio(room: roomA, stage: .audit)
        let studioRoute3 = AlcoveRoute.studio(room: roomA, stage: .rearrangement)

        #expect(studioRoute1 == studioRoute2)
        #expect(studioRoute1 != studioRoute3)
        #expect(route1 != studioRoute1)

        let dashRoute1 = AlcoveRoute.dashboard
        let dashRoute2 = AlcoveRoute.dashboard
        #expect(dashRoute1 == dashRoute2)
        #expect(dashRoute1 != route1)
        #expect(dashRoute1 != studioRoute1)

        var set = Set<AlcoveRoute>()
        set.insert(route1)
        set.insert(route2)
        set.insert(studioRoute1)
        set.insert(dashRoute1)
        set.insert(dashRoute2)
        #expect(set.count == 3)
    }

    @Test func navigationPathDirectBindingSync() {
        let router = NavigationRouter()
        let room = SampleData.createStarterRoom()

        // Simulating SwiftUI NavigationLink(value:) appending directly to router.path
        router.path.append(AlcoveRoute.stageList(room))
        #expect(!router.isEmpty)
        #expect(router.count == 1)

        router.path.append(AlcoveRoute.studio(room: room, stage: .audit))
        #expect(router.count == 2)

        // Programmatic pop pops the underlying path
        router.pop()
        #expect(router.count == 1)

        router.pop()
        #expect(router.isEmpty)
        #expect(router.count == 0)
    }

    @Test func pathReductionSynchronizesRoutes() {
        let router = NavigationRouter()
        let room = SampleData.createStarterRoom()

        router.push(.stageList(room))
        router.push(.studio(room: room, stage: .rearrangement))
        #expect(router.routes.count == 2)
        #expect(router.count == 2)

        // Simulate swipe-back gesture popping path
        router.path.removeLast()
        #expect(router.count == 1)
        #expect(router.routes.count == 1)
        #expect(router.routes.last == .stageList(room))
    }
}
