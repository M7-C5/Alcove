import SwiftUI

public struct StageCardView: View {
    let stage: StageType
    let isUnlocked: Bool
    let isCompleted: Bool
    let score: Int

    public init(
        stage: StageType,
        isUnlocked: Bool,
        isCompleted: Bool,
        score: Int
    ) {
        self.stage = stage
        self.isUnlocked = isUnlocked
        self.isCompleted = isCompleted
        self.score = score
    }

    public var body: some View {
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
