import Foundation
import SwiftData
import Observation

@Observable
@MainActor
public final class Studio3DViewModel {
    public var room: Room
    public var currentStage: StageType
    public let mascotService: any MascotAIServiceProtocol
    public var feedbackService: any MascotFeedbackServiceProtocol

    // Interactive selection & Mascot reaction state
    public var selectedFurnitureID: UUID?
    public var mascotMessage: String = ""
    public var mascotEmotion: MascotEmotion = .neutral

    // Spatial Viewport Camera & Gestures (Area 4)
    public var cameraState = SpatialViewportCameraState()

    // Stage 3 Illumination state & contracts (Area 1)
    public var daylightHour: Double = 12.0 // 12 PM noon
    public let illuminationEngine = IlluminationSimulationEngine()

    // Stage 4 Harmony Reveal state & contracts (Area 2)
    public var beforeAfterSplit: Double = 0.5 // Split slider
    public var revealMode: HarmonyRevealMode = .splitSlider
    public let harmonyEngine = HarmonySynthesisEngine()

    // Modal dialog presentation state
    public var showingChatDrawer: Bool = false
    public var showingEvaluationSheet: Bool = false
    public var evaluationResult: StageEvaluationResult?
    public var isEvaluating: Bool = false

    public init(
        room: Room,
        stage: StageType,
        mascotService: any MascotAIServiceProtocol,
        feedbackService: any MascotFeedbackServiceProtocol
    ) {
        self.room = room
        self.currentStage = stage
        self.mascotService = mascotService
        self.feedbackService = feedbackService
        updateMascotGreeting()
    }

    public convenience init(
        room: Room,
        stage: StageType,
        mascotService: any MascotAIServiceProtocol
    ) {
        self.init(
            room: room,
            stage: stage,
            mascotService: mascotService,
            feedbackService: SystemMascotFeedbackService()
        )
    }

    public convenience init(
        room: Room,
        stage: StageType
    ) {
        self.init(
            room: room,
            stage: stage,
            mascotService: MockMascotAIService(),
            feedbackService: SystemMascotFeedbackService()
        )
    }

    public var isVoiceNarrationEnabled: Bool {
        get { feedbackService.isVoiceNarrationEnabled }
        set { feedbackService.isVoiceNarrationEnabled = newValue }
    }

    public func toggleVoiceNarration() {
        feedbackService.isVoiceNarrationEnabled.toggle()
        if feedbackService.isVoiceNarrationEnabled {
            feedbackService.playImpact(.light)
            feedbackService.speak("Voice narration enabled")
        } else {
            feedbackService.stopSpeaking()
        }
    }

    public var selectedFurniture: Furniture? {
        guard let id = selectedFurnitureID else { return nil }
        return room.workingLayout?.furnitures.first { $0.id == id }
    }

    public func updateMascotGreeting() {
        mascotMessage = mascotService.stageGreeting(stage: currentStage, roomName: room.name)
        mascotEmotion = .neutral
        feedbackService.speak(mascotMessage)
    }

    public func selectFurniture(id: UUID?) {
        selectedFurnitureID = id
        if id != nil {
            feedbackService.playImpact(.light)
        }
    }

    public func rotateSelectedFurniture(delta: Double) {
        guard let item = selectedFurniture else { return }
        let oldPos = (x: item.positionX, z: item.positionZ)
        item.rotationYaw += delta
        feedbackService.playImpact(.medium)
        handleFurnitureMoved(
            FurnitureMoveEvent(
                furnitureName: item.name,
                category: item.category,
                oldPosition: oldPos,
                newPosition: oldPos,
                rotationYaw: item.rotationYaw
            )
        )
    }

    public func toggleSelectedFurnitureArchive() {
        guard let item = selectedFurniture else { return }
        item.isArchived.toggle()
        let archived = item.isArchived
        selectedFurnitureID = nil
        mascotEmotion = .curious
        mascotMessage = archived ? "Archived \(item.name) into inventory!" : "Restored \(item.name) to room!"
        feedbackService.playImpact(.heavy)
        feedbackService.speak(mascotMessage)
    }

    public func handleFurnitureMoved(_ event: FurnitureMoveEvent) {
        if let reaction = mascotService.microReact(
            event: event,
            roomDimensions: (width: room.dimensionsWidth, length: room.dimensionsLength),
            allFurnitures: room.workingLayout?.furnitures ?? []
        ) {
            mascotMessage = reaction.message
            mascotEmotion = reaction.emotion
            if reaction.emotion == .warning {
                feedbackService.playNotification(.warning)
            } else {
                feedbackService.playImpact(.light)
            }
            feedbackService.speak(reaction.message)
        }
    }

    public func resetWorkingLayout() {
        room.resetWorkingLayoutToBaseline()
        selectedFurnitureID = nil
        mascotEmotion = .curious
        mascotMessage = "Restored your room to the original baseline scan!"
        feedbackService.playNotification(.warning)
        feedbackService.speak(mascotMessage)
    }

    public func triggerStageEvaluation() {
        guard !isEvaluating else { return }
        isEvaluating = true
        Task {
            let result = await mascotService.evaluateStage(stage: currentStage, room: room)
            self.evaluationResult = result
            self.isEvaluating = false
            self.showingEvaluationSheet = true
            if result.canAdvance {
                self.feedbackService.playNotification(.success)
                self.feedbackService.playAudioCue(.stageComplete)
            } else {
                self.feedbackService.playNotification(.warning)
            }
            self.feedbackService.speak(result.dialogue)
        }
    }

    public func advanceToNextStage(result: StageEvaluationResult) {
        room.completeStage(currentStage, score: result.score, feedback: result.dialogue)
        if let next = currentStage.nextStage {
            currentStage = next
            updateMascotGreeting()
        }
        feedbackService.playNotification(.success)
    }

    public func switchToStage(_ stage: StageType) {
        guard room.isUnlocked(stage) else { return }
        currentStage = stage
        updateMascotGreeting()
        feedbackService.playImpact(.soft)
    }

    // MARK: - Stage 3 Illumination Helpers
    public var currentIlluminationReport: IlluminationReport {
        let fixtures = room.workingLayout?.lightFixtures ?? []
        let furnitures = room.workingLayout?.furnitures ?? []
        return illuminationEngine.evaluateIllumination(
            fixtures: fixtures,
            roomWidth: room.dimensionsWidth,
            roomLength: room.dimensionsLength,
            furnitures: furnitures,
            hourOfDay: daylightHour
        )
    }

    public func addLightFixture(
        name: String,
        layer: LightLayer,
        positionX: Double = 0.0,
        positionZ: Double = 0.0,
        elevationY: Double = 2.4,
        lumens: Double = 800.0,
        colorTemperatureKelvin: Int = 3000
    ) {
        guard let layout = room.workingLayout else { return }
        var fixtures = layout.lightFixtures
        let newFixture = LightFixture(
            name: name,
            layer: layer,
            positionX: positionX,
            positionZ: positionZ,
            elevationY: elevationY,
            lumens: lumens,
            colorTemperatureKelvin: colorTemperatureKelvin,
            isOn: true
        )
        fixtures.append(newFixture)
        layout.lightFixtures = fixtures
        feedbackService.playImpact(.medium)
        mascotEmotion = .happy
        mascotMessage = "Added \(name) (\(layer.title)) to illuminate the room!"
    }

    public func toggleLightFixture(id: UUID) {
        guard let layout = room.workingLayout else { return }
        var fixtures = layout.lightFixtures
        if let index = fixtures.firstIndex(where: { $0.id == id }) {
            fixtures[index].isOn.toggle()
            layout.lightFixtures = fixtures
            feedbackService.playImpact(.light)
        }
    }

    // MARK: - Stage 4 Harmony Helpers
    public var currentHarmonyMetrics: HarmonyComparisonMetrics {
        harmonyEngine.synthesizeHarmony(room: room, daylightHour: daylightHour)
    }
}
