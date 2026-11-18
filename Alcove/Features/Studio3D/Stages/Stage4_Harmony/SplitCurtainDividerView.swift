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
        let brown = Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0)
        let cream = Color(red: 0xFF / 255.0, green: 0xF7 / 255.0, blue: 0xE7 / 255.0)
        let gold = Color(red: 0xFB / 255.0, green: 0xD4 / 255.0, blue: 0x60 / 255.0)
        let beforeDot = Color(red: 0xD4 / 255.0, green: 0x63 / 255.0, blue: 0x63 / 255.0)
        let afterDot = Color(red: 0x6B / 255.0, green: 0x9E / 255.0, blue: 0x5B / 255.0)

        ZStack(alignment: .topLeading) {
            // Floating "Before" and "After" Badges positioned cleanly below the header & stepper
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(beforeDot)
                        .frame(width: 10, height: 10)
                    Text("Before")
                        .font(.custom("Cleanow", size: 17, relativeTo: .subheadline))
                        .foregroundStyle(brown)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(cream, in: Capsule())
                .overlay(Capsule().stroke(brown, lineWidth: 2))
                .opacity(splitFraction > 0.12 ? 1.0 : 0.45)
                .padding(.leading, 28)

                Spacer()

                HStack(spacing: 8) {
                    Circle()
                        .fill(afterDot)
                        .frame(width: 10, height: 10)
                    Text("After")
                        .font(.custom("Cleanow", size: 17, relativeTo: .subheadline))
                        .foregroundStyle(brown)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(cream, in: Capsule())
                .overlay(Capsule().stroke(brown, lineWidth: 2))
                .opacity(splitFraction < 0.88 ? 1.0 : 0.45)
                .padding(.trailing, 28)
            }
            .padding(.top, 146)
            .safeAreaPadding(.top)
            .frame(width: totalWidth)
            .allowsHitTesting(false)

            // Vertical Divider Line + Center Handle Knob (ONLY the 44pt line strip captures drags;
            // the rest of the 3D viewport passes touches through so orbit & pinch-to-zoom work freely)
            ZStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                brown.opacity(0.20),
                                brown.opacity(0.95),
                                brown.opacity(0.95),
                                brown.opacity(0.20)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: totalHeight)

                ZStack {
                    Circle()
                        .fill(gold)
                        .frame(width: 46, height: 46)
                        .overlay(Circle().stroke(brown, lineWidth: 2.5))

                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(brown)
                }
                .scaleEffect(isDragging ? 1.12 : 1.0)
                .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isDragging)
            }
            .frame(width: 44, height: totalHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .named("SplitCurtainSpace"))
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
            .position(x: dividerX, y: totalHeight / 2)
        }
        .frame(width: totalWidth, height: totalHeight, alignment: .topLeading)
        .coordinateSpace(name: "SplitCurtainSpace")
    }
}
