import SwiftUI

/// Bottom HUD bar with the bottom-left Otter chat trigger and temporary bottom-right Proceed button.
public struct StudioBottomHUD: View {
    let mascotEmotion: MascotEmotion
    let mascotMessage: String
    let showsNextStage: Bool
    let onTriggerEvaluation: () -> Void
    let onOpenChat: () -> Void

    public init(
        mascotEmotion: MascotEmotion,
        mascotMessage: String,
        showsNextStage: Bool = true,
        onTriggerEvaluation: @escaping () -> Void,
        onOpenChat: @escaping () -> Void
    ) {
        self.mascotEmotion = mascotEmotion
        self.mascotMessage = mascotMessage
        self.showsNextStage = showsNextStage
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

            if showsNextStage {
                StudioStageButton(title: "Next Stage", role: .next, action: onTriggerEvaluation)
                    .accessibilityLabel("Next Stage")
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .safeAreaPadding(.bottom)
    }
}
