import SwiftUI

public struct RoomScanSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let onRoomScanned: (Room) -> Void

    @State private var roomName = "My Living Room"
    @State private var width: Double = 4.0
    @State private var length: Double = 5.0
    @State private var compass = RoomCompassCapture()

    public init(onRoomScanned: @escaping (Room) -> Void) {
        self.onRoomScanned = onRoomScanned
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Room Details")) {
                    TextField("Room Name", text: $roomName)
                    Stepper("Width: \(String(format: "%.1f", width))m", value: $width, in: 2.5...12.0, step: 0.5)
                    Stepper("Length: \(String(format: "%.1f", length))m", value: $length, in: 2.5...15.0, step: 0.5)
                }

                Section(
                    header: Text("LiDAR Scanner"),
                    footer: Text("On LiDAR-equipped iPads, RoomPlan capture runs here.")
                ) {
                    Label("RoomPlan Scanning Ready", systemImage: "camera.metering.matrix")
                        .foregroundStyle(.indigo)
                }
                compassSection
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
                        newRoom.compassOrientation = compass.orientation
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
        .onAppear { compass.start() }
        .onDisappear { compass.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { compass.start() } else { compass.stop() }
        }
    }

    private var compassSection: some View {
        Section {
            Label(compassMessage, systemImage: "location.north.circle")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text("Room direction")
        } footer: {
            Text("Hold iPad upright facing the front of your room until north is found. This direction becomes the room’s front for the sunlight preview.")
        }
    }

    private var compassMessage: String {
        switch compass.status {
        case .searching: return "Finding magnetic north… Hold iPad steady."
        case .needsCalibration: return "Move iPad gently to calibrate the compass."
        case .needsUpright: return "Hold iPad upright facing the front of your room."
        case .captured:
            return "North captured · Room front \(Int((compass.orientation?.magneticForwardBearingDegrees ?? 0).rounded()) % 360)°"
        case .unavailable: return "Compass unavailable. Sunlight will use a sample direction."
        case .failed: return "Couldn’t read the compass. Sunlight will use a sample direction."
        }
    }
}
