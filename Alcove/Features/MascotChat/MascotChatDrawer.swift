import SwiftUI

/// Mascot interior design chat drawer
public struct MascotChatDrawer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: MascotChatViewModel
    @State private var showingConfigSheet: Bool = false

    public init(
        mascotService: any MascotAIServiceProtocol,
        feedbackService: (any MascotFeedbackServiceProtocol)? = nil,
        currentStage: StageType,
        room: Room,
        initialHistory: [ChatMessage] = [],
        onHistoryUpdated: (([ChatMessage]) -> Void)? = nil
    ) {
        self._viewModel = State(
            initialValue: MascotChatViewModel(
                mascotService: mascotService,
                feedbackService: feedbackService,
                currentStage: currentStage,
                room: room,
                initialHistory: initialHistory,
                onHistoryUpdated: onHistoryUpdated
            )
        )
    }

    public init(viewModel: MascotChatViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        chatBubble(
                            isUser: false,
                            text: "Hi! I'm your interior design companion. Ask me anything about clearance, lighting balance, or furniture placement for \(viewModel.currentStage.title)."
                        )

                        ForEach(viewModel.chatHistory) { entry in
                            chatBubble(isUser: entry.isUser, text: entry.text, modelBadge: entry.modelBadge)
                        }

                        if viewModel.isThinking {
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
                    TextField("Ask mascot about room design...", text: $viewModel.inputPrompt)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { viewModel.sendMessage() }

                    Button {
                        viewModel.sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(viewModel.inputPrompt.trimmingCharacters(in: .whitespaces).isEmpty)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingConfigSheet = true
                    } label: {
                        Label("AI Model", systemImage: "sparkles")
                    }
                }
            }
            .sheet(isPresented: $showingConfigSheet) {
                AIModelConfigSheet(room: viewModel.room, currentStage: viewModel.currentStage)
            }
        }
    }

    private func chatBubble(isUser: Bool, text: String, modelBadge: String? = nil) -> some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                if let modelBadge, !isUser {
                    Text(modelBadge)
                        .font(.caption2.bold())
                        .foregroundStyle(.indigo)
                        .padding(.horizontal, 4)
                }

                if let attributed = try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                    Text(attributed)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isUser ? Color.indigo : Color(uiColor: .secondarySystemGroupedBackground))
                        )
                        .foregroundStyle(isUser ? .white : .primary)
                } else {
                    Text(text)
                        .font(.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isUser ? Color.indigo : Color(uiColor: .secondarySystemGroupedBackground))
                        )
                        .foregroundStyle(isUser ? .white : .primary)
                }
            }
            if !isUser { Spacer(minLength: 40) }
        }
    }

    private func suggestionChip(_ query: String) -> some View {
        Button(query) {
            viewModel.selectSuggestion(query)
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.indigo.opacity(0.12)))
        .foregroundStyle(.indigo)
    }
}
