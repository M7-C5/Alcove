import SwiftUI
import UIKit

/// Inline Otter chat overlay matching Alcove's 3D Figma inspector design.
public struct MascotChatDrawer: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: MascotChatViewModel
    @State private var keyboardHeight: CGFloat = 0
    private let onClose: (() -> Void)?

    public init(
        mascotService: any MascotAIServiceProtocol,
        feedbackService: (any MascotFeedbackServiceProtocol)? = nil,
        currentStage: StageType,
        room: Room,
        initialHistory: [ChatMessage] = [],
        onHistoryUpdated: (([ChatMessage]) -> Void)? = nil,
        onClose: (() -> Void)? = nil
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
        self.onClose = onClose
    }

    public init(viewModel: MascotChatViewModel, onClose: (() -> Void)? = nil) {
        self._viewModel = State(initialValue: viewModel)
        self.onClose = onClose
    }

    private var stageSuggestions: [String] {
        switch viewModel.currentStage {
        case .audit:
            return [
                "Can I rearrange my room now?",
                "What else can I do here?"
            ]
        case .rearrangement:
            return [
                "How do I add or swap furniture?",
                "Where should I place my bed?",
                "What clearance do I need?"
            ]
        case .illumination:
            return [
                "Tips for window lighting",
                "How do I balance ambient & task light?",
                "Where should I add lamps?"
            ]
        case .harmony:
            return [
                "How did my room flow improve?",
                "What should I check in AR?"
            ]
        }
    }

    private var canSend: Bool {
        !viewModel.inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isThinking
    }

    private func closeDrawer() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    public var body: some View {
        ZStack {
            // Dimmed backdrop over the 3D room (tap outside to close)
            Color.black.opacity(0.38)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    closeDrawer()
                }

            VStack {
                Spacer()

                // Main 3D Cream Chat Card
                VStack(alignment: .leading, spacing: 14) {
                    // Header / Conversation Area
                    if viewModel.chatHistory.isEmpty && !viewModel.isThinking {
                        Text("Hey! What can I help you with?")
                            .font(.custom("Cleanow", size: 24, relativeTo: .title3))
                            .foregroundStyle(Color.alcoveText)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(viewModel.chatHistory) { entry in
                                        chatBubble(
                                            isUser: entry.isUser,
                                            text: entry.text,
                                            modelBadge: entry.modelBadge
                                        )
                                        .id(entry.id)
                                    }

                                    if viewModel.isThinking {
                                        HStack(spacing: 8) {
                                            ProgressView()
                                                .tint(Color.alcoveBorder)
                                                .scaleEffect(0.85)
                                            Text("Otter is thinking...")
                                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                                                .foregroundStyle(Color.alcoveMutedInk)
                                        }
                                        .padding(.vertical, 4)
                                        .id("thinkingIndicator")
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: keyboardHeight > 0 ? 110 : 156)
                            .onChange(of: viewModel.chatHistory.count) {
                                if let lastID = viewModel.chatHistory.last?.id {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        proxy.scrollTo(lastID, anchor: .bottom)
                                    }
                                }
                            }
                            .onChange(of: viewModel.isThinking) {
                                if viewModel.isThinking {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        proxy.scrollTo("thinkingIndicator", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }

                    // 3D Peach Suggestion Chips (Cleanow font + inner highlight/lip)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(stageSuggestions, id: \.self) { query in
                                suggestionChip(query)
                            }
                        }
                    }

                    // 3D Rounded Input Box with Bottom-Right Paperplane Button
                    ZStack(alignment: .bottomTrailing) {
                        TextField("Type your thoughts here...", text: $viewModel.inputPrompt, axis: .vertical)
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(Color.alcoveText)
                            .lineLimit(2...4)
                            .padding(.leading, 20)
                            .padding(.trailing, 58)
                            .padding(.top, 16)
                            .padding(.bottom, 34)
                            .frame(maxWidth: .infinity, minHeight: keyboardHeight > 0 ? 78 : 108, alignment: .topLeading)
                            .onSubmit {
                                viewModel.sendMessage()
                            }

                        Button {
                            viewModel.sendMessage()
                        } label: {
                            Image(systemName: "paperplane")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(canSend ? Color.alcoveText : Color.alcoveSecondaryShadow)
                                .frame(width: 38, height: 38)
                                .background(
                                    canSend ? Color.alcoveBadgeGold : Color.alcoveBackground,
                                    in: Circle()
                                )
                                .overlay(
                                    Circle()
                                        .stroke(canSend ? Color.alcoveBorder : Color.alcoveSecondaryShadow, lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .disabled(!canSend)
                        .accessibilityLabel("Send message")
                        .padding(.trailing, 10)
                        .padding(.bottom, 10)
                    }
                    .background {
                        AlcoveTactileCardBackground(
                            cornerRadius: 22,
                            borderWidth: 3,
                            topHighlightColor: .alcoveBackground,
                            bottomLipColor: .alcoveSecondaryShadow,
                            faceColor: .alcoveBackground,
                            topBevel: 0,
                            bottomBevel: 4.5
                        )
                    }

                }
                .padding(.horizontal, 44)
                .padding(.top, 38)
                .padding(.bottom, 26)
                .frame(maxWidth: 980, alignment: .leading)
                .background {
                    AlcoveTactileCardBackground(
                        cornerRadius: 24,
                        borderWidth: 3,
                        topHighlightColor: .alcoveSurfaceElevated,
                        bottomLipColor: .alcoveSecondaryShadow,
                        faceColor: .alcoveSurfaceElevated,
                        topBevel: 0,
                        bottomBevel: 4
                    )
                }
                // Background applied after card fill renders Otter BEHIND both card and name pill
                .background(alignment: .topLeading) {
                    MascotFigureView(emotion: viewModel.isThinking ? .thinking : .happy, showsTablet: true)
                        .offset(x: -4, y: -196)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    OtterNamePill()
                        .offset(x: 44, y: -22)
                        .allowsHitTesting(false)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, max(24, keyboardHeight + 16))
                .safeAreaPadding(.bottom)
                .animation(.easeOut(duration: 0.25), value: keyboardHeight)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let screenHeight = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.screen.bounds.height ?? frame.maxY
            let overlap = max(0, screenHeight - frame.minY)
            keyboardHeight = overlap
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    private func chatBubble(isUser: Bool, text: String, modelBadge: String? = nil) -> some View {
        HStack {
            if isUser { Spacer(minLength: 48) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 3) {
                if let modelBadge, !isUser {
                    Text(modelBadge)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(Color.alcoveMutedInk)
                        .padding(.horizontal, 4)
                }

                let bubbleShape = RoundedRectangle(cornerRadius: 14, style: .continuous)
                Text(text)
                    .font(.system(.subheadline, design: .rounded, weight: isUser ? .semibold : .bold))
                    .foregroundStyle(Color.alcoveText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        bubbleShape
                            .fill(isUser ? Color.alcoveBadgeGold : Color.alcoveSurface)
                    )
                    .overlay(
                        bubbleShape
                            .stroke(Color.alcoveBorder.opacity(isUser ? 0.8 : 0.28), lineWidth: 1.5)
                    )
            }
            if !isUser { Spacer(minLength: 48) }
        }
    }

    private func suggestionChip(_ query: String) -> some View {
        Button {
            viewModel.selectSuggestion(query)
        } label: {
            Text(query)
                .font(.custom("Cleanow", size: 20, relativeTo: .headline))
                .foregroundStyle(Color.alcoveText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 26)
                .frame(height: 46)
                .background {
                    ZStack {
                        Capsule()
                            .fill(Color.alcoveBorder)

                        ZStack {
                            VStack(spacing: 0) {
                                Color.alcoveChipHighlight
                                Color.alcoveChipShadow
                            }

                            Capsule()
                                .fill(Color.alcoveChipFill)
                                .padding(.top, 3)
                                .padding(.bottom, 5)
                        }
                        .clipShape(Capsule())
                        .padding(3)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
