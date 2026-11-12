import SwiftUI
import UIKit

/// A tactile sticker-style capsule button with warm brand colors, stroke outline, and press feedback.
public struct TactilePillButton: View {
    public let title: String
    public let action: () -> Void

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: {
            playTapHaptic()
            action()
        }) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.custom("Cleanow", size: 28))
                    .foregroundStyle(Color(red: 88 / 255, green: 60 / 255, blue: 52 / 255))
            }
            .padding(.horizontal, 44)
            .padding(.vertical, 16)
            .frame(minWidth: 170, minHeight: 64)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 254 / 255, green: 242 / 255, blue: 194 / 255), location: 0.0),
                                .init(color: Color(red: 248 / 255, green: 235 / 255, blue: 188 / 255), location: 0.12),
                                .init(color: Color(red: 245 / 255, green: 214 / 255, blue: 115 / 255), location: 0.24),
                                .init(color: Color(red: 245 / 255, green: 214 / 255, blue: 115 / 255), location: 0.74),
                                .init(color: Color(red: 240 / 255, green: 170 / 255, blue: 62 / 255), location: 0.88),
                                .init(color: Color(red: 240 / 255, green: 167 / 255, blue: 57 / 255), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(Color(red: 88 / 255, green: 60 / 255, blue: 52 / 255), lineWidth: 4.0)
            )
            .shadow(
                color: Color(red: 80 / 255, green: 31 / 255, blue: 0 / 255).opacity(0.24),
                radius: 3,
                x: 0,
                y: 3.5
            )
            .contentShape(Capsule())
        }
        .buttonStyle(TactilePillButtonStyle())
        .accessibilityLabel(title)
    }

    private func playTapHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
}

private struct TactilePillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
