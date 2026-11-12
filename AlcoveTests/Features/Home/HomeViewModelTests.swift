import Foundation
import Testing
@testable import Alcove

@Suite("Home Slice Tests") @MainActor
struct HomeViewModelTests {

    @Test func homeViewModelInitialState() {
        let vm = HomeViewModel()
        #expect(vm.hasEnteredDashboard == false)
    }

    @Test func startEntersDashboard() {
        let vm = HomeViewModel()
        vm.start()
        #expect(vm.hasEnteredDashboard == true)
    }
}
