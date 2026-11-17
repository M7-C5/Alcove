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

            // Next Stage button for stage evaluation
            Button {
                onTriggerEvaluation()
            } label: {
                HStack(spacing: 6) {
                    Text("Next Stage")
                        .font(.custom("Cleanow", size: 17, relativeTo: .subheadline))
                    Image(systemName: "chevron.right")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                }
                .foregroundStyle(Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0))
                .padding(.horizontal, 20)
                .frame(minWidth: 44, minHeight: 44)
                .background {
                    ZStack {
                        Capsule()
                            .fill(Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0))

                        ZStack {
                            VStack(spacing: 0) {
                                Color(red: 0xFB / 255.0, green: 0xEA / 255.0, blue: 0xB6 / 255.0)
                                Color(red: 0xFC / 255.0, green: 0xA6 / 255.0, blue: 0x0F / 255.0)
                            }

                            Capsule()
                                .fill(Color(red: 0xFB / 255.0, green: 0xD4 / 255.0, blue: 0x60 / 255.0))
                                .padding(.top, 2)
                                .padding(.bottom, 3.5)
                        }
                        .clipShape(Capsule())
                        .padding(2.5)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next Stage")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
        .safeAreaPadding(.bottom)
    }
}
