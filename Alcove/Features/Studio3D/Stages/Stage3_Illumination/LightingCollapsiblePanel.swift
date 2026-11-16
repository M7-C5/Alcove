import SwiftUI

/// The panel and the tab share one transform, preserving their join throughout the slide.
struct LightingCollapsiblePanel<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    @Binding var expanded: Bool
    let edge: HorizontalEdge
    let width: Double
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: edge == .leading ? .leading : .trailing) {
            tab
                .offset(x: edge == .leading ? width - 16 : -(width - 16))
            content()
                .frame(width: width)
                .allowsHitTesting(expanded)
                .accessibilityHidden(!expanded)
        }
        .frame(width: width + 44, alignment: edge == .leading ? .leading : .trailing)
        .transaction { $0.animation = nil }
        .geometryGroup()
        .compositingGroup()
        .modifier(LightingPanelReveal(progress: expanded ? 1 : 0,
                                      travel: width + 16, edge: edge))
        .animation(reduceMotion ? nil : .spring(response: 0.72, dampingFraction: 0.86,
                                               blendDuration: 0.2), value: expanded)
    }

    private var tab: some View {
        Button {
            expanded.toggle()
        } label: {
            Image(systemName: chevron)
                .font(.subheadline.bold())
                .foregroundStyle(LightingTheme.ink)
                .offset(x: edge == .leading ? 8 : -8)
                .frame(width: 60, height: 72)
                .background(LightingTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LightingTheme.ink, lineWidth: 2.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(expanded ? "Collapse" : "Expand") \(title)")
        .accessibilityValue(expanded ? "Expanded" : "Collapsed")
    }

    private var chevron: String {
        let pointsLeft = edge == .leading ? expanded : !expanded
        return pointsLeft ? "chevron.left" : "chevron.right"
    }
}

/// One interpolated presentation value drives the entire panel, including its tab.
private struct LightingPanelReveal: AnimatableModifier {
    var progress: Double
    let travel: Double
    let edge: HorizontalEdge

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let visibility = min(1, max(0, progress))
        content
            .scaleEffect(0.985 + 0.015 * visibility,
                         anchor: edge == .leading ? .trailing : .leading)
            .offset(x: (1 - progress) * travel * (edge == .leading ? -1 : 1))
            .shadow(color: LightingTheme.ink.opacity(0.025 + 0.065 * visibility),
                    radius: 3 + 9 * visibility,
                    x: edge == .leading ? 3 : -3, y: 3)
    }
}
