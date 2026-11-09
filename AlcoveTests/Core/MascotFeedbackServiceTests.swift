import Foundation
import Testing
@testable import Alcove

@Suite("Mascot Feedback Service Tests") @MainActor
struct MascotFeedbackServiceTests {

    @Test func mockServiceRecordsFeedbackAndCues() {
        let service = MockMascotFeedbackService()
        service.isVoiceNarrationEnabled = true
        service.isHapticsEnabled = true

        service.playImpact(.light)
        service.playImpact(.heavy)
        #expect(service.playedImpacts == [.light, .heavy])

        service.playNotification(.success)
        service.playNotification(.warning)
        #expect(service.playedNotifications == [.success, .warning])

        service.playAudioCue(.stageComplete)
        #expect(service.playedAudioCues == [.stageComplete])

        service.speak("Welcome to your room!")
        #expect(service.spokenTexts.contains("Welcome to your room!"))

        service.stopSpeaking()
        #expect(service.didStopSpeaking == true)
    }

    @Test func hapticsDisabledSuppressesImpacts() {
        let service = MockMascotFeedbackService()
        service.isHapticsEnabled = false

        service.playImpact(.rigid)
        service.playNotification(.error)

        #expect(service.playedImpacts.isEmpty)
        #expect(service.playedNotifications.isEmpty)
    }

    @Test func voiceDisabledSuppressesSpeech() {
        let service = MockMascotFeedbackService()
        service.isVoiceNarrationEnabled = false

        service.speak("This should not be spoken")
        #expect(service.spokenTexts.isEmpty)
    }
}
