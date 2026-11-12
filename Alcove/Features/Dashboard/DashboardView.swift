import SwiftUI
import SwiftData

public struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NavigationRouter.self) private var environmentRouter: NavigationRouter?
    @Query(sort: \Room.createdAt, order: .reverse) private var rooms: [Room]
    @State private var viewModel = DashboardViewModel()
    @State private var localRouter = NavigationRouter()

    public init() {}

    public var body: some View {
        if environmentRouter != nil {
            dashboardContent
        } else {
            NavigationStack(path: $localRouter.path) {
                dashboardContent
                    .navigationDestination(for: AlcoveRoute.self) { route in
                        switch route {
                        case .stageList(let room):
                            StageListView(room: room)
                        case .studio(let room, let stage):
                            Studio3DView(room: room, stage: stage)
                        case .dashboard:
                            DashboardView()
                        }
                    }
            }
            .environment(localRouter)
        }
    }

    private var dashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                lightingTestShortcut

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
        .onAppear {
            viewModel.seedInitialDataIfNeeded(rooms: rooms, modelContext: modelContext)
        }
        .sheet(isPresented: $viewModel.showingScanSheet) {
            RoomScanSheet { scannedRoom in
                viewModel.addScannedRoom(scannedRoom, modelContext: modelContext)
            }
        }
        .fullScreenCover(item: $viewModel.lightingTestSession) { session in
            NavigationStack {
                Studio3DView(room: session.room, stage: .illumination)
            }
            .environment(session.router)
            .modelContainer(session.container)
        }
        .alert("Could not open lighting test", isPresented: Binding(
            get: { viewModel.lightingTestError != nil },
            set: { if !$0 { viewModel.lightingTestError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.lightingTestError = nil }
        } message: {
            Text(viewModel.lightingTestError ?? "Please try again.")
        }
    }

    private var lightingTestShortcut: some View {
        Button { viewModel.startLightingTest() } label: {
            HStack(spacing: 16) {
                Image(systemName: "lightbulb.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Test Lighting").font(.headline)
                    Text("Add lights and try the simulation in a temporary mock bedroom layout.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .padding(24)
            .background(Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the lighting workspace without completing earlier stages.")
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
