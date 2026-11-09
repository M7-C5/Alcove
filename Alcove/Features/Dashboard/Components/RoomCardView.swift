import SwiftUI

public struct RoomCardView: View {
    let room: Room

    public init(room: Room) {
        self.room = room
    }

    public var body: some View {
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
