import Foundation
import SwiftData
import Observation

@Observable
@MainActor
public final class StageListViewModel {
    public var room: Room
    public var showingResetConfirmation: Bool = false

    public var completedStagesCount: Int {
        room.stageProgress.filter { $0.isCompleted }.count
    }

    public var totalStagesCount: Int {
        StageType.allCases.count
    }

    public var progressRatio: Double {
        guard totalStagesCount > 0 else { return 0.0 }
        return Double(completedStagesCount) / Double(totalStagesCount)
    }

    public init(room: Room) {
        self.room = room
    }

    public func resetWorkingLayoutToBaseline() {
        room.resetWorkingLayoutToBaseline()
    }
}
