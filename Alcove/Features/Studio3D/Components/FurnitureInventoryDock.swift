import SwiftUI
import AudioToolbox

/// Floating bottom-center furniture archive dock, inspired by Apple Freeform's tool palette.
/// Displays archived furniture items ready to be restored via single-tap or dragging directly onto the 3D floor.
public struct FurnitureInventoryDock: View {
    public let archivedFurnitures: [Furniture]
    public let dockWidth: CGFloat
    public let onRestoreItem: (Furniture, CGPoint?) -> Void
    public let onCardDragStart: (Furniture, CGPoint) -> Void
    public let onCardDragChanged: (CGPoint) -> Void
    public let onCardDragEnded: (Furniture, CGPoint) -> Void

    public init(
        archivedFurnitures: [Furniture],
        dockWidth: CGFloat = 520,
        onRestoreItem: @escaping (Furniture, CGPoint?) -> Void,
        onCardDragStart: @escaping (Furniture, CGPoint) -> Void,
        onCardDragChanged: @escaping (CGPoint) -> Void,
        onCardDragEnded: @escaping (Furniture, CGPoint) -> Void
    ) {
        self.archivedFurnitures = archivedFurnitures
        self.dockWidth = dockWidth
        self.onRestoreItem = onRestoreItem
        self.onCardDragStart = onCardDragStart
        self.onCardDragChanged = onCardDragChanged
        self.onCardDragEnded = onCardDragEnded
    }

    public var body: some View {
        Group {
            if archivedFurnitures.isEmpty {
                Text("No archived furniture")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .frame(width: dockWidth, alignment: .center)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(archivedFurnitures) { item in
                            ArchivedFurnitureCard(
                                furniture: item,
                                onTap: {
                                    onRestoreItem(item, nil)
                                },
                                onDragStart: { point in
                                    onCardDragStart(item, point)
                                },
                                onDragChanged: { point in
                                    onCardDragChanged(point)
                                },
                                onDragEnded: { point in
                                    onCardDragEnded(item, point)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(minWidth: dockWidth, alignment: .center)
                }
                .frame(width: dockWidth)
            }
        }
        .frame(width: dockWidth)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 6)
    }
}

/// Compact Freeform-style furniture card supporting tap-to-restore or dragging directly into the 3D room.
public struct ArchivedFurnitureCard: View {
    public let furniture: Furniture
    public let onTap: () -> Void
    public let onDragStart: (CGPoint) -> Void
    public let onDragChanged: (CGPoint) -> Void
    public let onDragEnded: (CGPoint) -> Void

    @State private var isDragging: Bool = false

    public init(
        furniture: Furniture,
        onTap: @escaping () -> Void,
        onDragStart: @escaping (CGPoint) -> Void,
        onDragChanged: @escaping (CGPoint) -> Void,
        onDragEnded: @escaping (CGPoint) -> Void
    ) {
        self.furniture = furniture
        self.onTap = onTap
        self.onDragStart = onDragStart
        self.onDragChanged = onDragChanged
        self.onDragEnded = onDragEnded
    }

    public var body: some View {
        VStack(spacing: 4) {
            Image(systemName: furniture.category.icon)
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(height: 28)

            Text(furniture.name)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
        }
        .frame(width: 76, height: 72)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 4, y: 2)
        .opacity(isDragging ? 0.35 : 1.0)
        .gesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .named("Studio3DViewportSpace"))
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        onDragStart(value.location)
                    } else {
                        onDragChanged(value.location)
                    }
                }
                .onEnded { value in
                    isDragging = false
                    onDragEnded(value.location)
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    if !isDragging {
                        onTap()
                    }
                }
        )
        .accessibilityLabel("\(furniture.name), archived")
    }
}
