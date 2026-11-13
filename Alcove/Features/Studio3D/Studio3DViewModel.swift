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
    var lightingSettings = LightingSimulationSettings()
    public var daylightHour: Double {
        get { lightingSettings.hourOfDay }
        set { lightingSettings.minuteOfDay = newValue.isFinite ? Int(min(1439, max(0, (newValue * 60).rounded()))) : 720 }
    }
    public var selectedLightFixtureID: UUID?
    public let illuminationEngine = IlluminationSimulationEngine()

    // Stage 4 Harmony Reveal state & contracts (Area 2)
    public var beforeAfterSplit: Double = 0.5 // Split slider
    public var revealMode: HarmonyRevealMode = .splitSlider
    public var showingARPlaceholder: Bool = false
    public var showingScorecardSheet: Bool = false
    public var isTouringCinematicWalkthrough: Bool = false
    public let harmonyEngine = HarmonySynthesisEngine()

    // Modal dialog presentation state
    public var showingChatDrawer: Bool = false
    public var chatHistory: [ChatMessage] = []
    public var showingEvaluationSheet: Bool = false
    public var evaluationResult: StageEvaluationResult?
    public var isEvaluating: Bool = false
    /// Tracks if the room layout has been modified since the last stage evaluation (prevents redundant API calls)
    public private(set) var hasPendingLayoutChanges: Bool = true
    private var evaluationTask: Task<Void, Never>?

    // Walkthrough Onboarding Sequence state (Figma Image 1 & 2)
    public var isWalkthroughActive: Bool = false
    public var walkthroughStepIndex: Int = 0
    public var walkthroughSteps: [WalkthroughStep] = []

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
            mascotService: LLMMascotAIService.shared,
            feedbackService: SystemMascotFeedbackService()
        )
    }

    public var isVoiceNarrationEnabled: Bool {
        get { feedbackService.isVoiceNarrationEnabled }
        set { feedbackService.isVoiceNarrationEnabled = newValue }
    }

    // Archive & Inventory Presentation
    public var isArchiveListPresented: Bool = false
    public var isFurnitureCatalogPresented: Bool = false
    public var swapTargetFurnitureID: UUID? = nil
    public var floorRaycaster: ((CGPoint) -> SIMD3<Float>?)? = nil
    public var snapToViewport: ((ViewportPreset) -> Void)? = nil

    // Live Spatial Warnings (Red collisions & Yellow improvements)
    public var dragRevision: Int = 0

    @discardableResult
    public func notifyLiveFurnitureDrag() -> [UUID: SpatialWarningSeverity] {
        dragRevision &+= 1
        markLayoutDirty()
        return warningSeverityByFurnitureID
    }

    public var spatialWarnings: [SpatialWarning] {
        _ = dragRevision
        guard currentStage != .harmony else { return [] }
        return FastPathRulebook().evaluateSpatialWarnings(
            furnitures: activeFurnitures,
            roomDimensions: (width: room.dimensionsWidth, length: room.dimensionsLength)
        )
    }

    public var warningSeverityByFurnitureID: [UUID: SpatialWarningSeverity] {
        FastPathRulebook.warningSeverityMap(from: spatialWarnings)
    }

    public var activeTopWarning: SpatialWarning? {
        if let selectedID = selectedFurnitureID {
            let matching = spatialWarnings.filter { $0.furnitureIDs.contains(selectedID) }
            if let highestForSelected = matching.first {
                return highestForSelected
            }
        }
        return spatialWarnings.first
    }

    public var archivedFurnitures: [Furniture] {
        room.workingLayout?.furnitures.filter { $0.isArchived } ?? []
    }

    public var activeFurnitures: [Furniture] {
        room.workingLayout?.furnitures.filter { !$0.isArchived } ?? []
    }

    public var canManipulateFurniture: Bool {
        currentStage.unlockedTools.contains(.dragFurniture) && currentStage != .harmony
    }

    public func restoreFurniture(_ item: Furniture) {
        guard canManipulateFurniture else { return }
        item.isArchived = false
        dragRevision &+= 1
        selectedFurnitureID = item.id
        mascotEmotion = .happy
        mascotMessage = "Restored \(item.name) to room!"
        feedbackService.playImpact(.medium)
        feedbackService.speak(mascotMessage)
    }

    public func archiveFurniture(_ item: Furniture) {
        guard canManipulateFurniture else { return }
        item.isArchived = true
        dragRevision &+= 1
        markLayoutDirty()
        if selectedFurnitureID == item.id {
            selectedFurnitureID = nil
        }
        mascotEmotion = .curious
        mascotMessage = "Archived \(item.name) into inventory!"
        feedbackService.playImpact(.heavy)
        feedbackService.speak(mascotMessage)
    }

    public func openAddFurnitureCatalog() {
        guard canManipulateFurniture else { return }
        swapTargetFurnitureID = nil
        isArchiveListPresented = false
        isFurnitureCatalogPresented = true
    }

    public func openSwapFurnitureCatalog(for item: Furniture) {
        guard canManipulateFurniture else { return }
        swapTargetFurnitureID = item.id
        isArchiveListPresented = false
        isFurnitureCatalogPresented = true
    }

    @discardableResult
    public func addFurniture(from catalogItem: FurnitureCatalogItem) -> Furniture? {
        guard canManipulateFurniture, let workingLayout = room.workingLayout else { return nil }

        let clamped = FurnitureTransformEngine.clampPosition(
            position: SIMD3<Float>(0, 0, 0),
            furnitureWidth: Float(catalogItem.width),
            furnitureLength: Float(catalogItem.length),
            rotationYaw: 0,
            roomWidth: Float(room.dimensionsWidth),
            roomLength: Float(room.dimensionsLength)
        )

        let newItem = catalogItem.makeFurniture(
            positionX: Double(clamped.x),
            positionZ: Double(clamped.z),
            rotationYaw: 0.0,
            isUserAdded: true
        )
        newItem.layout = workingLayout
        workingLayout.furnitures.append(newItem)

        dragRevision &+= 1
        markLayoutDirty()
        selectedFurnitureID = newItem.id
        isFurnitureCatalogPresented = false
        swapTargetFurnitureID = nil

        mascotEmotion = .happy
        mascotMessage = "Added \(newItem.name) to your room!"
        feedbackService.playImpact(.medium)
        feedbackService.speak(mascotMessage)

        return newItem
    }

    public func removeFurniture(_ item: Furniture) {
        guard canManipulateFurniture, item.isUserAdded, let workingLayout = room.workingLayout else { return }
        workingLayout.furnitures.removeAll { $0.id == item.id }
        item.layout = nil

        if selectedFurnitureID == item.id {
            selectedFurnitureID = nil
        }
        if swapTargetFurnitureID == item.id {
            swapTargetFurnitureID = nil
        }

        dragRevision &+= 1
        markLayoutDirty()

        mascotEmotion = .curious
        mascotMessage = "Removed \(item.name) from your room."
        feedbackService.playImpact(.heavy)
        feedbackService.speak(mascotMessage)
    }

    public func swapFurniture(_ item: Furniture, with catalogItem: FurnitureCatalogItem) {
        guard canManipulateFurniture else { return }
        let oldPos = (x: item.positionX, z: item.positionZ)
        let previousName = item.name

        item.name = catalogItem.name
        item.category = catalogItem.category
        item.width = catalogItem.width
        item.length = catalogItem.length
        item.height = catalogItem.height
        item.assetIdentifier = catalogItem.assetIdentifier

        let clamped = FurnitureTransformEngine.clampPosition(
            position: SIMD3<Float>(Float(item.positionX), Float(item.positionY), Float(item.positionZ)),
            furnitureWidth: Float(item.width),
            furnitureLength: Float(item.length),
            rotationYaw: Float(item.rotationYaw),
            roomWidth: Float(room.dimensionsWidth),
            roomLength: Float(room.dimensionsLength)
        )
        item.positionX = Double(clamped.x)
        item.positionZ = Double(clamped.z)

        isFurnitureCatalogPresented = false
        swapTargetFurnitureID = nil
        selectedFurnitureID = item.id
        feedbackService.playImpact(.medium)

        handleFurnitureMoved(
            FurnitureMoveEvent(
                furnitureName: item.name,
                category: item.category,
                oldPosition: oldPos,
                newPosition: (x: item.positionX, z: item.positionZ),
                rotationYaw: item.rotationYaw
            )
        )

        if mascotMessage.isEmpty || mascotEmotion == .neutral {
            mascotEmotion = .happy
            mascotMessage = "Swapped \(previousName) for \(item.name)!"
            feedbackService.speak(mascotMessage)
        }
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
        guard canManipulateFurniture, let item = selectedFurniture else { return }
        let oldPos = (x: item.positionX, z: item.positionZ)
        item.rotationYaw = FurnitureTransformEngine.normalizeYaw(item.rotationYaw + delta)

        // Ensure rotated bounds stay clamped inside room boundaries
        let clamped = FurnitureTransformEngine.clampPosition(
            position: SIMD3<Float>(Float(item.positionX), Float(item.positionY), Float(item.positionZ)),
            furnitureWidth: Float(item.width),
            furnitureLength: Float(item.length),
            rotationYaw: Float(item.rotationYaw),
            roomWidth: Float(room.dimensionsWidth),
            roomLength: Float(room.dimensionsLength)
        )
        item.positionX = Double(clamped.x)
        item.positionZ = Double(clamped.z)

        feedbackService.playImpact(.medium)
        handleFurnitureMoved(
            FurnitureMoveEvent(
                furnitureName: item.name,
                category: item.category,
                oldPosition: oldPos,
                newPosition: (x: item.positionX, z: item.positionZ),
                rotationYaw: item.rotationYaw
            )
        )
    }

    public func resetSelectedFurniture() {
        guard canManipulateFurniture, let selected = selectedFurniture else { return }
        let oldPos = (x: selected.positionX, z: selected.positionZ)
        if let baselineItem = room.baselineLayout?.furnitures.first(where: { $0.id == selected.id || $0.name == selected.name }) {
            selected.positionX = baselineItem.positionX
            selected.positionY = baselineItem.positionY
            selected.positionZ = baselineItem.positionZ
            selected.rotationYaw = baselineItem.rotationYaw
            feedbackService.playNotification(.warning)
            mascotEmotion = .curious
            mascotMessage = "Reset \(selected.name) back to original baseline position."
            feedbackService.speak(mascotMessage)
            handleFurnitureMoved(
                FurnitureMoveEvent(
                    furnitureName: selected.name,
                    category: selected.category,
                    oldPosition: oldPos,
                    newPosition: (x: selected.positionX, z: selected.positionZ),
                    rotationYaw: selected.rotationYaw
                )
            )
        }
    }

    public func toggleSelectedFurnitureArchive() {
        guard canManipulateFurniture, let item = selectedFurniture else { return }
        markLayoutDirty()
        item.isArchived.toggle()
        dragRevision &+= 1
        let archived = item.isArchived
        selectedFurnitureID = nil
        mascotEmotion = .curious
        mascotMessage = archived ? "Archived \(item.name) into inventory!" : "Restored \(item.name) to room!"
        feedbackService.playImpact(.heavy)
        feedbackService.speak(mascotMessage)
    }

    public func markLayoutDirty() {
        hasPendingLayoutChanges = true
    }

    public func handleFurnitureMoved(_ event: FurnitureMoveEvent) {
        dragRevision &+= 1
        markLayoutDirty()
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
        markLayoutDirty()
        room.resetWorkingLayoutToBaseline()
        dragRevision &+= 1
        selectedFurnitureID = nil
        mascotEmotion = .curious
        mascotMessage = "Restored your room to the original baseline scan!"
        feedbackService.playNotification(.warning)
        feedbackService.speak(mascotMessage)
    }

    @discardableResult
    public func evaluateCurrentStage(forceReprompt: Bool = false) async -> StageEvaluationResult? {
        guard !isEvaluating else { return evaluationResult }

        // If no changes were made to the room layout and we already have a cached evaluation,
        // instantly present the existing evaluation without burning API tokens or incurring network latency!
        if !forceReprompt && !hasPendingLayoutChanges, let cached = evaluationResult {
            showingEvaluationSheet = true
            feedbackService.playImpact(.light)
            return cached
        }

        let requestedStage = currentStage
        isEvaluating = true
        let result = await mascotService.evaluateStage(stage: requestedStage, room: room)
        guard !Task.isCancelled, currentStage == requestedStage else {
            self.isEvaluating = false
            return nil
        }
        self.evaluationResult = result
        self.hasPendingLayoutChanges = false
        self.isEvaluating = false
        self.showingEvaluationSheet = true
        if result.canAdvance {
            self.feedbackService.playNotification(.success)
            self.feedbackService.playAudioCue(.stageComplete)
        } else {
            self.feedbackService.playNotification(.warning)
        }
        self.feedbackService.speak(result.dialogue)
        return result
    }

    public func triggerStageEvaluation(forceReprompt: Bool = false) {
        guard !isEvaluating else { return }
        evaluationTask?.cancel()
        evaluationTask = Task {
            await evaluateCurrentStage(forceReprompt: forceReprompt)
            self.evaluationTask = nil
        }
    }

    public func advanceToNextStage(result: StageEvaluationResult) {
        evaluationTask?.cancel()
        evaluationTask = nil
        isEvaluating = false
        room.completeStage(currentStage, score: result.score, feedback: result.dialogue)
        if let next = currentStage.nextStage {
            currentStage = next
            updateMascotGreeting()
            evaluationResult = nil
            hasPendingLayoutChanges = true
        }
        feedbackService.playNotification(.success)
    }

    public func switchToStage(_ stage: StageType) {
        guard room.isUnlocked(stage) else { return }
        evaluationTask?.cancel()
        evaluationTask = nil
        isEvaluating = false
        currentStage = stage
        updateMascotGreeting()
        evaluationResult = nil
        hasPendingLayoutChanges = true
        feedbackService.playImpact(.soft)
    }

    // MARK: - Stage 3 Illumination Helpers
    public var selectedLightFixture: LightFixture? {
        guard let id = selectedLightFixtureID else { return nil }
        return room.workingLayout?.lightFixtures.first { $0.id == id }
    }

    public func selectLightFixture(id: UUID?) {
        selectedLightFixtureID = id
        if id != nil {
            selectedFurnitureID = nil
            feedbackService.playImpact(.light)
        }
    }

    public func moveSelectedLightFixture(deltaX: Double, deltaZ: Double) {
        guard let item = selectedLightFixture else { return }
        updateLightPosition(id: item.id, x: item.positionX + deltaX, z: item.positionZ + deltaZ)
        feedbackService.playImpact(.light)
    }

    public func updateLightPosition(id: UUID, x: Double, z: Double) {
        markLayoutDirty()
        guard let layout = room.workingLayout else { return }
        var fixtures = layout.lightFixtures
        guard let index = fixtures.firstIndex(where: { $0.id == id }) else { return }
        let halfW = room.dimensionsWidth / 2.0
        let halfL = room.dimensionsLength / 2.0
        fixtures[index].positionX = max(-halfW, min(halfW, x))
        fixtures[index].positionZ = max(-halfL, min(halfL, z))
        layout.lightFixtures = fixtures
    }

    public func updateLightProperties(id: UUID, lumens: Double? = nil, kelvin: Int? = nil, name: String? = nil) {
        markLayoutDirty()
        guard let layout = room.workingLayout else { return }
        var fixtures = layout.lightFixtures
        guard let index = fixtures.firstIndex(where: { $0.id == id }) else { return }
        if let lumens { fixtures[index].lumens = lumens }
        if let kelvin { fixtures[index].colorTemperatureKelvin = kelvin }
        if let name { fixtures[index].name = name }
        layout.lightFixtures = fixtures
    }

    public func removeLightFixture(id: UUID) {
        markLayoutDirty()
        guard let layout = room.workingLayout else { return }
        var fixtures = layout.lightFixtures
        fixtures.removeAll { $0.id == id }
        layout.lightFixtures = fixtures
        if selectedLightFixtureID == id {
            selectedLightFixtureID = nil
        }
        feedbackService.playImpact(.medium)
        mascotEmotion = .thinking
        mascotMessage = "Removed light fixture. Keep an eye on your illumination balance!"
    }

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
        markLayoutDirty()
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

        if fixtures.count >= 5 && fixtures.count <= 7 {
            mascotMessage = "Added \(name)! With \(fixtures.count) light points, you've reached the recommended 5–7 guideline for a balanced, dimensional room."
        } else if layer == .task {
            mascotMessage = "Added \(name) (Task Layer). Task lighting over work/reading areas prevents eye fatigue."
        } else if layer == .accent {
            mascotMessage = "Added \(name) (Accent Layer). Accent light creates depth and highlights focal textures."
        } else {
            mascotMessage = "Added \(name) (\(layer.title)) to illuminate the room!"
        }
    }

    public func toggleLightFixture(id: UUID) {
        markLayoutDirty()
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

    private var cinematicTourTask: Task<Void, Never>? = nil

    public func openScorecardSheet() {
        showingScorecardSheet = true
        feedbackService.playImpact(.light)
    }

    public func startCinematicWalkthroughTour() {
        cinematicTourTask?.cancel()
        isTouringCinematicWalkthrough = true
        feedbackService.playImpact(.medium)
        snapToViewport?(.dollhouse)

        cinematicTourTask = Task { @MainActor [weak self] in
            guard let self else { return }

            let tourStops: [(preset: ViewportPreset, message: String, emotion: MascotEmotion)] = [
                (.dollhouse, "Starting our 3D tour from the isometric overview: note the open circulation corridors.", .happy),
                (.front, "Front eye-level perspective: direct access to the focal point without physical obstruction.", .curious),
                (.left, "Side clearance perspective: walkways now comfortably exceed standard passage widths.", .thinking),
                (.top, "Plan perspective: notice the intentional balance between active floor space and open area.", .celebrating)
            ]

            for stop in tourStops {
                guard !Task.isCancelled, self.isTouringCinematicWalkthrough else { break }
                self.snapToViewport?(stop.preset)
                self.mascotMessage = stop.message
                self.mascotEmotion = stop.emotion
                self.feedbackService.playImpact(.light)
                self.feedbackService.speak(stop.message)

                try? await Task.sleep(nanoseconds: 3_200_000_000)
            }

            if !Task.isCancelled && self.isTouringCinematicWalkthrough {
                self.snapToViewport?(.dollhouse)
                self.mascotMessage = "Tour complete! Scrub the 3D Split or view the Room Harmony Scorecard anytime."
                self.mascotEmotion = .happy
                self.isTouringCinematicWalkthrough = false
            }
        }
    }

    public func stopCinematicWalkthroughTour() {
        cinematicTourTask?.cancel()
        cinematicTourTask = nil
        isTouringCinematicWalkthrough = false
        snapToViewport?(.dollhouse)
        feedbackService.playImpact(.light)
    }

    public func completeHarmonyCurriculum() {
        let metrics = currentHarmonyMetrics
        room.completeStage(.harmony, score: metrics.overallHarmonyScore, feedback: metrics.summaryVerdict)
        mascotEmotion = .celebrating
        mascotMessage = "Congratulations! You've mastered all 4 interior design stages for \(room.name)!"
        feedbackService.playNotification(.success)
        feedbackService.playAudioCue(.stageComplete)
        feedbackService.speak(mascotMessage)
    }

    // MARK: - Interactive Walkthrough Orchestration (Figma Image 1 & 2)
    public func startWalkthrough() {
        walkthroughSteps = buildWalkthroughSteps(for: currentStage)
        walkthroughStepIndex = 0
        isWalkthroughActive = !walkthroughSteps.isEmpty
        if let first = walkthroughSteps.first {
            mascotMessage = first.text
            mascotEmotion = first.emotion
            feedbackService.speak(first.text)
        }
    }

    public func advanceWalkthrough() {
        guard isWalkthroughActive else { return }
        if walkthroughStepIndex < walkthroughSteps.count - 1 {
            walkthroughStepIndex += 1
            let current = walkthroughSteps[walkthroughStepIndex]
            mascotMessage = current.text
            mascotEmotion = current.emotion
            feedbackService.playImpact(.light)
            feedbackService.speak(current.text)
        } else {
            completeWalkthrough()
        }
    }

    public func completeWalkthrough() {
        isWalkthroughActive = false
        feedbackService.playImpact(.medium)
        updateMascotGreeting()
    }

    private let dialogueCurator = StageDialogueCurator()

    public func buildWalkthroughSteps(for stage: StageType) -> [WalkthroughStep] {
        dialogueCurator.buildSteps(for: stage, room: room)
    }
}
