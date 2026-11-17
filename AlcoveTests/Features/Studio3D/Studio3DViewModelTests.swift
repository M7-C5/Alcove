import Foundation
import Testing
@testable import Alcove

@Suite("Studio3D Slice Tests") @MainActor
struct Studio3DViewModelTests {

    @Test func initializationAndMascotGreeting() {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .audit)

        #expect(vm.currentStage == .audit)
        #expect(vm.mascotEmotion == .neutral)
        #expect(vm.mascotMessage.contains("Welcome to Sample Studio Apartment"))
        #expect(vm.daylightHour == 12.0)
        #expect(vm.beforeAfterSplit == 0.5)
    }

    @Test func furnitureSelectionAndRotation() {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .rearrangement)

        let bed = room.workingLayout?.furnitures.first { $0.name == "Queen Bed" }
        #expect(bed != nil)

        vm.selectFurniture(id: bed?.id)
        #expect(vm.selectedFurniture?.id == bed?.id)

        let initialYaw = bed?.rotationYaw ?? 0.0
        vm.rotateSelectedFurniture(delta: .pi / 4)
        #expect(bed?.rotationYaw == initialYaw + (.pi / 4))
    }

    @Test func furnitureArchivingToggle() {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .rearrangement)

        let desk = room.workingLayout?.furnitures.first { $0.name == "Work Desk" }
        #expect(desk?.isArchived == false)

        vm.selectFurniture(id: desk?.id)
        vm.toggleSelectedFurnitureArchive()

        #expect(desk?.isArchived == true)
        #expect(vm.selectedFurnitureID == nil)
        #expect(vm.mascotMessage.contains("Archived Work Desk"))
    }

    @Test func stageSwitchingGatedByUnlocks() {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .audit)

        // Stage 2 is locked initially
        vm.switchToStage(.rearrangement)
        #expect(vm.currentStage == .audit) // Did not change

        // Unlock Stage 2
        room.completeStage(.audit, score: 90, feedback: "Passed")
        #expect(room.isUnlocked(.rearrangement) == true)

        vm.switchToStage(.rearrangement)
        #expect(vm.currentStage == .rearrangement)
        #expect(vm.mascotMessage.contains("Stage 2 unlocked"))
    }

    @Test func stageEvaluationAndAdvancement() async {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .audit)

        let result = await vm.mascotService.evaluateStage(stage: .audit, room: room)
        vm.advanceToNextStage(result: result)

        #expect(room.isCompleted(.audit) == true)
        #expect(vm.currentStage == .rearrangement)
    }

    @Test func evaluationCachingReusesResultUntilLayoutChanges() async {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .audit)

        #expect(vm.hasPendingLayoutChanges == true)
        #expect(vm.evaluationResult == nil)

        // 1. Initial evaluation
        let result1 = await vm.evaluateCurrentStage()

        #expect(result1 != nil)
        #expect(vm.evaluationResult != nil)
        #expect(vm.hasPendingLayoutChanges == false)
        let initialTitle = vm.evaluationResult?.title

        // 2. Trigger again without changes -> reuses existing evaluation without re-evaluating
        let result2 = await vm.evaluateCurrentStage()
        #expect(result2?.title == initialTitle)
        #expect(vm.hasPendingLayoutChanges == false)

        // 3. Move a furniture piece -> marks layout dirty
        let moveEvent = FurnitureMoveEvent(
            furnitureName: "Queen Bed",
            category: .bed,
            oldPosition: (x: -1.2, z: -1.5),
            newPosition: (x: -1.0, z: -1.5),
            rotationYaw: 0.0
        )
        vm.handleFurnitureMoved(moveEvent)
        #expect(vm.hasPendingLayoutChanges == true)
    }

    @Test func furnitureMoveTriggersMicroReactionAndBoldRearrangement() {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .rearrangement)

        // Move Queen Bed more than 0.8m (Rule 4: Bold rearrangement)
        let moveEvent = FurnitureMoveEvent(
            furnitureName: "Queen Bed",
            category: .bed,
            oldPosition: (x: -1.2, z: -1.5),
            newPosition: (x: 0.0, z: 0.0),
            rotationYaw: 0.0
        )

        vm.handleFurnitureMoved(moveEvent)
        #expect(vm.mascotEmotion == .thinking)
        #expect(vm.mascotMessage.contains("Bold rearrangement"))
    }

    @Test func repeatedEvaluationGuardPreventsParallelRuns() {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .audit)

        vm.isEvaluating = true
        vm.triggerStageEvaluation()

        // evaluationResult should remain nil because trigger was rejected by guard
        #expect(vm.evaluationResult == nil)
        #expect(vm.showingEvaluationSheet == false)
    }

    @Test func illuminationFixtureManagementAndReport() {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .illumination)

        #expect(vm.room.workingLayout?.lightFixtures.isEmpty == true)

        vm.addLightFixture(
            name: "Main Pendant",
            layer: .ambient,
            positionX: 0.0,
            positionZ: 0.0,
            lumens: 1500.0,
            colorTemperatureKelvin: 3000
        )

        #expect(vm.room.workingLayout?.lightFixtures.count == 1)
        let fixture = vm.room.workingLayout?.lightFixtures.first
        #expect(fixture?.isOn == true)
        #expect(vm.mascotMessage.contains("Main Pendant"))

        // Toggle fixture
        if let id = fixture?.id {
            vm.toggleLightFixture(id: id)
            #expect(vm.room.workingLayout?.lightFixtures.first?.isOn == false)
        }

        let report = vm.currentIlluminationReport
        #expect(report.daylightState.hour == 12.0)
    }

    @Test func harmonyMetricsComputation() {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .harmony)

        let metrics = vm.currentHarmonyMetrics
        #expect(metrics.overallHarmonyScore >= 50)
        #expect(!metrics.summaryVerdict.isEmpty)
    }

    @Test func cameraPresetAndFeedbackInteractions() {
        let feedback = MockMascotFeedbackService()
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(
            room: room,
            stage: .rearrangement,
            mascotService: MockMascotAIService(),
            feedbackService: feedback
        )

        // Select furniture triggers haptic
        let desk = room.workingLayout?.furnitures.first { $0.name == "Work Desk" }
        vm.selectFurniture(id: desk?.id)
        #expect(feedback.playedImpacts.contains(.light))

        // Rotate triggers medium impact
        vm.rotateSelectedFurniture(delta: .pi / 4)
        #expect(feedback.playedImpacts.contains(.medium))

        // Archive triggers heavy impact
        vm.toggleSelectedFurnitureArchive()
        #expect(feedback.playedImpacts.contains(.heavy))

        // Camera preset
        vm.cameraState.setPreset(.dollhouseIsometric)
        #expect(vm.cameraState.isIsometric3D == true)

        // Voice toggle
        #expect(!vm.isVoiceNarrationEnabled)
        vm.toggleVoiceNarration()
        #expect(vm.isVoiceNarrationEnabled)
        #expect(feedback.isVoiceNarrationEnabled)
        #expect(feedback.spokenTexts.contains("Voice narration enabled"))
        vm.toggleVoiceNarration()
        #expect(!vm.isVoiceNarrationEnabled)
    }

    @Test func harmonyRevealModeSelection() {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .harmony)

        #expect(vm.revealMode == .splitSlider)
        vm.revealMode = .overlayDiff
        #expect(vm.revealMode == .overlayDiff)
        vm.revealMode = .sideBySide
        #expect(vm.revealMode == .sideBySide)
    }

    @Test func furnitureArchivingAndRestorationInInventory() {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .rearrangement)

        #expect(!vm.isArchiveListPresented)
        vm.isArchiveListPresented = true
        #expect(vm.isArchiveListPresented)

        let initialActiveCount = vm.activeFurnitures.count
        #expect(vm.archivedFurnitures.isEmpty)

        guard let firstItem = vm.activeFurnitures.first else {
            Issue.record("Expected starter room to have active furniture")
            return
        }

        // Archive item
        vm.selectFurniture(id: firstItem.id)
        #expect(vm.selectedFurnitureID == firstItem.id)

        vm.archiveFurniture(firstItem)
        #expect(firstItem.isArchived == true)
        #expect(vm.selectedFurnitureID == nil) // Deselected upon archive
        #expect(vm.archivedFurnitures.count == 1)
        #expect(vm.activeFurnitures.count == initialActiveCount - 1)
        #expect(vm.mascotMessage.contains("Archived"))

        // Restore item
        vm.restoreFurniture(firstItem)
        #expect(firstItem.isArchived == false)
        #expect(vm.selectedFurnitureID == firstItem.id) // Selected upon restore
        #expect(vm.archivedFurnitures.isEmpty)
        #expect(vm.activeFurnitures.count == initialActiveCount)
        #expect(vm.mascotMessage.contains("Restored"))
    }

    @Test func snapToViewportClosureInvocation() {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .rearrangement)

        var snappedPreset: ViewportPreset? = nil
        vm.snapToViewport = { preset in
            snappedPreset = preset
        }

        #expect(vm.snapToViewport != nil)
        vm.snapToViewport?(.top)
        #expect(snappedPreset == .top)

        vm.snapToViewport?(.left)
        #expect(snappedPreset == .left)

        vm.snapToViewport?(.right)
        #expect(snappedPreset == .right)

        vm.snapToViewport?(.front)
        #expect(snappedPreset == .front)

        vm.snapToViewport?(.back)
        #expect(snappedPreset == .back)

        vm.snapToViewport?(.dollhouse)
        #expect(snappedPreset == .dollhouse)
    }

    @Test func lightFixtureSelectionMovementAndEditing() {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .rearrangement)

        // Add an ambient ceiling light
        vm.addLightFixture(name: "Pendant Light", layer: .ambient, positionX: 0.0, positionZ: 0.0, lumens: 800)
        let addedFixture = vm.room.workingLayout?.lightFixtures.first { $0.name == "Pendant Light" }
        #expect(addedFixture != nil)

        // Select light fixture
        vm.selectLightFixture(id: addedFixture?.id)
        #expect(vm.selectedLightFixtureID == addedFixture?.id)
        #expect(vm.selectedLightFixture?.name == "Pendant Light")

        // Move light fixture
        vm.moveSelectedLightFixture(deltaX: 0.5, deltaZ: -0.5)
        #expect(vm.selectedLightFixture?.positionX == 0.5)
        #expect(vm.selectedLightFixture?.positionZ == -0.5)

        // Edit light properties (lumens and kelvin)
        vm.updateLightProperties(id: addedFixture!.id, lumens: 1200, kelvin: 3500)
        #expect(vm.selectedLightFixture?.lumens == 1200)
        #expect(vm.selectedLightFixture?.colorTemperatureKelvin == 3500)

        // Toggle power
        vm.toggleLightFixture(id: addedFixture!.id)
        #expect(vm.selectedLightFixture?.isOn == false)

        // Remove fixture
        vm.removeLightFixture(id: addedFixture!.id)
        #expect(vm.selectedLightFixtureID == nil)
        #expect(vm.room.workingLayout?.lightFixtures.contains { $0.name == "Pendant Light" } == false)

        // AR Walkthrough placeholder
        #expect(!vm.showingARPlaceholder)
        vm.showingARPlaceholder = true
        #expect(vm.showingARPlaceholder)
    }

    @Test func spatialWarningsAndHighlightSeverityUpdateOnMove() {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .rearrangement)

        guard let bed = vm.activeFurnitures.first(where: { $0.name == "Queen Bed" }),
              let desk = vm.activeFurnitures.first(where: { $0.name == "Work Desk" }) else {
            Issue.record("Expected Queen Bed and Work Desk in starter room")
            return
        }

        // Move bed directly onto the Work Desk -> Red collision warning for both
        bed.positionX = desk.positionX
        bed.positionZ = desk.positionZ
        vm.selectFurniture(id: bed.id)
        vm.notifyLiveFurnitureDrag()

        #expect(vm.warningSeverityByFurnitureID[bed.id] == .collision)
        #expect(vm.warningSeverityByFurnitureID[desk.id] == .collision)
        #expect(vm.activeTopWarning?.severity == .collision)

        // Move bed to open Front-Right perimeter corner -> no collision
        bed.positionX = 1.45
        bed.positionZ = 1.70
        vm.notifyLiveFurnitureDrag()

        #expect(vm.warningSeverityByFurnitureID[bed.id] != .collision)
    }

    @Test func auditStagePreventsFurnitureRearrangement() async {
        let room = SampleData.createStarterRoom()
        let vm = Studio3DViewModel(room: room, stage: .audit)

        #expect(vm.canManipulateFurniture == false)

        guard let bed = vm.activeFurnitures.first(where: { $0.name == "Queen Bed" }) else {
            Issue.record("Expected Queen Bed in starter room")
            return
        }

        let initialYaw = bed.rotationYaw
        let initialArchived = bed.isArchived

        vm.selectFurniture(id: bed.id)
        vm.rotateSelectedFurniture(delta: .pi / 4)
        vm.archiveFurniture(bed)
        vm.toggleSelectedFurnitureArchive()

        #expect(bed.rotationYaw == initialYaw)
        #expect(bed.isArchived == initialArchived)

        // Advancing to Stage 2 unlocks rearrangement
        let evalResult = await vm.mascotService.evaluateStage(stage: .audit, room: room)
        vm.advanceToNextStage(result: evalResult)

        #expect(vm.currentStage == .rearrangement)
        #expect(vm.canManipulateFurniture == true)
    }
}
