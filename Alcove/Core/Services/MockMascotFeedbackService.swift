import Foundation

/// Mock implementation of MascotFeedbackServiceProtocol for deterministic unit testing.
@MainActor
public final class MockMascotFeedbackService: MascotFeedbackServiceProtocol, @unchecked Sendable {
    public var isVoiceNarrationEnabled: Bool = false
    public var isHapticsEnabled: Bool = true

    public private(set) var playedImpacts: [MascotHapticStyle] = []
    public private(set) var playedNotifications: [MascotNotificationType] = []
    public private(set) var playedAudioCues: [MascotAudioCue] = []
    public private(set) var spokenTexts: [String] = []
    public private(set) var didStopSpeaking: Bool = false

    public init() {}

    public func playImpact(_ style: MascotHapticStyle) {
        if isHapticsEnabled {
            playedImpacts.append(style)
        }
    }

    public func playNotification(_ type: MascotNotificationType) {
        if isHapticsEnabled {
            playedNotifications.append(type)
        }
    }

    public func playAudioCue(_ cue: MascotAudioCue) {
        playedAudioCues.append(cue)
    }

    public func speak(_ text: String) {
        if isVoiceNarrationEnabled {
            spokenTexts.append(text)
        }
    }

    public func stopSpeaking() {
        didStopSpeaking = true
    }

    public func reset() {
        playedImpacts.removeAll()
        playedNotifications.removeAll()
        playedAudioCues.removeAll()
        spokenTexts.removeAll()
        didStopSpeaking = false
    }
}
