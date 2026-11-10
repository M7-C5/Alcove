import SwiftUI
import SwiftData

/// 3D Studio workspace rendering the low-poly RealityKit room and furniture layout.
public struct Studio3DView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NavigationRouter.self) private var router: NavigationRouter?
    public let room: Room
    public let stage: StageType

    @State private var selectedFurnitureID: UUID?

    public init(room: Room, stage: StageType = .rearrangement) {
        self.room = room
        self.stage = stage
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Interactive 3D RealityKit Viewport
            Studio3DViewport(room: room, selectedFurnitureID: $selectedFurnitureID)
                .ignoresSafeArea()

            // Top Navigation HUD: Back button & Room Title
            HStack(spacing: 12) {
                Button {
                    if let router, !router.isEmpty {
                        router.pop()
                    } else {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                        Text("Stages")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(.regularMaterial, in: Capsule())
                }

                Spacer()

                // Room Title Pill
                HStack(spacing: 8) {
                    Image(systemName: "cube.transparent")
                        .foregroundStyle(.secondary)
                    Text(room.name)
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 44)
                .background(.regularMaterial, in: Capsule())
            }
            .padding(16)
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview("Mock Bedroom & Office") {
    let mockRoom = MockRoomGenerator.generateBedroomOfficeCombo()
    return Studio3DView(room: mockRoom)
}
