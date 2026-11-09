import SwiftUI
import SwiftData

public struct StageListView: View {
    @Bindable var room: Room
    @State private var viewModel: StageListViewModel

    public init(room: Room) {
        self.room = room
        self._viewModel = State(initialValue: StageListViewModel(room: room))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                roomHeaderSection

                VStack(alignment: .leading, spacing: 16) {
                    Text("Design Stages")
                        .font(.title2.bold())

                    VStack(spacing: 16) {
                        ForEach(StageType.allCases) { stage in
                            let isUnlocked = room.isUnlocked(stage)
                            let isCompleted = room.isCompleted(stage)
                            let progress = room.progress(for: stage)

                            if isUnlocked {
                                NavigationLink(value: AlcoveRoute.studio(room: room, stage: stage)) {
                                    StageCardView(
                                        stage: stage,
                                        isUnlocked: true,
                                        isCompleted: isCompleted,
                                        score: progress?.score ?? 0
                                    )
                                }
                                .buttonStyle(.plain)
                            } else {
                                StageCardView(
                                    stage: stage,
                                    isUnlocked: false,
                                    isCompleted: false,
                                    score: 0
                                )
                                .opacity(0.55)
                            }
                        }
                    }
                }
            }
            .padding(32)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(room.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    viewModel.showingResetConfirmation = true
                } label: {
                    Label("Reset Room", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                }
            }
        }
        .confirmationDialog(
            "Reset Room to Baseline Scan?",
            isPresented: $viewModel.showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to Original Scan", role: .destructive) {
                viewModel.resetWorkingLayoutToBaseline()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore all furniture to their exact captured positions from the original LiDAR scan.")
        }
    }

    private var roomHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(room.name)
                        .font(.largeTitle.bold())
                    Text("Dimensions: \(String(format: "%.1f", room.dimensionsWidth))m width × \(String(format: "%.1f", room.dimensionsLength))m length · Ceiling \(String(format: "%.1f", room.dimensionsHeight))m")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(viewModel.completedStagesCount) of \(viewModel.totalStagesCount) Completed")
                        .font(.subheadline.bold())
                        .foregroundStyle(.indigo)
                    ProgressView(value: viewModel.progressRatio)
                        .frame(width: 160)
                        .tint(.indigo)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}
