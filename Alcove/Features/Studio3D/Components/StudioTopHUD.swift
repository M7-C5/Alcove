import SwiftUI

public struct StudioTopHUD: View {
    let roomName: String
    let currentStage: StageType
    let room: Room
    var isVoiceEnabled: Bool = false
    var onToggleVoice: (() -> Void)? = nil
    let onDismiss: () -> Void
    let onSelectStage: (StageType) -> Void
    let onResetLayout: () -> Void

    public init(
        roomName: String,
        currentStage: StageType,
        room: Room,
        isVoiceEnabled: Bool = false,
        onToggleVoice: (() -> Void)? = nil,
        onDismiss: @escaping () -> Void,
        onSelectStage: @escaping (StageType) -> Void,
        onResetLayout: @escaping () -> Void
    ) {
        self.roomName = roomName
        self.currentStage = currentStage
        self.room = room
        self.isVoiceEnabled = isVoiceEnabled
        self.onToggleVoice = onToggleVoice
        self.onDismiss = onDismiss
        self.onSelectStage = onSelectStage
        self.onResetLayout = onResetLayout
    }

    public var body: some View {
        HStack(spacing: 16) {
            Button {
                onDismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("Stages")
                }
                .font(.headline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(Capsule().fill(.ultraThinMaterial))
                .contentShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(roomName)
                    .font(.headline)
                Text(currentStage.title)
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
            }

            Spacer()

            // Stage Switcher Pills
            HStack(spacing: 6) {
                ForEach(StageType.allCases) { stage in
                    let isUnlocked = room.isUnlocked(stage)
                    let isCurrent = stage == currentStage

                    Button {
                        if isUnlocked {
                            onSelectStage(stage)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isUnlocked ? stage.icon : "lock.fill")
                                .font(.caption2)
                            Text("S\(stage.stageNumber)")
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minHeight: 44)
                        .background(
                            Capsule().fill(isCurrent ? Color.indigo : (isUnlocked ? Color.secondary.opacity(0.15) : Color.gray.opacity(0.1)))
                        )
                        .foregroundStyle(isCurrent ? .white : (isUnlocked ? .primary : .secondary))
                        .contentShape(Capsule())
                    }
                    .disabled(!isUnlocked)
                }
            }
            .padding(6)
            .background(Capsule().fill(.ultraThinMaterial))

            // Voice narration toggle button
            if let onToggleVoice {
                Button {
                    onToggleVoice()
                } label: {
                    Image(systemName: isVoiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.body.bold())
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.ultraThinMaterial))
                        .foregroundStyle(isVoiceEnabled ? .indigo : .secondary)
                        .contentShape(Circle())
                }
            }

            // Reset Layout button
            Button {
                onResetLayout()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.body.bold())
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.ultraThinMaterial))
                    .contentShape(Circle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
}
