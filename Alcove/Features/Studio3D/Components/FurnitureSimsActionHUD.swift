import SwiftUI

/// Projected floating action cluster positioned directly over a selected 3D furniture entity,
/// mirroring Resign's circular dial HUD.
/// Features a circular halo dial, circular motion rotation tracking where the rotate button glides along the orbit rim,
/// and instant archival.
public struct FurnitureSimsActionHUD: View {
    public let furniture: Furniture
    public let isColliding: Bool
    public let warningSeverity: SpatialWarningSeverity?
    public let onStepRotate: () -> Void
    public let onCircularRotate: (Float) -> Void
    public let onDragRotateEnded: () -> Void
    public let onArchive: () -> Void
    public let onSwap: () -> Void
    public let onRemove: (() -> Void)?

    @State private var dragStartLocation: CGPoint? = nil
    @State private var previousLocation: CGPoint? = nil
    @State private var accumulatedAngle: Float = 0
    @State private var isDraggingRotate: Bool = false
    @State private var currentDragAngle: CGFloat? = nil

    private let dialRadius: CGFloat = 88
    private let buttonRadius: CGFloat = 23
    private let defaultRotateAngle: CGFloat = -.pi * 0.94 // ~ -170° (bottom-left)
    private let defaultArchiveAngle: CGFloat = -.pi * 0.69 // ~ -125° (top-left)
    private let defaultSwapAngle: CGFloat = -.pi * 0.31 // ~ -55° (top-right)
    private let defaultRemoveAngle: CGFloat = -.pi * 0.06 // ~ -10° (bottom-right)

    public init(
        furniture: Furniture,
        isColliding: Bool = false,
        warningSeverity: SpatialWarningSeverity? = nil,
        onStepRotate: @escaping () -> Void,
        onCircularRotate: @escaping (Float) -> Void,
        onDragRotateEnded: @escaping () -> Void,
        onArchive: @escaping () -> Void,
        onSwap: @escaping () -> Void = {},
        onRemove: (() -> Void)? = nil
    ) {
        self.furniture = furniture
        self.isColliding = isColliding
        self.warningSeverity = warningSeverity
        self.onStepRotate = onStepRotate
        self.onCircularRotate = onCircularRotate
        self.onDragRotateEnded = onDragRotateEnded
        self.onArchive = onArchive
        self.onSwap = onSwap
        self.onRemove = onRemove
    }

    private var dialDiameter: CGFloat {
        dialRadius * 2
    }

    private var centerPoint: CGPoint {
        CGPoint(x: dialRadius, y: dialRadius)
    }

    public var body: some View {
        ZStack {
            // 1. Translucent Circular Halo / Dial
            // Hit-testing disabled so 3D furniture underneath remains directly selectable and draggable
            let effectiveSeverity = warningSeverity ?? (isColliding ? .collision : nil)
            let haloFill: Color = switch effectiveSeverity {
            case .collision: Color.red.opacity(0.18)
            case .caution: Color.yellow.opacity(0.18)
            case nil: Color.white.opacity(0.48)
            }
            let haloStroke: Color = switch effectiveSeverity {
            case .collision: Color.red.opacity(0.85)
            case .caution: Color.yellow.opacity(0.95)
            case nil: Color.white.opacity(0.55)
            }
            let haloLineWidth: CGFloat = effectiveSeverity == nil ? 1.5 : 2.5

            Circle()
                .fill(haloFill)
                .overlay(
                    Circle()
                        .stroke(haloStroke, lineWidth: haloLineWidth)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
                .frame(width: dialDiameter, height: dialDiameter)
                .allowsHitTesting(false)

            // 2. Archive Button (Fixed on rim at top-left)
            Button {
                onArchive()
            } label: {
                actionButtonContent(systemName: "archivebox.fill")
            }
            .buttonStyle(.plain)
            .frame(width: 48, height: 48)
            .contentShape(Circle())
            .offset(
                x: dialRadius * cos(defaultArchiveAngle),
                y: dialRadius * sin(defaultArchiveAngle)
            )
            .accessibilityLabel("Archive furniture to inventory")

            // 3. Swap Button (Fixed on rim at top-right)
            Button {
                onSwap()
            } label: {
                actionButtonContent(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(.plain)
            .frame(width: 48, height: 48)
            .contentShape(Circle())
            .offset(
                x: dialRadius * cos(defaultSwapAngle),
                y: dialRadius * sin(defaultSwapAngle)
            )
            .accessibilityLabel("Swap furniture with catalog item")

            // 4. Remove Button (Fixed on rim at bottom-right; only for user-added items)
            if furniture.isUserAdded, let onRemove {
                Button {
                    onRemove()
                } label: {
                    actionButtonContent(systemName: "trash.fill", tint: .red)
                }
                .buttonStyle(.plain)
                .frame(width: 48, height: 48)
                .contentShape(Circle())
                .offset(
                    x: dialRadius * cos(defaultRemoveAngle),
                    y: dialRadius * sin(defaultRemoveAngle)
                )
                .accessibilityLabel("Remove added furniture")
            }

            // 3. Rotate Button (Draggable along circular orbit rim)
            let activeRotateAngle = currentDragAngle ?? defaultRotateAngle
            actionButtonContent(systemName: "arrow.clockwise")
                .frame(width: 48, height: 48)
                .contentShape(Circle())
                .offset(
                    x: dialRadius * cos(activeRotateAngle),
                    y: dialRadius * sin(activeRotateAngle)
                )
                .accessibilityLabel("Rotate 45 degrees or drag around dial to turn smoothly")
                .gesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .named("SimsHUDCoordinateSpace"))
                        .onChanged { value in
                            handleRotateGestureChanged(value: value)
                        }
                        .onEnded { value in
                            handleRotateGestureEnded(value: value)
                        }
                )
        }
        .frame(width: dialDiameter, height: dialDiameter)
        .coordinateSpace(name: "SimsHUDCoordinateSpace")
    }

    private func actionButtonContent(systemName: String, tint: Color = Color(uiColor: .label)) -> some View {
        ZStack {
            Circle()
                .fill(tint)
                .frame(width: buttonRadius * 2, height: buttonRadius * 2)
                .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.22), radius: 5, x: 0, y: 2)

            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white)
        }
        .frame(width: 48, height: 48)
    }

    private func handleRotateGestureChanged(value: DragGesture.Value) {
        let center = centerPoint
        if dragStartLocation == nil {
            dragStartLocation = value.startLocation
            previousLocation = value.startLocation
            accumulatedAngle = 0
            isDraggingRotate = false
        }

        let dist = hypot(value.location.x - value.startLocation.x, value.location.y - value.startLocation.y)
        if dist >= 4 {
            isDraggingRotate = true
            let touchAngle = atan2(value.location.y - center.y, value.location.x - center.x)
            currentDragAngle = touchAngle
        }

        if isDraggingRotate, let prev = previousLocation {
            let delta = FurnitureTransformEngine.circularAngleDelta(
                center: center,
                previous: prev,
                current: value.location
            )
            accumulatedAngle += delta
            previousLocation = value.location
            onCircularRotate(accumulatedAngle)
        }
    }

    private func handleRotateGestureEnded(value: DragGesture.Value) {
        let wasDrag = isDraggingRotate
        dragStartLocation = nil
        previousLocation = nil
        isDraggingRotate = false
        accumulatedAngle = 0

        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
            currentDragAngle = nil
        }

        if wasDrag {
            onDragRotateEnded()
        } else {
            onStepRotate()
        }
    }

    /// Clamps projected 3D coordinates safely within the visible screen frame.
    public static func clampedPosition(
        projected: CGPoint,
        in screenSize: CGSize,
        verticalOffset: CGFloat = 0
    ) -> CGPoint {
        let marginX: CGFloat = 60
        let minX = marginX
        let maxX = max(minX, screenSize.width - marginX)
        let clampedX = min(maxX, max(minX, projected.x))

        let minY: CGFloat = 60
        let maxY = max(minY, screenSize.height - 80)
        let rawY = projected.y - verticalOffset
        let clampedY = min(maxY, max(minY, rawY))

        return CGPoint(x: clampedX, y: clampedY)
    }
}
