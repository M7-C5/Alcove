import SwiftUI

/// Smooth Before / After 3D Spatial Overlay Controller for Stage 4 (The Harmony Reveal).
/// Overlays the original baseline scan and the optimized layout in the exact same 3D room orientation,
/// allowing continuous, buttery-smooth opacity blending without any harsh clipping or popping.
public struct SplitCurtainDividerView: View {
    @Binding public var splitFraction: Double
    public let totalWidth: CGFloat
    public let totalHeight: CGFloat
    public var onDragChanged: ((Double) -> Void)? = nil

    @State private var hasHapticSnappedCenter: Bool = false

    public init(
        splitFraction: Binding<Double>,
        totalWidth: CGFloat,
        totalHeight: CGFloat,
        onDragChanged: ((Double) -> Void)? = nil
    ) {
        self._splitFraction = splitFraction
        self.totalWidth = totalWidth
        self.totalHeight = totalHeight
        self.onDragChanged = onDragChanged
    }

    public var body: some View {
        VStack {
            // Top Floating Status Badges
            HStack {
                // BEFORE Pill
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        splitFraction = 0.0
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 8, height: 8)
                        Text("BEFORE")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(splitFraction < 0.35 ? .primary : .secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(splitFraction < 0.35 ? Color.orange.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
                }
                .buttonStyle(.plain)

                Spacer()

                // Center OVERLAY Pill (Active in middle blend)
                HStack(spacing: 6) {
                    Image(systemName: "square.2.layers.3d.top.filled")
                        .font(.caption.bold())
                        .foregroundStyle(splitFraction >= 0.35 && splitFraction <= 0.65 ? Color.indigo : Color.secondary)
                    Text("OVERLAY")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(splitFraction >= 0.35 && splitFraction <= 0.65 ? Color.indigo : Color.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(splitFraction >= 0.35 && splitFraction <= 0.65 ? Color.indigo.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)

                Spacer()

                // AFTER Pill
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        splitFraction = 1.0
                    }
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("AFTER")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(splitFraction > 0.65 ? .primary : .secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(splitFraction > 0.65 ? Color.green.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 76)

            Spacer()

            // Bottom Center Frosted Glass Overlay Slider
            HStack(spacing: 16) {
                Text("Before")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(splitFraction < 0.25 ? Color.indigo : Color.secondary)

                Slider(
                    value: Binding(
                        get: { splitFraction },
                        set: { newValue in
                            let clamped = max(0.0, min(1.0, newValue))

                            // Snap tick at the 50% overlay point
                            if abs(clamped - 0.50) < 0.02 {
                                if !hasHapticSnappedCenter {
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    hasHapticSnappedCenter = true
                                }
                            } else {
                                hasHapticSnappedCenter = false
                            }

                            splitFraction = clamped
                            onDragChanged?(clamped)
                        }
                    ),
                    in: 0.0...1.0
                )
                .tint(.indigo)
                .frame(width: 300)
                .accessibilityLabel("Before After 3D Overlay Blend Slider")

                Text("After")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(splitFraction > 0.75 ? Color.indigo : Color.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(.regularMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 14, y: 4)
            .padding(.bottom, 28)
            .safeAreaPadding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(true)
    }
}
