import Foundation
import Testing
@testable import Alcove

@Suite("MascotChat Slice Tests") @MainActor
struct MascotChatViewModelTests {

    @Test func initializationState() {
        let room = SampleData.createStarterRoom()
        let mascot = MockMascotAIService()
        let vm = MascotChatViewModel(
            mascotService: mascot,
            currentStage: .rearrangement,
            room: room
        )

        #expect(vm.chatHistory.isEmpty)
        #expect(vm.inputPrompt.isEmpty)
        #expect(vm.isThinking == false)
    }

    @Test func sendMessageAppendsAndReceivesResponse() async {
        let room = SampleData.createStarterRoom()
        let mascot = MockMascotAIService()
        let vm = MascotChatViewModel(
            mascotService: mascot,
            currentStage: .rearrangement,
            room: room
        )

        vm.inputPrompt = "What clearance do I need for walkways?"
        let task = vm.sendMessage()

        #expect(vm.chatHistory.first?.isUser == true)
        #expect(vm.chatHistory.first?.text.contains("clearance") == true)

        // Wait deterministically for task completion without arbitrary thread sleep
        await task?.value

        #expect(vm.chatHistory.count == 2)
        #expect(vm.chatHistory.last?.isUser == false)
        #expect(vm.chatHistory.last?.text.contains("Panero & Zelnik") == true || vm.chatHistory.last?.text.contains("60cm") == true)
        #expect(vm.isThinking == false)
    }

    @Test func emptyMessageIgnored() {
        let room = SampleData.createStarterRoom()
        let mascot = MockMascotAIService()
        let vm = MascotChatViewModel(
            mascotService: mascot,
            currentStage: .audit,
            room: room
        )

        vm.inputPrompt = "   "
        let task = vm.sendMessage()

        #expect(task == nil)
        #expect(vm.chatHistory.isEmpty)
    }

    @Test func selectSuggestionDispatchesMessage() async {
        let room = SampleData.createStarterRoom()
        let mascot = MockMascotAIService()
        let vm = MascotChatViewModel(
            mascotService: mascot,
            currentStage: .illumination,
            room: room
        )

        let task = vm.selectSuggestion("Tips for window lighting")
        #expect(vm.chatHistory.first?.isUser == true)

        await task?.value
        #expect(vm.chatHistory.count == 2)
        #expect(vm.chatHistory.last?.isUser == false)
    }

    @Test func messageIgnoredWhenAlreadyThinking() async {
        let room = SampleData.createStarterRoom()
        let mascot = MockMascotAIService()
        let vm = MascotChatViewModel(
            mascotService: mascot,
            currentStage: .audit,
            room: room
        )

        vm.inputPrompt = "First message"
        let task1 = vm.sendMessage()

        vm.inputPrompt = "Second message while thinking"
        let task2 = vm.sendMessage()
        #expect(task2 == nil)

        await task1?.value
        #expect(vm.chatHistory.count == 2)
    }

    @Test func chatWithFeedbackServiceTriggersHapticsAndSpeech() async {
        let room = SampleData.createStarterRoom()
        let mascot = MockMascotAIService()
        let feedback = MockMascotFeedbackService()
        feedback.isVoiceNarrationEnabled = true

        let vm = MascotChatViewModel(
            mascotService: mascot,
            feedbackService: feedback,
            currentStage: .illumination,
            room: room
        )

        vm.inputPrompt = "Tell me about lighting"
        let task = vm.sendMessage()

        #expect(feedback.playedImpacts.contains(.light))

        await task?.value
        #expect(feedback.playedNotifications.contains(.success))
        #expect(!feedback.spokenTexts.isEmpty)
    }
}
