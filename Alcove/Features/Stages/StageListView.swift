import SwiftUI
import SwiftData

public struct StageListView: View {
    @Bindable var room: Room
    @State private var showingResetConfirmation = false

    public init(room: Room) {
        self.room = room
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
                                NavigationLink(destination: Studio3DView(room: room, stage: stage)) {
                                    StageCard(stage: stage, isUnlocked: true, isCompleted: isCompleted, score: progress?.score ?? 0)
                                }
                                .buttonStyle(.plain)
                            } else {
                                StageCard(stage: stage, isUnlocked: false, isCompleted: false, score: 0)
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
                    showingResetConfirmation = true
                } label: {
                    Label("Reset Room", systemImage: "arrow.counterclockwise")
                        .font(.subheadline)
                }
            }
        }
        .confirmationDialog(
            "Reset Room to Baseline Scan?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to Original Scan", role: .destructive) {
                room.resetWorkingLayoutToBaseline()
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
                let completedCount = room.stageProgress.filter { $0.isCompleted }.count
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(completedCount) of 4 Completed")
                        .font(.subheadline.bold())
                        .foregroundStyle(.indigo)
                    ProgressView(value: Double(completedCount), total: 4.0)
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

private struct StageCard: View {
    let stage: StageType
    let isUnlocked: Bool
    let isCompleted: Bool
    let score: Int

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : (isUnlocked ? Color.indigo : Color.secondary.opacity(0.3)))
                    .frame(width: 56, height: 56)
                Image(systemName: isCompleted ? "checkmark" : (isUnlocked ? stage.icon : "lock.fill"))
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("STAGE \(stage.stageNumber)")
                        .font(.caption.bold())
                        .foregroundStyle(isCompleted ? Color.green : (isUnlocked ? Color.indigo : Color.secondary))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(
                                isCompleted ? Color.green.opacity(0.15) :
                                (isUnlocked ? Color.indigo.opacity(0.12) : Color.gray.opacity(0.12))
                            )
                        )

                    if isCompleted {
                        Text("Score: \(score)/100")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }
                }

                Text(stage.title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Text(stage.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isUnlocked {
                HStack(spacing: 4) {
                    Text(isCompleted ? "Review" : "Enter")
                        .font(.callout.bold())
                    Image(systemName: "chevron.right")
                        .font(.footnote.bold())
                }
                .foregroundStyle(.indigo)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(Color.indigo.opacity(0.12))
                )
            } else {
                Text("Complete Stage \(stage.stageNumber - 1) first")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 3)
        )
    }
}
