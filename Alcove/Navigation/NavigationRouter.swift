import SwiftUI
import Observation

/// Programmatic navigation router managing the `NavigationPath` for Alcove.
@Observable
@MainActor
public final class NavigationRouter {
    public var path = NavigationPath() {
        didSet {
            if path.count < routes.count {
                routes.removeLast(routes.count - path.count)
            }
        }
    }
    public private(set) var routes: [AlcoveRoute] = []

    public init() {}

    public var count: Int {
        path.count
    }

    public var isEmpty: Bool {
        path.isEmpty
    }

    public func push(_ route: AlcoveRoute) {
        routes.append(route)
        path.append(route)
    }

    public func pop() {
        if !routes.isEmpty {
            routes.removeLast()
        }
        if !path.isEmpty {
            path.removeLast()
        }
    }

    public func popToRoot() {
        routes.removeAll()
        path = NavigationPath()
    }
}
