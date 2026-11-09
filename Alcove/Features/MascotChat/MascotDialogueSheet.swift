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

                        Text(result.dialogue)
                            .font(.body)
                            .lineSpacing(4)
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

/// Mascot interior design chat drawer
public struct MascotChatDrawer: View {
    @Environment(\.dismiss) private var dismiss
    let mascotService: MascotAIServiceProtocol
    let currentStage: StageType
    let room: Room

    @State private var chatHistory: [(isUser: Bool, text: String)] = []
    @State private var inputPrompt: String = ""
    @State private var isThinking: Bool = false

    public init(
        mascotService: MascotAIServiceProtocol,
        currentStage: StageType,
        room: Room
    ) {
        self.mascotService = mascotService
        self.currentStage = currentStage
        self.room = room
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        // Greeting message
                        chatBubble(
                            isUser: false,
                            text: "Hi! I'm your interior design companion. Ask me anything about clearance, lighting balance, or furniture placement for \(currentStage.title)."
                        )

                        ForEach(Array(chatHistory.enumerated()), id: \.offset) { _, entry in
                            chatBubble(isUser: entry.isUser, text: entry.text)
                        }

                        if isThinking {
                            HStack(spacing: 6) {
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            .padding(12)
                        }
                    }
                    .padding(20)
                }

                // Quick suggestions
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        suggestionChip("What clearance do I need?")
                        suggestionChip("How to orient seating?")
                        suggestionChip("Tips for window lighting")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))

                Divider()

                // Input bar
                HStack(spacing: 12) {
                    TextField("Ask mascot about room design...", text: $inputPrompt)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { sendCurrentMessage() }

                    Button {
                        sendCurrentMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(inputPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(16)
                .background(Color(uiColor: .systemBackground))
            }
            .navigationTitle("Ask Design Mascot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func chatBubble(isUser: Bool, text: String) -> some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(text)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isUser ? Color.indigo : Color(uiColor: .secondarySystemGroupedBackground))
                )
                .foregroundStyle(isUser ? .white : .primary)
            if !isUser { Spacer(minLength: 40) }
        }
    }

    private func suggestionChip(_ query: String) -> some View {
        Button(query) {
            inputPrompt = query
            sendCurrentMessage()
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.indigo.opacity(0.12)))
        .foregroundStyle(.indigo)
    }

    private func sendCurrentMessage() {
        let trimmed = inputPrompt.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        inputPrompt = ""
        chatHistory.append((isUser: true, text: trimmed))
        isThinking = true

        Task {
            let response = await mascotService.askMascot(
                question: trimmed,
                currentStage: currentStage,
                room: room
            )
            await MainActor.run {
                chatHistory.append((isUser: false, text: response))
                isThinking = false
            }
        }
    }
}
