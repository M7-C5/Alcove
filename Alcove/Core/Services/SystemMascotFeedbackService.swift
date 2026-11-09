import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Real system implementation delivering tactile haptics and speech synthesis on iOS/iPadOS.
@MainActor
public final class SystemMascotFeedbackService: NSObject, MascotFeedbackServiceProtocol, @unchecked Sendable {
    public var isVoiceNarrationEnabled: Bool = false
    public var isHapticsEnabled: Bool = true

    #if canImport(AVFoundation)
    private let speechSynthesizer = AVSpeechSynthesizer()
    #endif

    public override init() {
        super.init()
    }

    public func playImpact(_ style: MascotHapticStyle) {
        guard isHapticsEnabled else { return }
        #if canImport(UIKit)
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light: feedbackStyle = .light
        case .medium: feedbackStyle = .medium
        case .heavy: feedbackStyle = .heavy
        case .soft: feedbackStyle = .soft
        case .rigid: feedbackStyle = .rigid
        }
        let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    public func playNotification(_ type: MascotNotificationType) {
        guard isHapticsEnabled else { return }
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        switch type {
        case .success: generator.notificationOccurred(.success)
        case .warning: generator.notificationOccurred(.warning)
        case .error: generator.notificationOccurred(.error)
        }
        #endif
    }

    public func playAudioCue(_ cue: MascotAudioCue) {
        switch cue {
        case .snap:
            playImpact(.light)
        case .stageComplete:
            playNotification(.success)
        case .warningAlert:
            playNotification(.warning)
        case .mascotGreeting:
            playImpact(.soft)
        }
    }

    public func speak(_ text: String) {
        guard isVoiceNarrationEnabled, !text.isEmpty else { return }
        #if canImport(AVFoundation)
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.95
        utterance.pitchMultiplier = 1.15 // Friendly mascot persona tone
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speechSynthesizer.speak(utterance)
        #endif
    }

    public func stopSpeaking() {
        #if canImport(AVFoundation)
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        #endif
    }
}
