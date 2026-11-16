import SwiftUI

/// Bottom HUD bar with the bottom-left Otter chat trigger and temporary bottom-right Proceed button.
public struct StudioBottomHUD: View {
    let mascotEmotion: MascotEmotion
    let mascotMessage: String
    let onTriggerEvaluation: () -> Void
    let onOpenChat: () -> Void

    public init(
        mascotEmotion: MascotEmotion,
        mascotMessage: String,
        onTriggerEvaluation: @escaping () -> Void,
        onOpenChat: @escaping () -> Void
    ) {
        self.mascotEmotion = mascotEmotion
        self.mascotMessage = mascotMessage
        self.onTriggerEvaluation = onTriggerEvaluation
        self.onOpenChat = onOpenChat
    }

    public var body: some View {
        HStack(alignment: .bottom) {
            Button {
                onOpenChat()
            } label: {
                OtterAvatarBadgeView(
                    emotion: mascotEmotion,
                    size: 72,
                    showsQuestionBadge: true
                )
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ask Otter (Design Chat)")

            Spacer()

            // Temporary Proceed button for stage evaluation testing
            Button {
                onTriggerEvaluation()
            } label: {
                HStack(spacing: 6) {
                    Text("Proceed")
                    Image(systemName: "chevron.right")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                }
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Color.alcoveText)
                .padding(.horizontal, 22)
                .frame(minWidth: 44, minHeight: 48)
                .background(Color.alcovePrimaryFill, in: Capsule())
                .overlay(Capsule().stroke(Color.alcoveBorder, lineWidth: 2.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Proceed to evaluate stage")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .safeAreaPadding(.bottom)
    }
}
