import Foundation
import Observation

@Observable
@MainActor
public final class MascotChatViewModel {
    public let mascotService: any MascotAIServiceProtocol
    public let feedbackService: (any MascotFeedbackServiceProtocol)?
    public let currentStage: StageType
    public let room: Room
    private let onHistoryUpdated: (([ChatMessage]) -> Void)?

    public var chatHistory: [ChatMessage]
    public var inputPrompt: String = ""
    public var isThinking: Bool = false

    public init(
        mascotService: any MascotAIServiceProtocol,
        feedbackService: (any MascotFeedbackServiceProtocol)? = nil,
        currentStage: StageType,
        room: Room,
        initialHistory: [ChatMessage] = [],
        onHistoryUpdated: (([ChatMessage]) -> Void)? = nil
    ) {
        self.mascotService = mascotService
        self.feedbackService = feedbackService
        self.currentStage = currentStage
        self.room = room
        self.chatHistory = initialHistory
        self.onHistoryUpdated = onHistoryUpdated
    }

    @discardableResult
    public func sendMessage() -> Task<Void, Never>? {
        let trimmed = inputPrompt.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isThinking else { return nil }

        let priorHistory = chatHistory
        inputPrompt = ""
        chatHistory.append(ChatMessage(isUser: true, text: trimmed))
        onHistoryUpdated?(chatHistory)
        isThinking = true
        feedbackService?.playImpact(.light)

        return Task {
            let response = await mascotService.askMascot(
                question: trimmed,
                currentStage: currentStage,
                room: room,
                history: priorHistory
            )
            let badge = mascotService.activeModelBadge

            self.chatHistory.append(ChatMessage(isUser: false, text: response, modelBadge: badge))
            self.onHistoryUpdated?(self.chatHistory)
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
