import SwiftUI

/// A tactile sticker-style capsule button with warm brand colors, layered capsule shading, stroke outline, and press feedback.
public struct TactilePillButton: View {
    public let title: String
    public let accessibilityLabelText: String
    public let action: () -> Void

    @State private var tapTrigger: Int = 0

    public init(
        title: String,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.accessibilityLabelText = accessibilityLabel ?? title
        self.action = action
    }

    public var body: some View {
        Button {
            tapTrigger += 1
            action()
        } label: {
            Text(title)
                .font(.custom("Cleanow", size: 32, relativeTo: .title))
                .foregroundStyle(.alcoveText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 44)
                .padding(.vertical, 20)
                .frame(minWidth: 188, minHeight: 80)
                .background {
                    // Outer border capsule wraps the inner clipped fill so
                    // the stroke never covers the top highlight or bottom rim crescents.
                    ZStack {
                        Capsule()
                            .fill(.alcoveBorder)

                        ZStack {
                            VStack(spacing: 0) {
                                Color.alcovePrimaryHighlight
                                Color.alcovePrimaryShadow
                            }

                            Capsule()
                                .fill(.alcovePrimaryFill)
                                .padding(.top, 5.0)
                                .padding(.bottom, 6.0)
                        }
                        .clipShape(Capsule())
                        .padding(4.5)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(TactilePillButtonStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: tapTrigger)
        .accessibilityLabel(accessibilityLabelText)
    }
}

private struct TactilePillButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}
