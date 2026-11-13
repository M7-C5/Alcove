import Foundation

/// Severity of a detected spatial bottleneck
public enum BottleneckSeverity: String, Codable, Sendable {
    case notice
    case warning
    case critical

    public var badgeColor: String {
        switch self {
        case .notice: return "blue"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }
}

/// A spatial bottleneck identified during an audit or stage evaluation
public struct SpatialBottleneck: Identifiable, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let detail: String
    public let severity: BottleneckSeverity
    public let affectedFurnitureName: String?

    public init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        severity: BottleneckSeverity,
        affectedFurnitureName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.severity = severity
        self.affectedFurnitureName = affectedFurnitureName
    }
}

/// Outcome of a stage evaluation gate
public struct StageEvaluationResult: Sendable {
    public let canAdvance: Bool
    public let score: Int
    public let title: String
    public let dialogue: String
    public let bottlenecks: [SpatialBottleneck]
    public let recommendations: [String]
    public let praise: [String]

    public init(
        canAdvance: Bool,
        score: Int,
        title: String,
        dialogue: String,
        bottlenecks: [SpatialBottleneck],
        recommendations: [String],
        praise: [String]
    ) {
        self.canAdvance = canAdvance
        self.score = score
        self.title = title
        self.dialogue = dialogue
        self.bottlenecks = bottlenecks
        self.recommendations = recommendations
        self.praise = praise
    }
}

/// Mascot emotional state for UI avatar / speech bubble
public enum MascotEmotion: String, Codable, Sendable {
    case neutral
    case curious
    case happy
    case thinking
    case warning
    case celebrating

    public var emoji: String {
        switch self {
        case .neutral: return "🛋️"
        case .curious: return "🧐"
        case .happy: return "✨"
        case .thinking: return "🤔"
        case .warning: return "⚠️"
        case .celebrating: return "🎉"
        }
    }
}

/// Micro-reaction message returned from fast-path local heuristics
public struct MicroReaction: Sendable {
    public let message: String
    public let emotion: MascotEmotion

    public init(message: String, emotion: MascotEmotion) {
        self.message = message
        self.emotion = emotion
    }
}

/// Core protocol for the Mascot AI system
@MainActor
public protocol MascotAIServiceProtocol: Sendable {
    /// Onboarding introductory dialogue for a stage
    func stageGreeting(stage: StageType, roomName: String) -> String

    /// Sub-100ms micro-reaction to interactive layout edits
    func microReact(
        event: FurnitureMoveEvent,
        roomDimensions: (width: Double, length: Double),
        allFurnitures: [Furniture]
    ) -> MicroReaction?

    /// Sub-100ms micro-reaction to natural daylight scrubbing in Stage 3 (Illumination)
    func daylightMicroReact(
        hour: Double,
        room: Room
    ) -> MicroReaction?

    /// Comprehensive evaluation gate to assess if user can proceed
    func evaluateStage(
        stage: StageType,
        room: Room
    ) async -> StageEvaluationResult

    /// LLM-powered context-aware interior design dialogue
    func askMascot(
        question: String,
        currentStage: StageType,
        room: Room,
        history: [ChatMessage]
    ) async -> String

    /// Display badge describing the active reasoning engine (cloud provider or local engine)
    var activeModelBadge: String { get }
}

public struct ChatMessage: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let isUser: Bool
    public let text: String
    public let modelBadge: String?

    public init(id: UUID = UUID(), isUser: Bool, text: String, modelBadge: String? = nil) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.modelBadge = modelBadge
    }
}

public extension MascotAIServiceProtocol {
    var activeModelBadge: String {
        "📖 Local Engine"
    }

    func askMascot(
        question: String,
        currentStage: StageType,
        room: Room
    ) async -> String {
        await askMascot(question: question, currentStage: currentStage, room: room, history: [])
    }
}

public struct FurnitureMoveEvent: Sendable {
    public let furnitureName: String
    public let category: FurnitureCategory
    public let oldPosition: (x: Double, z: Double)
    public let newPosition: (x: Double, z: Double)
    public let rotationYaw: Double

    public init(
        furnitureName: String,
        category: FurnitureCategory,
        oldPosition: (x: Double, z: Double),
        newPosition: (x: Double, z: Double),
        rotationYaw: Double
    ) {
        self.furnitureName = furnitureName
        self.category = category
        self.oldPosition = oldPosition
        self.newPosition = newPosition
        self.rotationYaw = rotationYaw
    }
}

public enum SpatialWarningSeverity: String, Codable, Sendable, Comparable {
    case caution   // Yellow: tight clearance or layout improvement ("can be better")
    case collision // Red: physical overlap / collision or blocked doorway

    public static func < (lhs: SpatialWarningSeverity, rhs: SpatialWarningSeverity) -> Bool {
        lhs == .caution && rhs == .collision
    }
}

public struct SpatialWarning: Identifiable, Equatable, Sendable {
    public let id: String
    public let severity: SpatialWarningSeverity
    public let furnitureIDs: Set<UUID>
    public let title: String
    public let message: String

    public init(
        id: String,
        severity: SpatialWarningSeverity,
        furnitureIDs: Set<UUID>,
        title: String,
        message: String
    ) {
        self.id = id
        self.severity = severity
        self.furnitureIDs = furnitureIDs
        self.title = title
        self.message = message
    }
}
