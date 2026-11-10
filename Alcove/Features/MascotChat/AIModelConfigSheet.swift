import SwiftUI

/// Settings sheet to configure Claude / GPT-4o API keys and inspect live spatial context
public struct AIModelConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    let room: Room
    let currentStage: StageType

    @State private var selectedProvider: LLMProvider
    @State private var apiKeyInput: String
    @State private var showingSavedToast: Bool = false

    private let serializer = RoomSpatialContextSerializer()

    public init(room: Room, currentStage: StageType) {
        self.room = room
        self.currentStage = currentStage
        self._selectedProvider = State(initialValue: LLMMascotAIService.shared.provider)
        self._apiKeyInput = State(initialValue: LLMMascotAIService.shared.apiKey)
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Provider & Credentials
                Section("AI Companion Engine") {
                    Picker("Model Provider", selection: $selectedProvider) {
                        ForEach(LLMProvider.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedProvider) { _, newValue in
                        LLMMascotAIService.shared.provider = newValue
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(providerKeyLabel)
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        SecureField(providerPlaceholder, text: $apiKeyInput)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)

                        if selectedProvider == .gemini {
                            Text("💡 Tip: Get a free key with 1,500 free requests/day (no credit card needed) at aistudio.google.com")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }

                        HStack {
                            Button("Save API Key") {
                                LLMMascotAIService.shared.apiKey = apiKeyInput
                                showingSavedToast = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.indigo)

                            if !apiKeyInput.isEmpty {
                                Button("Clear") {
                                    apiKeyInput = ""
                                    LLMMascotAIService.shared.apiKey = ""
                                }
                                .tint(.red)
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // Connection status
                    HStack {
                        Image(systemName: LLMMascotAIService.shared.apiKey.isEmpty ? "bolt.slash.fill" : "checkmark.seal.fill")
                            .foregroundStyle(LLMMascotAIService.shared.apiKey.isEmpty ? .orange : .green)
                        Text(LLMMascotAIService.shared.apiKey.isEmpty ? "Offline Heuristics (Panero & Zelnik + Ramstedt active)" : "Connected to \(selectedProvider.rawValue)")
                            .font(.caption)
                    }
                }

                // Section 2: Reference Books Active
                Section("Active Design Knowledge Base") {
                    Label("Panero & Zelnik: 76.2cm min circulation, 91.4cm comfort", systemImage: "ruler")
                        .font(.caption)
                    Label("Karlen & Benya: Ambient, Task & Accent 3-layer lighting", systemImage: "lightbulb.fill")
                        .font(.caption)
                    Label("Frida Ramstedt: 5–7 light sources, visual balance & focal points", systemImage: "book.pages.fill")
                        .font(.caption)
                }

                // Section 3: Live Spatial Context Inspector
                Section("Live Spatial Context Given to AI") {
                    Text("This is the exact mathematical data the AI reads when answering your design questions:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal) {
                        Text(serializer.serialize(room: room, stage: currentStage))
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("AI Model Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .overlay(alignment: .bottom) {
                if showingSavedToast {
                    Text("Settings Saved Successfully")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.black.opacity(0.8)))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                showingSavedToast = false
                            }
                        }
                }
            }
        }
    }

    private var providerKeyLabel: String {
        switch selectedProvider {
        case .gemini: return "Google Gemini API Key (Free Tier)"
        case .claude: return "Anthropic Claude API Key"
        case .openai: return "OpenAI API Key"
        }
    }

    private var providerPlaceholder: String {
        switch selectedProvider {
        case .gemini: return "Enter Gemini API Key..."
        case .claude: return "Enter Claude API Key..."
        case .openai: return "Enter OpenAI API Key..."
        }
    }
}

