import SwiftUI

/// Only the panel and its edge tab receive touches; the remaining canvas stays interactive.
struct LightingCollapsiblePanel<Content: View>: View {
    let title: String
    @Binding var expanded: Bool
    let edge: HorizontalEdge
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            if edge == .trailing { tab }
            if expanded {
                content()
                    .transition(.move(edge: edge == .leading ? .leading : .trailing).combined(with: .opacity))
            }
            if edge == .leading { tab }
        }
        .animation(.easeInOut(duration: 0.25), value: expanded)
    }

    private var tab: some View {
        Button {
            expanded.toggle()
        } label: {
            Image(systemName: chevron)
                .font(.subheadline.bold())
                .foregroundStyle(LightingTheme.ink)
                .frame(width: 44, height: 60)
                .background(LightingTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LightingTheme.ink, lineWidth: 1.5))
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
