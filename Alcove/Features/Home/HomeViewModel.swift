import Foundation
import Observation

@Observable
@MainActor
public final class HomeViewModel {
    public var hasEnteredDashboard: Bool = false

    public init() {}

    public func start() {
        hasEnteredDashboard = true
    }
}
