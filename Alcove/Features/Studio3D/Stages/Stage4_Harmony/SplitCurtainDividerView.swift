import SwiftUI

/// Interactive vertical split-screen divider slider (like photo editing before/after comparison tools).
/// Features a vertical divider line with an interactive center handle knob that can be dragged
/// horizontally across the screen to smoothly reveal the Before (Baseline) and After (Optimized) layouts.
public struct SplitCurtainDividerView: View {
    @Binding public var splitFraction: Double
    public let totalWidth: CGFloat
    public let totalHeight: CGFloat
    public var onDragChanged: ((Double) -> Void)? = nil

    @State private var isDragging: Bool = false
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

    private var dividerX: CGFloat {
        max(24, min(totalWidth - 24, totalWidth * CGFloat(splitFraction)))
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Floating "BEFORE" and "AFTER" Badges at Top of Screen
            HStack {
                // BEFORE Pill (Baseline Layout)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                    Text("BEFORE")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(splitFraction > 0.15 ? .primary : .secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
                .padding(.leading, 24)

                Spacer()

                // AFTER Pill (Optimized Layout)
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("AFTER")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(splitFraction < 0.85 ? .primary : .secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
                .padding(.trailing, 24)
            }
            .padding(.top, 76)
            .frame(width: totalWidth)

            // Vertical Divider Line Across Full Screen Height
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2.5, height: totalHeight)
                .shadow(color: Color.black.opacity(0.40), radius: 4, x: 0, y: 0)
                .position(x: dividerX, y: totalHeight / 2)

            // Interactive Center Circular Handle Knob (< | >)
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 48, height: 48)
                    .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 3)

                Image(systemName: "arrow.left.and.right")
                    .font(.body.weight(.bold))
                    .foregroundStyle(Color.black.opacity(0.85))
            }
            .position(x: dividerX, y: totalHeight / 2)
            .contentShape(Circle().inset(by: -16))
            .scaleEffect(isDragging ? 1.15 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isDragging)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let rawFraction = Double(gesture.location.x / totalWidth)
                        let clamped = max(0.02, min(0.98, rawFraction))

                        // Haptic feedback snap when crossing the 50% midpoint
                        if abs(clamped - 0.50) < 0.025 {
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
                    .onEnded { _ in
                        isDragging = false
                        hasHapticSnappedCenter = false
                    }
            )
        }
        .allowsHitTesting(true)
    }
}
