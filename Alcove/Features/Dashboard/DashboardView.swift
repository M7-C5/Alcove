import SwiftUI
import SwiftData

public struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.createdAt, order: .reverse) private var rooms: [Room]
    @State private var viewModel = DashboardViewModel()
    @State private var router = NavigationRouter()

    public init() {}

    public var body: some View {
        NavigationStack(path: $router.path) {
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
                    HStack(spacing: 12) {
                        Button {
                            viewModel.seedBedroomOfficeCombo(modelContext: modelContext)
                        } label: {
                            Label("Add Mock Bedroom", systemImage: "plus.square.dashed")
                        }

                        Button {
                            viewModel.showingScanSheet = true
                        } label: {
                            Label("Scan Room", systemImage: "camera.viewfinder")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                    }
                }
            }
            .navigationDestination(for: AlcoveRoute.self) { route in
                switch route {
                case .stageList(let room):
                    StageListView(room: room)
                case .studio(let room, let stage):
                    Studio3DView(room: room, stage: stage)
                }
            }
            .onAppear {
                viewModel.seedInitialDataIfNeeded(rooms: rooms, modelContext: modelContext)
            }
            .sheet(isPresented: $viewModel.showingScanSheet) {
                RoomScanSheet { scannedRoom in
                    viewModel.addScannedRoom(scannedRoom, modelContext: modelContext)
                }
            }
        }
        .environment(router)
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
                NavigationLink(value: AlcoveRoute.stageList(room)) {
                    RoomCardView(room: room)
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
            HStack(spacing: 12) {
                Button("Load Sample Studio") {
                    viewModel.seedInitialDataIfNeeded(rooms: rooms, modelContext: modelContext, force: true)
                }
                .buttonStyle(.bordered)

                Button("Load Master Bedroom") {
                    viewModel.seedCozyBedroom(modelContext: modelContext)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(48)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}
