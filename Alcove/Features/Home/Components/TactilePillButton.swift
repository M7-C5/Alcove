import SwiftUI

/// A tactile sticker-style capsule button with warm brand colors, layered capsule shading, stroke outline, and press feedback.
public struct TactilePillButton: View {
    public let title: String
    public let accessibilityLabelText: String
    public let action: () -> Void

    public enum Size { case regular, compact }
    public enum Appearance { case primary, cream }
    public let size: Size
    public let appearance: Appearance
    public let systemImage: String?
    public let fillsWidth: Bool

    @ScaledMetric(relativeTo: .title) private var compactHeight: CGFloat = 48
    @State private var tapTrigger: Int = 0

    public init(
        title: String,
        accessibilityLabel: String? = nil,
        size: Size = .regular,
        appearance: Appearance = .primary,
        systemImage: String? = nil,
        fillsWidth: Bool = false,
        action: @escaping () -> Void
    ) {
        self.size = size
        self.appearance = appearance
        self.systemImage = systemImage
        self.fillsWidth = fillsWidth
        self.title = title
        self.accessibilityLabelText = accessibilityLabel ?? title
        self.action = action
    }

    private var sizeScale: CGFloat { size == .regular ? 1 : compactHeight / 87 }

    public var body: some View {
        Button {
            tapTrigger += 1
            action()
        } label: {
            if size == .regular {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.custom("Cleanow", size: 38, relativeTo: .title))
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 32, weight: .heavy))
                    }
                }
                .foregroundStyle(.alcoveText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 44)
                    .padding(.vertical, 20)
                    .frame(minWidth: 188, minHeight: 100)
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
            } else {
                HStack(spacing: 12 * sizeScale) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 28 * sizeScale, weight: .bold))
                    }
                    Text(title)
                        .font(.custom("Cleanow", size: 36 * (48.0 / 87.0), relativeTo: .title))
                }
                    .foregroundStyle(Color.alcoveInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 36 * sizeScale)
                    .frame(height: 87 * sizeScale)
                    .frame(maxWidth: fillsWidth ? .infinity : nil)
                    .background {
                        GeometryReader { geometry in
                            let border: CGFloat = 5 * sizeScale
                            let band: CGFloat = 7 * sizeScale
                            ZStack {
                                Capsule()
                                    .fill(appearance == .primary ? Color.alcovePrimaryShadow : Color.alcoveSecondaryShadow)
                                    .padding(border)
                                Capsule()
                                    .fill(appearance == .primary ? Color.alcovePrimaryHighlight : Color.alcoveChipHighlight)
                                    .padding(.horizontal, border)
                                    .padding(.top, border)
                                    .padding(.bottom, border + band)
                                    .mask(alignment: .top) {
                                        Rectangle().frame(height: geometry.size.height * 0.52)
                                    }
                                Capsule()
                                    .fill(appearance == .primary ? Color.alcovePrimaryFill : Color.alcoveSurfaceElevated)
                                    .padding(.horizontal, border)
                                    .padding(.top, border + band)
                                    .padding(.bottom, border + band)
                                Capsule()
                                    .strokeBorder(Color.alcoveInk, lineWidth: border)
                            }
                        }
                    }
                    .contentShape(Capsule())
            }
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
