import Foundation
import Observation

public struct ChatMessage: Identifiable, Sendable {
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

@Observable
@MainActor
public final class MascotChatViewModel {
    public let mascotService: any MascotAIServiceProtocol
    public let feedbackService: (any MascotFeedbackServiceProtocol)?
    public let currentStage: StageType
    public let room: Room

    public var chatHistory: [ChatMessage] = []
    public var inputPrompt: String = ""
    public var isThinking: Bool = false

    public init(
        mascotService: any MascotAIServiceProtocol,
        feedbackService: (any MascotFeedbackServiceProtocol)? = nil,
        currentStage: StageType,
        room: Room
    ) {
        self.mascotService = mascotService
        self.feedbackService = feedbackService
        self.currentStage = currentStage
        self.room = room
    }

    @discardableResult
    public func sendMessage() -> Task<Void, Never>? {
        let trimmed = inputPrompt.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isThinking else { return nil }

        inputPrompt = ""
        chatHistory.append(ChatMessage(isUser: true, text: trimmed))
        isThinking = true
        feedbackService?.playImpact(.light)

        return Task {
            let response = await mascotService.askMascot(
                question: trimmed,
                currentStage: currentStage,
                room: room
            )
            let badge: String
            if LLMMascotAIService.shared.apiKey.isEmpty {
                badge = "📖 Local Engine"
            } else if LLMMascotAIService.shared.isQuotaExhausted {
                badge = "📖 Local Engine (Cloud Quota Resting)"
            } else {
                badge = "✨ \(LLMMascotAIService.shared.provider.rawValue)"
            }

            self.chatHistory.append(ChatMessage(isUser: false, text: response, modelBadge: badge))
            self.isThinking = false
            self.feedbackService?.playNotification(.success)
            self.feedbackService?.speak(response)
        }
    }

    @discardableResult
    public func selectSuggestion(_ text: String) -> Task<Void, Never>? {
        inputPrompt = text
        return sendMessage()
    }
}
