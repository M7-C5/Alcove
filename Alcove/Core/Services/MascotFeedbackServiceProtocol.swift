import Foundation

/// Tactile feedback intensities for user interactions and mascot gestures.
public enum MascotHapticStyle: Sendable {
    case light
    case medium
    case heavy
    case soft
    case rigid
}

/// Notification tactile feedback types.
public enum MascotNotificationType: Sendable {
    case success
    case warning
    case error
}

/// Audio cues for Mascot interactions and stage completion.
public enum MascotAudioCue: Sendable {
    case snap
    case stageComplete
    case warningAlert
    case mascotGreeting
}

/// Contract for multi-sensory mascot feedback (Haptics, TTS Speech, Audio Cues).
@MainActor
public protocol MascotFeedbackServiceProtocol: AnyObject, Sendable {
    var isVoiceNarrationEnabled: Bool { get set }
    var isHapticsEnabled: Bool { get set }

    func playImpact(_ style: MascotHapticStyle)
    func playNotification(_ type: MascotNotificationType)
    func playAudioCue(_ cue: MascotAudioCue)
    func speak(_ text: String)
    func stopSpeaking()
}
