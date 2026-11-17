import SwiftUI
import SwiftData

public struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.createdAt, order: .reverse) private var rooms: [Room]
    @State private var viewModel = DashboardViewModel()
    @State private var router = NavigationRouter()

    // Carousel & menu state keyed by Room.ID
    @State private var centeredRoomID: UUID?
    @State private var roomToRename: Room?
    @State private var newLayoutName = ""
    @State private var roomToDelete: Room?
    @State private var openMenuRoomID: UUID?

    private let cardSpacing: CGFloat = 32
    private let seedOnAppear: Bool

    public init(seedOnAppear: Bool = true) {
        self.seedOnAppear = seedOnAppear
    }

    public var body: some View {
        NavigationStack(path: $router.path) {
            GeometryReader { geometry in
                ZStack {
                    dashboardBackground
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                openMenuRoomID = nil
                            }
                        }

                    if rooms.isEmpty {
                        emptyStateView
                    } else {
                        filledStateView(availableSize: geometry.size)
                    }

                    VStack {
                        headerView
                        Spacer()
                    }

                    VStack {
                        Spacer()
                        startScanningButton
                            .padding(.bottom, 48)
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .overlay {
                    alertOverlay
                }
                .toolbar(.hidden, for: .navigationBar)
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
                if seedOnAppear {
                    viewModel.seedInitialDataIfNeeded(rooms: rooms, modelContext: modelContext)
                }
                if centeredRoomID == nil {
                    centeredRoomID = rooms.first?.id
                }
            }
            .sheet(isPresented: $viewModel.showingScanSheet) {
                RoomScanSheet { scannedRoom in
                    viewModel.addScannedRoom(scannedRoom, modelContext: modelContext)
                    centeredRoomID = scannedRoom.id
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
        .environment(router)
    }

    // MARK: - Alert Overlay

    @ViewBuilder
    private var alertOverlay: some View {
        ZStack {
            if roomToRename != nil || roomToDelete != nil {
                Color.black.opacity(0.30)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            roomToRename = nil
                            roomToDelete = nil
                        }
                    }
                    .transition(.opacity)
            }

            if roomToRename != nil {
                LayoutAlert(
                    type: .edit,
                    layoutName: $newLayoutName,
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            roomToRename = nil
                        }
                    },
                    onConfirm: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            renameLayout()
                        }
                    }
                )
                .offset(y: -55)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity.combined(with: .scale(scale: 0.97))
                    )
                )
            }

            if let targetRoom = roomToDelete {
                LayoutAlert(
                    type: .delete,
                    layoutName: .constant(targetRoom.name),
                    onCancel: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            roomToDelete = nil
                        }
                    },
                    onConfirm: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            deleteLayout()
                        }
                    }
                )
                .offset(y: -55)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.92)),
                        removal: .opacity.combined(with: .scale(scale: 0.97))
                    )
                )
            }
        }
    }

    // MARK: - Background & Header

    @ViewBuilder
    private var dashboardBackground: some View {
        GeometryReader { geometry in
            Image("DashboardPattern")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .ignoresSafeArea()
    }

    private var headerView: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Rooms")
                .font(.custom("Cleanow", size: 36, relativeTo: .largeTitle))
                .foregroundStyle(Color.alcoveInk)

            Spacer()

            Button {
                viewModel.seedBedroomOfficeCombo(modelContext: modelContext)
            } label: {
                Label("Add Mock Room", systemImage: "plus.square.dashed")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.alcoveInk)
                    .padding(.horizontal, 14)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(Color.alcoveSurface.opacity(0.92), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.alcoveInk, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add mock bedroom layout")

            Button {
                viewModel.startLightingTest()
            } label: {
                Label("Test Lighting", systemImage: "lightbulb.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Color.alcoveInk)
                    .padding(.horizontal, 14)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(Color.alcoveSurface.opacity(0.92), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.alcoveInk, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open lighting test playground")
        }
        .padding(.horizontal, 34)
        .padding(.top, 18)
    }

    // MARK: - States

    private var emptyStateView: some View {
        VStack(spacing: 0) {
            Image(systemName: "square.split.bottomrightquarter")
                .font(.system(size: 55))
                .foregroundStyle(Color.alcoveEmptyStateText)
                .padding(.bottom, 15)

            Text("No Layout Yet.")
                .font(.custom("Cleanow", size: 30, relativeTo: .title))
                .foregroundStyle(Color.alcoveEmptyStateText)
                .padding(.bottom, 6)

            Text(
                "Create a layout to start planning and arranging your room.\nTap the 'Start Scanning' button to get started."
            )
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .foregroundStyle(Color.alcoveEmptyStateText)
            .multilineTextAlignment(.center)
            .lineSpacing(9)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: -5)
    }

    private func filledStateView(availableSize: CGSize) -> some View {
        let cardWidth = min(600, availableSize.width * 0.46)
        let cardHeight = cardWidth * 0.94

        return ScrollView(.horizontal) {
            LazyHStack(spacing: cardSpacing) {
                ForEach(rooms) { room in
                    roomCard(for: room, cardWidth: cardWidth, cardHeight: cardHeight)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .onScrollPhaseChange { _, newPhase in
            if newPhase == .interacting || newPhase == .decelerating {
                guard openMenuRoomID != nil else { return }
                withAnimation(.easeInOut(duration: 0.18)) {
                    openMenuRoomID = nil
                }
            }
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always, anchor: .center))
        .scrollPosition(id: $centeredRoomID)
        .contentMargins(
            .horizontal,
            max(0, (availableSize.width - cardWidth) / 2),
            for: .scrollContent
        )
        .frame(height: cardHeight + 110)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: -25)
    }

    @ViewBuilder
    private func roomCard(for room: Room, cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        LayoutCardView(
            layoutID: room.id,
            layoutName: room.name,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            onTap: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    openMenuRoomID = nil
                }
                router.push(.stageList(room))
            },
            onEdit: {
                withAnimation(.easeInOut(duration: 0.18)) {
                    openMenuRoomID = nil
                }
                newLayoutName = room.name
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    roomToRename = room
                }
            },
            onDelete: {
                openMenuRoomID = nil
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    roomToDelete = room
                }
            },
            openMenuLayoutID: $openMenuRoomID
        )
        .scrollTransition(
            .interactive(timingCurve: .easeInOut),
            axis: .horizontal
        ) { content, phase in
            content
                .scaleEffect(1 - 0.07 * abs(phase.value))
                .rotationEffect(.degrees(phase.value * 5))
                .offset(y: 14 * abs(phase.value))
        }
        .id(room.id)
    }

    // MARK: - Start Scanning CTA

    private var startScanningButton: some View {
        Button {
            viewModel.showingScanSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 28, weight: .bold))

                Text("Start Scanning")
                    .font(.custom("Cleanow", size: 36, relativeTo: .title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Color.alcoveInk)
            .padding(.horizontal, 36)
            .frame(minHeight: 87)
            .background {
                GeometryReader { geometry in
                    let border: CGFloat = 5
                    let band: CGFloat = 7

                    ZStack {
                        Capsule()
                            .fill(Color.alcovePrimaryShadow)
                            .padding(border)

                        Capsule()
                            .fill(Color.alcovePrimaryHighlight)
                            .padding(.horizontal, border)
                            .padding(.top, border)
                            .padding(.bottom, border + band)
                            .mask(alignment: .top) {
                                Rectangle().frame(height: geometry.size.height * 0.52)
                            }

                        Capsule()
                            .fill(Color.alcovePrimaryFill)
                            .padding(.horizontal, border)
                            .padding(.top, border + band)
                            .padding(.bottom, border + band)

                        Capsule()
                            .strokeBorder(Color.alcoveInk, lineWidth: border)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start scanning a room")
    }

    // MARK: - Persistence Actions

    private func renameLayout() {
        guard let target = roomToRename else { return }

        let trimmedName = newLayoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            roomToRename = nil
            return
        }

        target.name = trimmedName
        roomToRename = nil
    }

    private func deleteLayout() {
        guard let target = roomToDelete else { return }
        let deletedID = target.id
        modelContext.delete(target)

        if centeredRoomID == deletedID {
            centeredRoomID = rooms.first(where: { $0.id != deletedID })?.id
        }
        roomToDelete = nil
    }
}

#Preview("Empty Dashboard", traits: .landscapeRight) {
    DashboardView(seedOnAppear: false)
        .modelContainer(try! ModelContainer.createInMemoryContainer())
}

#Preview("Seeded Dashboard", traits: .landscapeRight) {
    DashboardView()
        .modelContainer(try! ModelContainer.createPreviewContainer())
}
