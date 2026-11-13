import Testing
import Foundation
@testable import Alcove

@Suite("Spatial Fact Verifier Tests")
struct SpatialFactVerifierTests {

    @Test func verifierCatchesPhantomFurniture() {
        let room = SampleData.createStarterRoom()
        let furnitures = room.workingLayout?.furnitures.filter { !$0.isArchived } ?? []
        let verifier = SpatialFactVerifier()

        // Room only has Queen Bed, Work Desk, Ergonomic Chair, Bookshelf, Floor Lamp
        #expect(verifier.containsPhantomFurniture(text: "You should add throw pillows to your sofa", activeFurnitures: furnitures))
        #expect(verifier.containsPhantomFurniture(text: "Your dining table looks great", activeFurnitures: furnitures))
        #expect(!verifier.containsPhantomFurniture(text: "Your Queen Bed is positioned nicely", activeFurnitures: furnitures))
    }

    @Test func verifierCorrectsWallBoundPiecesMistakenlyClaimedAsCentered() {
        let room = SampleData.createStarterRoom()
        let verifier = SpatialFactVerifier()
        let baseline = StageEvaluationResult(
            canAdvance: true,
            score: 100,
            title: "Baseline",
            dialogue: "Verified baseline layout.",
            bottlenecks: [],
            recommendations: ["Verified tip 1"],
            praise: ["Verified praise"]
        )

        let hallucinatedDialogue = "Your Queen Bed is floating comfortably in the center of the room."
        let hallucinatedRecs = ["Your Queen Bed enjoys plenty of open breathing room in the center"]

        let sanitized = verifier.verifyAndSanitize(
            dialogue: hallucinatedDialogue,
            recommendations: hallucinatedRecs,
            room: room,
            stage: .audit,
            baseline: baseline
        )

        // Must NOT claim bed is floating or in the center
        #expect(!sanitized.dialogue.contains("floating comfortably"))
        #expect(!sanitized.dialogue.contains("in the center"))
        for rec in sanitized.recommendations {
            #expect(!rec.contains("in the center"))
            #expect(!rec.contains("floating"))
        }
    }

    @Test func verifierDropsPrematureLightingTipsInStage1Audit() {
        let room = SampleData.createStarterRoom()
        let verifier = SpatialFactVerifier()
        let baseline = StageEvaluationResult(
            canAdvance: true,
            score: 100,
            title: "Baseline",
            dialogue: "Verified baseline layout.",
            bottlenecks: [],
            recommendations: ["Verified tip 1"],
            praise: ["Verified praise"]
        )

        let prematureTips = [
            "Add ceiling spotlights to brighten dark corners",
            "Notice how the natural daylight enters across the floor"
        ]

        let sanitized = verifier.verifyAndSanitize(
            dialogue: "Observing baseline.",
            recommendations: prematureTips,
            room: room,
            stage: .audit,
            baseline: baseline
        )

        // Premature lighting advice should be filtered out during Stage 1
        #expect(!sanitized.recommendations.contains(where: { $0.contains("Add ceiling spotlights") }))
        #expect(sanitized.recommendations.contains(where: { $0.contains("natural daylight") }))
    }

    @Test func verifierChatAnswerCatchesPhantomAndFalseCenter() {
        let room = SampleData.createStarterRoom()
        let verifier = SpatialFactVerifier()
        let fallback = "Here is what I see in your room."

        // Phantom furniture
        let phantomAns = verifier.verifyChatAnswer(
            answer: "You could move your sofa next to the window.",
            room: room,
            stage: .audit,
            fallbackAnswer: fallback
        )
        #expect(phantomAns == fallback)

        // Wall-bound bed claimed as floating in center
        let falseCenterAns = verifier.verifyChatAnswer(
            answer: "Your Queen Bed is floating in the center of the space.",
            room: room,
            stage: .audit,
            fallbackAnswer: fallback
        )
        #expect(falseCenterAns == fallback)

        // Stage 1 artificial lighting
        let prematureLightAns = verifier.verifyChatAnswer(
            answer: "You should add lamp fixtures across the ceiling.",
            room: room,
            stage: .audit,
            fallbackAnswer: fallback
        )
        #expect(prematureLightAns == fallback)

        // Clean answer is preserved
        let validAns = verifier.verifyChatAnswer(
            answer: "Your Work Desk has great natural light by the window.",
            room: room,
            stage: .audit,
            fallbackAnswer: fallback
        )
        #expect(validAns == "Your Work Desk has great natural light by the window.")

        // Advice mentioning keeping the center open should NOT trip false-center circuit breaker
        let openCenterAdvice = "Slide your Queen Bed toward the open corner so the center of the room stays clear."
        let preservedCenterAdvice = verifier.verifyChatAnswer(
            answer: openCenterAdvice,
            room: room,
            stage: .rearrangement,
            fallbackAnswer: fallback
        )
        #expect(preservedCenterAdvice == openCenterAdvice)
    }
}

