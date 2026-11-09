import Foundation
import SwiftData

/// Strongly-typed routes for value-based navigation across Alcove slices.
public enum AlcoveRoute: Hashable, Sendable {
    case stageList(Room)
    case studio(room: Room, stage: StageType)

    public static func == (lhs: AlcoveRoute, rhs: AlcoveRoute) -> Bool {
        switch (lhs, rhs) {
        case let (.stageList(lhsRoom), .stageList(rhsRoom)):
            return lhsRoom.id == rhsRoom.id
        case let (.studio(lhsRoom, lhsStage), .studio(rhsRoom, rhsStage)):
            return lhsRoom.id == rhsRoom.id && lhsStage == rhsStage
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .stageList(let room):
            hasher.combine(0)
            hasher.combine(room.id)
        case .studio(let room, let stage):
            hasher.combine(1)
            hasher.combine(room.id)
            hasher.combine(stage)
        }
    }
}
