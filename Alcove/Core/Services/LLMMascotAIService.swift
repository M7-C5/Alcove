import Foundation

/// Active LLM provider selection
public enum LLMProvider: String, CaseIterable, Codable, Sendable {
    case gemini = "Google Gemini"
}

/// Production AI service that connects to Google Gemini with offline fallback
@MainActor
public final class LLMMascotAIService: MascotAIServiceProtocol {
    private let fallbackService = MockMascotAIService()
    private let contextSerializer = RoomSpatialContextSerializer()
    private let factVerifier = SpatialFactVerifier()

    public static let shared = LLMMascotAIService()

    /// Tracks whether cloud quota has been exhausted to seamlessly toggle guardrail UI badges
    public private(set) var isQuotaExhausted: Bool = false

    public var provider: LLMProvider {
        get {
            let saved = UserDefaults.standard.string(forKey: "alcove_llm_provider") ?? LLMProvider.gemini.rawValue
            return LLMProvider(rawValue: saved) ?? .gemini
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "alcove_llm_provider")
        }
    }

    /// Optional: In-code developer key override (kept empty by default to prevent secret leaks)
    public static var hardcodedDeveloperKey: String = ""

    /// When true, skips reading local file secrets (useful for deterministic offline tests)
    public static var bypassFileSecretLoading: Bool = false

    /// Multi-key pool: Parses all available keys from gitignored secret files, environment, or UserDefaults
    /// Supports comma or newline separation for automatic multi-account failover!
    public var apiKeys: [String] {
        var rawSources: [String] = []

        if !Self.hardcodedDeveloperKey.isEmpty {
            rawSources.append(Self.hardcodedDeveloperKey)
        }
        if !Self.bypassFileSecretLoading {
            if let secretURL = Bundle.main.url(forResource: "developer", withExtension: "secret"),
               let content = try? String(contentsOf: secretURL, encoding: .utf8) {
                rawSources.append(content)
            }
            // Direct project path fallback when running in Xcode / local simulator
            let fileURL = URL(fileURLWithPath: #filePath)
            let subfolderSecret = fileURL
                .deletingLastPathComponent() // Services
                .deletingLastPathComponent() // Core
                .deletingLastPathComponent() // Alcove
                .appendingPathComponent("developer.secret").path
            let repoRootSecret = fileURL
                .deletingLastPathComponent() // Services
                .deletingLastPathComponent() // Core
                .deletingLastPathComponent() // Alcove
                .deletingLastPathComponent() // repo root
                .appendingPathComponent("developer.secret").path

            for path in [subfolderSecret, repoRootSecret] {
                if let content = try? String(contentsOfFile: path, encoding: .utf8) {
                    rawSources.append(content)
                }
            }
        }

        if let envKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !envKey.isEmpty {
            rawSources.append(envKey)
        }
        if let userKey = UserDefaults.standard.string(forKey: "alcove_llm_api_key"), !userKey.isEmpty {
            rawSources.append(userKey)
        }

        var keys: [String] = []
        for raw in rawSources {
            let split = raw.components(separatedBy: CharacterSet.newlines.union(CharacterSet(charactersIn: ",")))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            for key in split {
                if !keys.contains(key) {
                    keys.append(key)
                }
            }
        }
        return keys
    }

    public var apiKey: String {
        get {
            apiKeys.first ?? ""
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "alcove_llm_api_key")
        }
    }

    public init() {}

    public func stageGreeting(stage: StageType, roomName: String) -> String {
        fallbackService.stageGreeting(stage: stage, roomName: roomName)
    }

    public func microReact(
        event: FurnitureMoveEvent,
        roomDimensions: (width: Double, length: Double),
        allFurnitures: [Furniture]
    ) -> MicroReaction? {
        fallbackService.microReact(
            event: event,
            roomDimensions: roomDimensions,
            allFurnitures: allFurnitures
        )
    }

    public func daylightMicroReact(
        hour: Double,
        room: Room
    ) -> MicroReaction? {
        fallbackService.daylightMicroReact(hour: hour, room: room)
    }

    public func evaluateStage(
        stage: StageType,
        room: Room
    ) async -> StageEvaluationResult {
        // Fallback local spatial baseline evaluation
        let baseline = await fallbackService.evaluateStage(stage: stage, room: room)

        guard !apiKey.isEmpty else {
            return baseline
        }

        // Generate dynamic LLM critique citing the books
        do {
            let spatialContext = contextSerializer.serialize(room: room, stage: stage)
            let evaluationPrompt: String
            if stage == .audit {
                evaluationPrompt = """
                Perform an observational spatial intake diagnosis for Stage 1: The Audit for "\(room.name)".
                CRITICAL CURRICULUM & VOICE RULES FOR STAGE 1 (THE AUDIT):
                - The Audit is strictly an observational diagnosis of the room's CURRENT SITUATION and layout as scanned.
                - DO NOT mention, score, or criticize artificial lighting, lamps, or fixtures! DO NOT tell the user to "add more lights" or "add lamps" (artificial lighting belongs strictly to Stage 3: The Illumination).
                - There is NO score penalty in Stage 1. Return "score": 100 and "canAdvance": true.
                - Location accuracy: Look at each piece's `Placement` tag. NEVER say a piece is "floating" or "in the center" when it is anchored against a wall or corner!
                - Mascot voice: warm, insightful interior design companion. Avoid awkward real-estate brochure fluff (NEVER use "floating comfortably", "lovely daylight", or "enjoys open breathing room in the center"). Keep dialogue under 35 words.

                EDUCATIONAL DESIGN KNOWLEDGE RULES FOR RECOMMENDATIONS ("Design Tips"):
                Every recommendation MUST be an educational, actionable design tip teaching an interior design principle tailored to this room's real layout:
                1. Daylight & Glare: Explain how window orientation benefits the work area (e.g. positioning the Work Desk perpendicular to the window illuminates the desk while preventing computer screen glare).
                2. Bed Anchoring & Zoning: Explain how anchoring the Queen Bed against perimeter walls preserves open central floor area and creates a clear, quiet sleeping zone.
                3. Circulation & Clearances: Note the primary walkway from the entrance (standard 76–90 cm) and highlight any snug paths to watch out for in Stage 2.
                4. Chair Egress: Emphasize maintaining at least 75 cm behind the desk for chair slide-out.
                DO NOT write passive empty observations (NEVER say "Notice how the desk sits by daylight" or "Bed enjoys open room"). Explain WHY the arrangement matters from a design perspective!

                Return ONLY a raw JSON object (no markdown quotes, no explanation) with this exact schema:
                {
                  "canAdvance": true,
                  "score": 100,
                  "title": "Short punchy diagnosis title (2-4 words, e.g. 'Room Baseline Diagnosed')",
                  "dialogue": "1-2 short, punchy sentences diagnosing the room's current flow and natural light, setting up Stage 2 rearranging (under 35 words).",
                  "recommendations": ["Actionable design tip on desk daylight/glare or chair clearance (1 sentence)", "Actionable design tip on bed anchoring, zoning, or pathway flow (1 sentence)"],
                  "praise": ["Baseline room scan captured", "Room footprint mapped"]
                }
                """
            } else if stage == .rearrangement {
                evaluationPrompt = """
                Perform a formal stage completion evaluation for Stage 2: The Rearrangement for "\(room.name)".
                CRITICAL CURRICULUM & ORIENTATION RULES:
                - Voice: Casual, grounded interior designer companion. Friendly and encouraging.
                - Location accuracy: Look at each piece's `Placement` tag. NEVER say a piece is "floating" or "in the center" when it is anchored against a wall or corner!
                - Pieces marked 'Facing: INWARD into the room (toward center)' are ALREADY properly facing the room. NEVER tell the user to rotate them to face the room.

                EDUCATIONAL DESIGN KNOWLEDGE RULES FOR RECOMMENDATIONS ("Design Tips"):
                Provide 2 concrete, educational design tips grounded in this room's layout:
                1. Clearance & Walkways: Recommend maintaining at least 76 cm along main walking lanes to keep transit effortless.
                2. Chair Pushback: Remind to keep 75 cm behind the desk for chair pushback without bumping into walls or walkways.
                3. Zoning & Flow: Highlight grouping resting and working zones to maintain visual order in a studio.

                Return ONLY a raw JSON object with this exact schema:
                {
                  "canAdvance": true/false,
                  "score": 0-100 integer,
                  "title": "Short punchy evaluation title (2-4 words, e.g. 'Layout & Flow Evaluated')",
                  "dialogue": "1-2 short, punchy sentences evaluating the layout's walking flow and functional zones (under 35 words).",
                  "recommendations": ["Specific tip on clearance or chair pushback naming real furniture (1 sentence)", "Specific tip on zoning or perimeter anchoring (1 sentence)"],
                  "praise": ["What worked well 1", "What worked well 2"]
                }
                """
            } else if stage == .illumination {
                evaluationPrompt = """
                Perform a formal stage completion evaluation for Stage 3: The Illumination for "\(room.name)".
                EDUCATIONAL DESIGN KNOWLEDGE RULES FOR RECOMMENDATIONS ("Design Tips"):
                Provide 2 concrete, educational lighting design tips based on Karlen & Benya / Frida Ramstedt principles:
                1. Task Lighting: Emphasize focused task illumination at the desk or bedside to reduce eye strain and screen glare.
                2. Layer Balance: Recommend combining overhead ambient fill with 2–3 localized lamps at varied heights for warmth and dimensional depth without harsh shadows.

                Return ONLY a raw JSON object with this exact schema:
                {
                  "canAdvance": true/false,
                  "score": 0-100 integer,
                  "title": "Short punchy evaluation title (2-4 words, e.g. 'Lighting Layers Balanced')",
                  "dialogue": "1-2 short, punchy sentences evaluating the room's lighting balance and daylight distribution (under 35 words).",
                  "recommendations": ["Educational tip on task lighting or reducing screen glare (1 sentence)", "Educational tip on ambient/accent lighting layers (1 sentence)"],
                  "praise": ["What worked well 1", "What worked well 2"]
                }
                """
            } else {
                evaluationPrompt = """
                Perform a formal stage completion evaluation for Stage 4: The Harmony Reveal for "\(room.name)".
                EDUCATIONAL DESIGN KNOWLEDGE RULES FOR RECOMMENDATIONS ("Design Tips"):
                Provide 2 celebratory, practical synthesis tips:
                1. Flow & Clearance: Celebrate the percentage improvement in open circulation and elimination of bottlenecks.
                2. Real-World AR Walkthrough: Encourage launching the 1:1 Life-Size AR Walkthrough to experience the newly designed clearances in physical space.

                Return ONLY a raw JSON object with this exact schema:
                {
                  "canAdvance": true/false,
                  "score": 0-100 integer,
                  "title": "Short punchy evaluation title (2-4 words, e.g. 'Spatial Harmony Achieved')",
                  "dialogue": "1-2 short, punchy sentences celebrating the spatial transformation and flow improvement (under 35 words).",
                  "recommendations": ["Insight on improved walking clearance and zoning (1 sentence)", "Suggestion to test walkways with the 1:1 AR Walkthrough (1 sentence)"],
                  "praise": ["What worked well 1", "What worked well 2"]
                }
                """
            }

            let rawJson = try await callGeminiAPI(question: evaluationPrompt, context: spatialContext)

            // Clean potential markdown fencing ```json ... ```
            let cleaned = rawJson
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let data = cleaned.data(using: .utf8),
               let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let canAdvance = parsed["canAdvance"] as? Bool ?? baseline.canAdvance
                let score = parsed["score"] as? Int ?? baseline.score
                let title = parsed["title"] as? String ?? baseline.title
                let rawDialogue = parsed["dialogue"] as? String ?? baseline.dialogue
                let rawRecs = parsed["recommendations"] as? [String] ?? baseline.recommendations
                let praise = parsed["praise"] as? [String] ?? baseline.praise

                // Enforce deterministic spatial truth through the fact verifier pipeline
                let verified = factVerifier.verifyAndSanitize(
                    dialogue: rawDialogue,
                    recommendations: rawRecs,
                    room: room,
                    stage: stage,
                    baseline: baseline
                )

                return StageEvaluationResult(
                    canAdvance: canAdvance && baseline.canAdvance, // Safety: cannot advance if critical physical collision exists
                    score: score,
                    title: title,
                    dialogue: verified.dialogue,
                    bottlenecks: baseline.bottlenecks,
                    recommendations: verified.recommendations,
                    praise: praise
                )
            }
        } catch {
            // Graceful fallback to deterministic local baseline
        }

        return baseline
    }

    public func askMascot(
        question: String,
        currentStage: StageType,
        room: Room
    ) async -> String {
        // Guardrail 1: Anti-Prompt Injection Pre-Filter
        let lower = question.lowercased()
        let injectionPatterns = [
            "ignore previous instructions",
            "ignore all instructions",
            "ignore your rules",
            "bypass guardrails",
            "dan mode",
            "jailbreak",
            "system prompt",
            "reveal prompt"
        ]
        if injectionPatterns.contains(where: { lower.contains($0) }) {
            return "Haha, nice try! But I'm strictly your interior design companion in Alcove. Let's focus on making your room look amazing—what piece should we rearrange next?"
        }

        guard !apiKey.isEmpty else {
            print("📖 [Alcove AI] No API key set. Using Local Built-in Engine. Question: '\(question)'")
            // Intelligent local response grounded in Panero & Zelnik + Ramstedt
            let baseAnswer = await fallbackService.askMascot(question: question, currentStage: currentStage, room: room)
            
            // Check if room has active bottlenecks
            let furnitures = room.workingLayout?.furnitures.filter { !$0.isArchived } ?? []
            var bottleneckNote = ""
            for i in 0..<furnitures.count {
                for j in (i + 1)..<furnitures.count {
                    let a = furnitures[i]
                    let b = furnitures[j]
                    let dist = sqrt(pow(a.positionX - b.positionX, 2) + pow(a.positionZ - b.positionZ, 2))
                    let radiusSum = (a.width + a.length) / 4.0 + (b.width + b.length) / 4.0
                    let clearance = max(0.0, dist - radiusSum)
                    let isCompanionPair = AnthropometricStandards.isFunctionalCompanionPair(a: a, b: b)
                    if clearance < AnthropometricStandards.minimumCirculation && !isCompanionPair {
                        bottleneckNote = " Also, in \(room.name), \(a.name) and \(b.name) look a little too tight for walking comfortably. Try nudging one to open up the walkway!"
                        break
                    }
                }
                if !bottleneckNote.isEmpty { break }
            }

            return baseAnswer + bottleneckNote
        }

        print("🚀 [Alcove AI] Sending request to \(provider.rawValue)... Question: '\(question)'")

        // Cloud LLM invocation with live spatial context
        do {
            let spatialContext = contextSerializer.serialize(room: room, stage: currentStage)
            let answer = try await callGeminiAPI(question: question, context: spatialContext)
            self.isQuotaExhausted = false

            // Validate against spatial hallucinations via deterministic SpatialFactVerifier
            let fallbackAnswer = await fallbackService.askMascot(question: question, currentStage: currentStage, room: room)
            let verifiedAnswer = factVerifier.verifyChatAnswer(
                answer: answer,
                room: room,
                stage: currentStage,
                fallbackAnswer: fallbackAnswer
            )
            return verifiedAnswer
        } catch {
            print("❌ [Alcove AI] Cloud request failed: \(error.localizedDescription). Falling back to local engine.")
            let isQuota = (error as NSError).code == 429 ||
                          error.localizedDescription.localizedCaseInsensitiveContains("quota") ||
                          error.localizedDescription.localizedCaseInsensitiveContains("RESOURCE_EXHAUSTED") ||
                          error.localizedDescription.localizedCaseInsensitiveContains("exhausted")
            self.isQuotaExhausted = isQuota
            let offlineAnswer = await fallbackService.askMascot(question: question, currentStage: currentStage, room: room)
            if isQuota {
                return "\(offlineAnswer)\n\n*(⚡️ Daily cloud quota is resting, so I'm using my built-in design brain right now!)*"
            } else {
                return offlineAnswer
            }
        }
    }

    // MARK: - Google Gemini API Call (Multi-Key Pool & Multi-Model Free Tier)
    private func callGeminiAPI(question: String, context: String) async throws -> String {
        let availableKeys = apiKeys.isEmpty ? (apiKey.isEmpty ? [] : [apiKey]) : apiKeys
        guard !availableKeys.isEmpty else {
            throw NSError(domain: "GeminiAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "No API key configured"])
        }

        let candidateModels = ["gemini-2.5-flash", "gemini-3.5-flash-lite"]
        var lastError: Error?

        for key in availableKeys {
            for model in candidateModels {
                guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)") else {
                    continue
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")

                var generationConfig: [String: Any] = [
                    "maxOutputTokens": 1024,
                    "temperature": 0.3
                ]
                // Disable hidden thinking tokens on Gemini 2.5 to achieve ~97% token savings & 10x faster response!
                if model == "gemini-2.5-flash" {
                    generationConfig["thinkingConfig"] = [
                        "thinkingBudget": 0
                    ]
                }

                let body: [String: Any] = [
                    "system_instruction": [
                        "parts": [
                            ["text": DesignKnowledgeSystemPrompt.prompt]
                        ]
                    ],
                    "contents": [
                        [
                            "role": "user",
                            "parts": [
                                ["text": "\(context)\n\nUser Question: \(question)"]
                            ]
                        ]
                    ],
                    "generationConfig": generationConfig
                ]

                do {
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)
                    let (data, response) = try await URLSession.shared.data(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else { continue }

                    if httpResponse.statusCode == 429 {
                        print("⚠️ [Alcove AI] Model \(model) with key \(key.prefix(6))... quota exceeded (429). Trying next key or model...")
                        lastError = NSError(domain: "GeminiAPI", code: 429, userInfo: [NSLocalizedDescriptionKey: "Quota exceeded for key"])
                        continue
                    }

                    guard (200...299).contains(httpResponse.statusCode) else {
                        let errString = String(data: data, encoding: .utf8) ?? "Unknown server response"
                        lastError = NSError(domain: "GeminiAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errString])
                        continue
                    }

                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let candidates = json["candidates"] as? [[String: Any]],
                       let firstCandidate = candidates.first,
                       let content = firstCandidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let firstPart = parts.first,
                       let text = firstPart["text"] as? String {
                        print("✅ [Alcove AI] Responded successfully using \(model) with key \(key.prefix(6))...!")
                        return text.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                } catch {
                    lastError = error
                }
            }
        }

        throw lastError ?? NSError(domain: "GeminiAPI", code: 429, userInfo: [NSLocalizedDescriptionKey: "All Gemini free models and keys currently exhausted. Please try again in a little while."])
    }
}
