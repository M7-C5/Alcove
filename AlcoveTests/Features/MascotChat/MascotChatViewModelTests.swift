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

    @Test func followUpPassesHistoryAndPersistsAcrossDrawerReopen() async {
        @MainActor
        final class RecordingMascotService: MascotAIServiceProtocol {
            private let delegate = MockMascotAIService()
            var recordedHistories: [[ChatMessage]] = []

            func stageGreeting(stage: StageType, roomName: String) -> String {
                delegate.stageGreeting(stage: stage, roomName: roomName)
            }

            func microReact(
                event: FurnitureMoveEvent,
                roomDimensions: (width: Double, length: Double),
                allFurnitures: [Furniture]
            ) -> MicroReaction? { nil }

            func daylightMicroReact(hour: Double, room: Room) -> MicroReaction? { nil }

            func evaluateStage(stage: StageType, room: Room) async -> StageEvaluationResult {
                await delegate.evaluateStage(stage: stage, room: room)
            }

            func askMascot(question: String, currentStage: StageType, room: Room, history: [ChatMessage]) async -> String {
                recordedHistories.append(history)
                return await delegate.askMascot(question: question, currentStage: currentStage, room: room, history: history)
            }
        }

        let room = SampleData.createStarterRoom()
        let spyService = RecordingMascotService()
        var persistedHistory: [ChatMessage] = []

        let vm = MascotChatViewModel(
            mascotService: spyService,
            currentStage: .rearrangement,
            room: room,
            initialHistory: persistedHistory,
            onHistoryUpdated: { persistedHistory = $0 }
        )

        vm.inputPrompt = "Where do u think I should place my bed when I wanna go near my desk"
        await vm.sendMessage()?.value

        #expect(spyService.recordedHistories.count == 1)
        #expect(spyService.recordedHistories[0].isEmpty)
        #expect(persistedHistory.count == 2)

        // Simulate closing and reopening the chat drawer with persisted studio state
        let reopenedVM = MascotChatViewModel(
            mascotService: spyService,
            currentStage: .rearrangement,
            room: room,
            initialHistory: persistedHistory,
            onHistoryUpdated: { persistedHistory = $0 }
        )

        #expect(reopenedVM.chatHistory == persistedHistory)

        reopenedVM.inputPrompt = "But where"
        await reopenedVM.sendMessage()?.value

        #expect(spyService.recordedHistories.count == 2)
        #expect(spyService.recordedHistories[1].count == 2)
        #expect(persistedHistory.count == 4)

        let reply = reopenedVM.chatHistory.last?.text ?? ""
        #expect(reply.contains("Back-Right") || reply.contains("Front-Right"))
    }

    @Test @MainActor func usesInjectedServiceModelBadgeRatherThanSharedSingleton() async {
        let originalDevKey = LLMMascotAIService.hardcodedDeveloperKey
        LLMMascotAIService.hardcodedDeveloperKey = "shared_key_should_not_leak_badge"
        defer {
            LLMMascotAIService.hardcodedDeveloperKey = originalDevKey
        }

        let room = SampleData.createStarterRoom()
        let vm = MascotChatViewModel(
            mascotService: MockMascotAIService(),
            currentStage: .audit,
            room: room
        )

        vm.inputPrompt = "How is the room layout?"
        await vm.sendMessage()?.value

        #expect(vm.chatHistory.last?.modelBadge == "📖 Local Engine")
    }
}
