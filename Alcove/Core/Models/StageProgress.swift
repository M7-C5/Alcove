import Foundation
import SwiftData

@Model
public final class StageProgress {
    public var id: UUID
    public var stageRaw: String
    public var isCompleted: Bool
    public var isUnlocked: Bool
    public var score: Int
    public var feedback: String
    public var completedAt: Date?

    public var room: Room?

    public var stage: StageType {
        get { StageType(rawValue: stageRaw) ?? .audit }
        set { stageRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        stage: StageType,
        isCompleted: Bool = false,
        isUnlocked: Bool = false,
        score: Int = 0,
        feedback: String = "",
        completedAt: Date? = nil
    ) {
        self.id = id
        self.stageRaw = stage.rawValue
        self.isCompleted = isCompleted
        self.isUnlocked = isUnlocked
        self.score = score
        self.feedback = feedback
        self.completedAt = completedAt
    }
}
