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

    private var sizeScale: CGFloat { size == .regular ? 1 : 48.0 / 87.0 }

    public var body: some View {
        Button {
            tapTrigger += 1
            action()
        } label: {
            HStack(spacing: 12 * sizeScale) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 28 * sizeScale, weight: .bold))
                }
                Text(title)
                    .font(.custom("Cleanow", size: 36 * sizeScale))
            }
                .foregroundStyle(Color("AlcoveInk"))
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
                                .fill(appearance == .primary ? Color("AlcovePrimaryShadow") : Color(red: 0.88, green: 0.73, blue: 0.56))
                                .padding(border)
                            Capsule()
                                .fill(appearance == .primary ? Color("AlcovePrimaryHighlight") : Color(red: 1, green: 0.99, blue: 0.96))
                                .padding(.horizontal, border)
                                .padding(.top, border)
                                .padding(.bottom, border + band)
                                .mask(alignment: .top) {
                                    Rectangle().frame(height: geometry.size.height * 0.52)
                                }
                            Capsule()
                                .fill(appearance == .primary ? Color("AlcovePrimaryFill") : Color(red: 1, green: 247.0 / 255, blue: 231.0 / 255))
                                .padding(.horizontal, border)
                                .padding(.top, border + band)
                                .padding(.bottom, border + band)
                            Capsule()
                                .strokeBorder(Color("AlcoveInk"), lineWidth: border)
                        }
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: tapTrigger)
        .accessibilityLabel(accessibilityLabelText)
    }
}
