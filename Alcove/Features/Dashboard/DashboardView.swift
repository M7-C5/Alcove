import SwiftUI
import SwiftData

public struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.createdAt, order: .reverse) private var rooms: [Room]

    @State private var showingScanSheet = false
    @State private var showingNewRoomAlert = false
    @State private var newRoomName = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerSection

                    if rooms.isEmpty {
                        emptyStateSection
                    } else {
                        roomGridSection
                    }
                }
                .padding(32)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Alcove")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingScanSheet = true
                    } label: {
                        Label("Scan Room", systemImage: "camera.viewfinder")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                }
            }
            .onAppear {
                seedInitialDataIfNeeded()
            }
            .sheet(isPresented: $showingScanSheet) {
                MockScanView { scannedRoom in
                    modelContext.insert(scannedRoom)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Text("🛋️")
                    .font(.system(size: 40))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Living Spaces")
                        .font(.largeTitle.bold())
                    Text("Select a room to continue your interior design curriculum.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var roomGridSection: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 340, maximum: 420), spacing: 24)],
            spacing: 24
        ) {
            ForEach(rooms) { room in
                NavigationLink(destination: StageListView(room: room)) {
                    RoomCard(room: room)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "house.and.flag.fill")
                .font(.system(size: 48))
                .foregroundStyle(.indigo)
            Text("No Rooms Yet")
                .font(.title2.bold())
            Text("Scan your physical room with LiDAR or load a sample space to begin.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Load Sample Apartment") {
                seedInitialDataIfNeeded(force: true)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(48)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private func seedInitialDataIfNeeded(force: Bool = false) {
        if rooms.isEmpty || force {
            let sample = SampleData.createStarterRoom()
            modelContext.insert(sample)
        }
    }
}

private struct RoomCard: View {
    let room: Room

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(room.name)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text("\(String(format: "%.1f", room.dimensionsWidth))m × \(String(format: "%.1f", room.dimensionsLength))m · \(String(format: "%.1f", room.dimensionsHeight))m ceiling")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(.tertiary)
            }

            Divider()

            // Stage badges
            VStack(alignment: .leading, spacing: 8) {
                Text("Curriculum Progress")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                HStack(spacing: 8) {
                    ForEach(StageType.allCases) { stage in
                        let isUnlocked = room.isUnlocked(stage)
                        let isCompleted = room.isCompleted(stage)

                        HStack(spacing: 4) {
                            Image(systemName: isCompleted ? "checkmark.circle.fill" : (isUnlocked ? stage.icon : "lock.fill"))
                                .font(.caption)
                            Text("S\(stage.stageNumber)")
                                .font(.caption2.bold())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(
                                isCompleted ? Color.green.opacity(0.18) :
                                (isUnlocked ? Color.indigo.opacity(0.15) : Color.gray.opacity(0.15))
                            )
                        )
                        .foregroundStyle(
                            isCompleted ? Color.green :
                            (isUnlocked ? Color.indigo : Color.secondary)
                        )
                    }
                }
            }

            HStack {
                let itemCount = room.workingLayout?.furnitures.filter { !$0.isArchived }.count ?? 0
                Label("\(itemCount) furniture items", systemImage: "chair.lounge.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Tap to Enter →")
                    .font(.caption.bold())
                    .foregroundStyle(.indigo)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
    }
}

/// Fallback / simulator room scan coordinator sheet
private struct MockScanView: View {
    @Environment(\.dismiss) private var dismiss
    let onRoomScanned: (Room) -> Void

    @State private var roomName = "My Living Room"
    @State private var width: Double = 4.0
    @State private var length: Double = 5.0

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Room Details")) {
                    TextField("Room Name", text: $roomName)
                    Stepper("Width: \(String(format: "%.1f", width))m", value: $width, in: 2.5...12.0, step: 0.5)
                    Stepper("Length: \(String(format: "%.1f", length))m", value: $length, in: 2.5...15.0, step: 0.5)
                }

                Section(header: Text("LiDAR Scanner"), footer: Text("On LiDAR-equipped iPads, RoomPlan capture runs here.")) {
                    Label("RoomPlan Scanning Ready", systemImage: "camera.metering.matrix")
                        .foregroundStyle(.indigo)
                }
            }
            .navigationTitle("New Room Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Scan") {
                        let newRoom = Room(
                            name: roomName.isEmpty ? "Scanned Space" : roomName,
                            dimensionsWidth: width,
                            dimensionsLength: length,
                            dimensionsHeight: 2.6
                        )
                        let baseline = Layout(
                            name: "Original Scan",
                            isBaseline: true,
                            furnitures: [
                                Furniture(name: "Sofa", category: .seating, positionX: 0.0, positionZ: -1.0, width: 2.0, length: 0.9, height: 0.8),
                                Furniture(name: "Coffee Table", category: .table, positionX: 0.0, positionZ: 0.0, width: 1.0, length: 0.6, height: 0.45)
                            ]
                        )
                        let working = baseline.createCopy(name: "Working Layout")
                        newRoom.baselineLayout = baseline
                        newRoom.workingLayout = working
                        baseline.room = newRoom
                        working.room = newRoom

                        onRoomScanned(newRoom)
                        dismiss()
                    }
                }
            }
        }
    }
}
