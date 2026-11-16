import SwiftUI

enum LightingTheme {
    static let background = Color("LightingBackground")
    static let panel = Color("LightingPanel")
    static let border = Color("LightingBorder")
    static let ink = Color("LightingInk")
    static let accent = Color("LightingAccent")
    static let canvas = Color("LightingCanvas")
    static let row = Color("LightingRow")
}

extension View {
    func lightingPanel() -> some View {
        background(LightingTheme.panel, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(LightingTheme.ink, lineWidth: 2.5))
    }
}

struct LightingWorkspaceBackground: View {
    var body: some View {
        GeometryReader { proxy in
            Image(decorative: "MainBackground")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct LightingGradientSlider: View {
    @Environment(\.isEnabled) private var isEnabled
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let colors: [Color]
    let label: String
    let formattedValue: String

    private var fraction: Double {
        min(1, max(0, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))
    }

    var body: some View {
        GeometryReader { proxy in
            let available = max(1, proxy.size.width - 24)
            ZStack(alignment: .leading) {
                LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                    .frame(height: 8)
                    .clipShape(Capsule())
                    .padding(.horizontal, 12)
                Circle()
                    .fill(LightingTheme.row)
                    .overlay(Circle().stroke(LightingTheme.ink.opacity(0.25)))
                    .frame(width: 24, height: 24)
                    .shadow(color: LightingTheme.ink.opacity(0.15), radius: 3, y: 2)
                    .offset(x: fraction * available)
            }
            .frame(height: 44)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
                guard isEnabled else { return }
                let progress = min(1, max(0, (gesture.location.x - 12) / available))
                update(range.lowerBound + (progress * (range.upperBound - range.lowerBound) / step).rounded() * step)
            })
        }
        .frame(height: 44)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(formattedValue)
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            switch direction {
            case .increment: update(value + step)
            case .decrement: update(value - step)
            @unknown default: break
            }
        }
    }

    private func update(_ next: Double) {
        value = min(range.upperBound, max(range.lowerBound, next))
    }
}

/// Warm raised capsule shared by the lighting workspace's primary actions.
