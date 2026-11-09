import SwiftUI

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
        HStack(alignment: .bottom, spacing: 16) {
            // Mascot Control Button with Menu
            Menu {
                Button {
                    onTriggerEvaluation()
                } label: {
                    Label("Proceed & Evaluate Stage", systemImage: "flag.checkered")
                }

                Button {
                    onOpenChat()
                } label: {
                    Label("Ask Mascot (Design Chat)", systemImage: "bubble.left.and.bubble.right.fill")
                }
            } label: {
                VStack(spacing: 4) {
                    Text(mascotEmotion.emoji)
                        .font(.system(size: 38))
                    Text("Mascot")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                }
                .frame(width: 72, height: 72)
                .background(Circle().fill(Color.indigo.gradient))
                .shadow(color: .indigo.opacity(0.4), radius: 8, x: 0, y: 4)
            }

            // Visual Novel Dialogue Box
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("ALCOVE COMPANION")
                            .font(.caption2.bold())
                            .foregroundStyle(.indigo)
                            .tracking(1.2)

                        Spacer()

                        Button {
                            onOpenChat()
                        } label: {
                            Label("Chat", systemImage: "message.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.indigo)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                    }

                    Text(mascotMessage)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .animation(.easeInOut, value: mascotMessage)
                }

                Divider()

                // Proceed Button
                Button {
                    onTriggerEvaluation()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                        Text("Proceed")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(.indigo)
                    .frame(width: 58)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
            )
            .frame(maxWidth: 640)
        }
        .padding(.leading, 24)
        .padding(.bottom, 24)
    }
}
