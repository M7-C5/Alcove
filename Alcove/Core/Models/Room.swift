import Foundation
import SwiftData

@Model
public final class Room {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var dimensionsWidth: Double
    public var dimensionsLength: Double
    public var dimensionsHeight: Double
    /// Optional payload lets existing rooms migrate without inventing a north reference.
    public var compassOrientationData: Data? = nil

    public var compassOrientation: RoomCompassOrientation? {
        get {
            guard let data = compassOrientationData,
                  let value = try? JSONDecoder().decode(RoomCompassOrientation.self, from: data), value.isValid else { return nil }
            return value
        }
        set { compassOrientationData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    @Relationship(deleteRule: .cascade)
    public var baselineLayout: Layout?

    @Relationship(deleteRule: .cascade)
    public var workingLayout: Layout?

    @Relationship(deleteRule: .cascade, inverse: \StageProgress.room)
    public var stageProgress: [StageProgress]

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        dimensionsWidth: Double = 4.0,
        dimensionsLength: Double = 5.0,
        dimensionsHeight: Double = 2.6,
        baselineLayout: Layout? = nil,
        workingLayout: Layout? = nil,
        stageProgress: [StageProgress] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.dimensionsWidth = dimensionsWidth
        self.dimensionsLength = dimensionsLength
        self.dimensionsHeight = dimensionsHeight
        self.baselineLayout = baselineLayout
        self.workingLayout = workingLayout
        self.stageProgress = stageProgress

        if self.stageProgress.isEmpty {
            self.stageProgress = [
                StageProgress(stage: .audit, isCompleted: false, isUnlocked: true),
                StageProgress(stage: .rearrangement, isCompleted: false, isUnlocked: false),
                StageProgress(stage: .illumination, isCompleted: false, isUnlocked: false),
                StageProgress(stage: .harmony, isCompleted: false, isUnlocked: false)
            ]
        }
    }

    public func progress(for stage: StageType) -> StageProgress? {
        stageProgress.first { $0.stage == stage }
    }

    public func isUnlocked(_ stage: StageType) -> Bool {
        progress(for: stage)?.isUnlocked ?? false
    }

    public func isCompleted(_ stage: StageType) -> Bool {
        progress(for: stage)?.isCompleted ?? false
    }

    public func completeStage(_ stage: StageType, score: Int, feedback: String) {
        if let current = progress(for: stage) {
            current.isCompleted = true
            current.score = score
            current.feedback = feedback
            current.completedAt = Date()
        }

        if let next = stage.nextStage, let nextProgress = progress(for: next) {
            nextProgress.isUnlocked = true
        }
    }

    /// Resets the working layout back to the baseline scan
    public func resetWorkingLayoutToBaseline() {
        guard let baseline = baselineLayout else { return }
        let resetCopy = baseline.createCopy(name: "Working Layout (Reset)", isBaseline: false)
        resetCopy.room = self
        self.workingLayout = resetCopy
    }
}
