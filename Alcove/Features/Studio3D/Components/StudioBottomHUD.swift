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
        HStack(alignment: .center, spacing: 12) {
            // Mascot Control Button with Menu (44x44 hit target)
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
                ZStack {
                    Circle()
                        .fill(Color.indigo.gradient)
                    Text(mascotEmotion.emoji)
                        .font(.system(size: 24))
                }
                .frame(width: 44, height: 44)
                .shadow(color: .indigo.opacity(0.3), radius: 6, x: 0, y: 2)
            }

            // Compact Visual Novel Dialogue Box
            VStack(alignment: .leading, spacing: 2) {
                Text("ALCOVE COMPANION")
                    .font(.caption2.bold())
                    .foregroundStyle(.indigo)
                    .tracking(1.0)

                if let attributed = try? AttributedString(markdown: mascotMessage, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(attributed)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .animation(.easeInOut, value: mascotMessage)
                } else {
                    Text(mascotMessage)
                        .font(.footnote)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .animation(.easeInOut, value: mascotMessage)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Chat Action Button (44x44 target)
            Button {
                onOpenChat()
            } label: {
                Image(systemName: "message.fill")
                    .font(.subheadline)
                    .foregroundStyle(.indigo)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.indigo.opacity(0.12)))
            }
            .contentShape(Rectangle())

            // Proceed Action Button (44x44 target)
            Button {
                onTriggerEvaluation()
            } label: {
                HStack(spacing: 4) {
                    Text("Proceed")
                        .font(.caption.bold())
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.subheadline)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 36)
                .background(Capsule().fill(Color.indigo.gradient))
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 4)
        )
        .frame(maxWidth: 620)
        .padding(.leading, 20)
        .padding(.bottom, 12)
    }
}
