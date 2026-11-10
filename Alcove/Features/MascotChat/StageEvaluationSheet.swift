import SwiftUI

/// Advisory stage evaluation dialog presenting Mascot's critique with override option
public struct StageEvaluationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let result: StageEvaluationResult
    let stage: StageType
    let onProceedAnyway: () -> Void
    let onKeepRefining: () -> Void

    public init(
        result: StageEvaluationResult,
        stage: StageType,
        onProceedAnyway: @escaping () -> Void,
        onKeepRefining: @escaping () -> Void
    ) {
        self.result = result
        self.stage = stage
        self.onProceedAnyway = onProceedAnyway
        self.onKeepRefining = onKeepRefining
    }

    private var scoreColor: Color {
        if result.score >= 80 {
            return .green
        } else if result.score >= 60 {
            return .orange
        } else {
            return .red
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Score & Mascot Verdict
                    HStack(spacing: 16) {
                        Text(result.canAdvance ? "🎉" : "🤔")
                            .font(.system(size: 48))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(result.title)
                                .font(.title2.bold())
                            Text("Evaluation Score: \(result.score)/100")
                                .font(.subheadline.bold())
                                .foregroundStyle(scoreColor)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )

                    // Mascot Dialogue
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Mascot Critique", systemImage: "quote.bubble.fill")
                            .font(.caption.bold())
                            .foregroundStyle(.indigo)
                            .textCase(.uppercase)

                        if let attributed = try? AttributedString(markdown: result.dialogue, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                            Text(attributed)
                                .font(.body)
                                .lineSpacing(4)
                        } else {
                            Text(result.dialogue)
                                .font(.body)
                                .lineSpacing(4)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.indigo.opacity(0.08))
                    )

                    // Bottlenecks section (if any)
                    if !result.bottlenecks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Identified Bottlenecks")
                                .font(.headline)

                            ForEach(result.bottlenecks) { bottleneck in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.orange)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(bottleneck.title)
                                            .font(.subheadline.bold())
                                        Text(bottleneck.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.orange.opacity(0.1))
                                )
                            }
                        }
                    }

                    // Recommendations section (textbook-grounded improvements)
                    if !result.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Textbook Recommendations")
                                .font(.headline)

                            ForEach(result.recommendations, id: \.self) { rec in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(.yellow)
                                        .font(.subheadline)
                                        .padding(.top, 2)
                                    if let attributed = try? AttributedString(markdown: rec, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                                        Text(attributed)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                    } else {
                                        Text(rec)
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                                )
                            }
                        }
                    }

                    // Praise
                    if !result.praise.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("What Works Well")
                                .font(.headline)

                            ForEach(result.praise, id: \.self) { point in
                                Label(point, systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                            }
                        }
                    }

                    // Action buttons
                    VStack(spacing: 12) {
                        Button {
                            onProceedAnyway()
                            dismiss()
                        } label: {
                            HStack {
                                Text(result.canAdvance ? "Advance to Next Stage" : "Proceed Anyway (Advisory Override)")
                                Image(systemName: "arrow.right")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(result.canAdvance ? .indigo : .secondary)

                        Button("Keep Refining Layout") {
                            onKeepRefining()
                            dismiss()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 16)
                }
                .padding(28)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Stage Evaluation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
