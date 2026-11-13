import Foundation

/// Deterministic validator and sanitizer that enforces strict spatial truth against
/// physical room geometry, eliminating LLM hallucinations before display.
public struct SpatialFactVerifier: Sendable {

    public init() {}

    /// Audits and sanitizes an evaluation result's dialogue and tips against real room layout facts.
    public func verifyAndSanitize(
        dialogue: String,
        recommendations: [String],
        room: Room,
        stage: StageType,
        baseline: StageEvaluationResult
    ) -> (dialogue: String, recommendations: [String]) {
        let furnitures = (room.workingLayout?.furnitures ?? []).filter { !$0.isArchived }
        let halfW = room.dimensionsWidth / 2.0
        let halfL = room.dimensionsLength / 2.0

        // 1. Sanitize dialogue
        var cleanDialogue = dialogue.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove awkward/bizarre marketing jargon
        cleanDialogue = cleanDialogue
            .replacingOccurrences(of: "floating comfortably", with: "anchored neatly against the wall", options: .caseInsensitive)
            .replacingOccurrences(of: "floating", with: "placed", options: .caseInsensitive)
            .replacingOccurrences(of: "lovely daylight", with: "natural daylight", options: .caseInsensitive)

        // Check for false "in the center" or "floating" claims when items are wall-bound
        for f in furnitures {
            let isWallBound = isFurnitureNearWall(f, halfW: halfW, halfL: halfL)
            if isWallBound {
                // If text claims this wall-bound item is in the center, correct it
                if cleanDialogue.localizedCaseInsensitiveContains(f.name) &&
                   (cleanDialogue.localizedCaseInsensitiveContains("center") || cleanDialogue.localizedCaseInsensitiveContains("middle") || cleanDialogue.localizedCaseInsensitiveContains("floating")) {
                    cleanDialogue = cleanDialogue
                        .replacingOccurrences(of: "floating comfortably", with: "anchored neatly against the wall", options: .caseInsensitive)
                        .replacingOccurrences(of: "floating", with: "anchored", options: .caseInsensitive)
                        .replacingOccurrences(of: "in the center of the room", with: "along the wall", options: .caseInsensitive)
                        .replacingOccurrences(of: "in the center", with: "along the wall", options: .caseInsensitive)
                        .replacingOccurrences(of: "in the middle", with: "along the wall", options: .caseInsensitive)
                        .replacingOccurrences(of: "centered", with: "wall-anchored", options: .caseInsensitive)
                }
            }
        }

        // Circuit breaker: if dialogue contradicts basic room reality or mentions phantom pieces, use verified baseline
        let hasPhantom = containsPhantomFurniture(text: cleanDialogue, activeFurnitures: furnitures)
        let hasContradictoryFloatingOrCenter = furnitures.contains { f in
            isFurnitureNearWall(f, halfW: halfW, halfL: halfL) &&
            cleanDialogue.localizedCaseInsensitiveContains(f.name) &&
            (cleanDialogue.localizedCaseInsensitiveContains("center") || cleanDialogue.localizedCaseInsensitiveContains("floating"))
        }
        let hasPrematureLightingInAudit = stage == .audit && (
            cleanDialogue.localizedCaseInsensitiveContains("spotlight") ||
            cleanDialogue.localizedCaseInsensitiveContains("add light") ||
            cleanDialogue.localizedCaseInsensitiveContains("add lamp") ||
            cleanDialogue.localizedCaseInsensitiveContains("artificial light")
        )

        if hasPhantom || hasContradictoryFloatingOrCenter || hasPrematureLightingInAudit {
            cleanDialogue = baseline.dialogue
        }

        // 2. Filter and sanitize recommendations
        var verifiedRecs: [String] = []

        for rec in recommendations {
            let lower = rec.lowercased()

            // Filter A: Phantom furniture not in the room
            if containsPhantomFurniture(text: rec, activeFurnitures: furnitures) {
                continue
            }

            // Filter B: False "face the room" advice for pieces already facing inward
            if lower.contains("face") && (lower.contains("room") || lower.contains("inward") || lower.contains("center") || lower.contains("door")) {
                let isAlreadyFacing = furnitures.contains { f in
                    guard isTargetedByText(furniture: f, text: lower) else { return false }
                    return isFurnitureFacingInward(f)
                }
                if isAlreadyFacing {
                    continue
                }
            }

            // Filter C: False "in the center" or "floating" claims for pieces near walls
            if (lower.contains("center") || lower.contains("middle") || lower.contains("floating")) &&
               (lower.contains("bed") || lower.contains("desk") || lower.contains("shelf") || lower.contains("wardrobe")) {
                let isWallPiece = furnitures.contains { f in
                    guard isTargetedByText(furniture: f, text: lower) else { return false }
                    return isFurnitureNearWall(f, halfW: halfW, halfL: halfL)
                }
                if isWallPiece {
                    continue
                }
            }

            // Filter D: Premature artificial lighting tips in Stage 1 (The Audit)
            if stage == .audit {
                let mentionsLightingAdvice = lower.contains("spotlight") ||
                                             lower.contains("add light") ||
                                             lower.contains("add lamp") ||
                                             lower.contains("install") ||
                                             lower.contains("fixture") ||
                                             lower.contains("more light") ||
                                             lower.contains("artificial light")
                if mentionsLightingAdvice {
                    continue
                }
            }

            // Filter E: Generic textbook number reciting
            if lower.contains("ensure minimum 76.2") || lower.contains("aim for 91.4") || lower.contains("66-99cm for bed-making") {
                continue
            }

            // Clean awkward phrasing in tips
            let cleanedTip = rec
                .replacingOccurrences(of: "enjoys plenty of open breathing room in the center", with: "has clear, comfortable clearance along the wall", options: .caseInsensitive)
                .replacingOccurrences(of: "enjoys open breathing room in the center", with: "has clear clearance along the wall", options: .caseInsensitive)
                .replacingOccurrences(of: "in the center", with: "along the wall", options: .caseInsensitive)

            verifiedRecs.append(cleanedTip)
        }

        // If suggestions were filtered out due to hallucinations, backfill from verified baseline recommendations
        if verifiedRecs.count < 2 {
            for baseRec in baseline.recommendations {
                if verifiedRecs.count >= 2 { break }
                if !verifiedRecs.contains(baseRec) {
                    verifiedRecs.append(baseRec)
                }
            }
        }

        return (cleanDialogue, verifiedRecs)
    }

    /// Verifies and sanitizes open Mascot conversation answers against real room geometry.
    public func verifyChatAnswer(
        answer: String,
        room: Room,
        stage: StageType,
        fallbackAnswer: String
    ) -> String {
        let furnitures = (room.workingLayout?.furnitures ?? []).filter { !$0.isArchived }
        let halfW = room.dimensionsWidth / 2.0
        let halfL = room.dimensionsLength / 2.0

        // Circuit breaker: Phantom furniture in chat
        if containsPhantomFurniture(text: answer, activeFurnitures: furnitures) {
            return fallbackAnswer
        }

        // Circuit breaker: Claiming a wall-anchored piece is floating or in the center
        // Use explicit placement phrases so valid advice like "keep the center of the room open" is allowed.
        let falseCenterPhrases = [
            "is floating",
            "floating in",
            "floating comfortably",
            "is in the center",
            "sits in the center",
            "placed in the center",
            "tucked in the center"
        ]
        let hasFalseCenter = furnitures.contains { f in
            isFurnitureNearWall(f, halfW: halfW, halfL: halfL) &&
            answer.localizedCaseInsensitiveContains(f.name) &&
            falseCenterPhrases.contains { phrase in
                answer.localizedCaseInsensitiveContains(phrase)
            }
        }
        if hasFalseCenter {
            return fallbackAnswer
        }

        // Circuit breaker: Premature artificial lighting in Stage 1
        if stage == .audit {
            let lower = answer.lowercased()
            if lower.contains("add lamp") || lower.contains("add light") || lower.contains("spotlight") || lower.contains("install fixture") {
                return fallbackAnswer
            }
        }

        // Sanitize flowery clichés
        return answer
            .replacingOccurrences(of: "floating comfortably", with: "anchored neatly against the wall", options: .caseInsensitive)
            .replacingOccurrences(of: "lovely daylight", with: "natural daylight", options: .caseInsensitive)
            .replacingOccurrences(of: "enjoys open breathing room in the center", with: "has clear circulation", options: .caseInsensitive)
    }

    // MARK: - Spatial Invariant Checkers

    /// Tests if a piece's outer boundary is within 45 cm of any perimeter wall
    public func isFurnitureNearWall(_ f: Furniture, halfW: Double, halfL: Double) -> Bool {
        let absCos = abs(cos(f.rotationYaw))
        let absSin = abs(sin(f.rotationYaw))
        let extentX = (absCos * f.width + absSin * f.length) / 2.0
        let extentZ = (absSin * f.width + absCos * f.length) / 2.0

        let distToLeft = (f.positionX - extentX) - (-halfW)
        let distToRight = halfW - (f.positionX + extentX)
        let distToBack = (f.positionZ - extentZ) - (-halfL)
        let distToFront = halfL - (f.positionZ + extentZ)

        let minDist = min(distToLeft, distToRight, distToBack, distToFront)
        return minDist < 0.45
    }

    /// Tests if a piece's local front faces toward the room center (dot product > 0.05)
    public func isFurnitureFacingInward(_ f: Furniture) -> Bool {
        let facingX = sin(f.rotationYaw)
        let facingZ = cos(f.rotationYaw)
        let toCenterX = -f.positionX
        let toCenterZ = -f.positionZ
        let dot = facingX * toCenterX + facingZ * toCenterZ
        return dot > 0.05
    }

    /// Checks if text references major furniture types that do NOT exist in the room
    public func containsPhantomFurniture(text: String, activeFurnitures: [Furniture]) -> Bool {
        let lower = text.lowercased()
        let commonFurnitureKeywords = [
            "sofa", "couch", "coffee table", "dining table", "armchair",
            "wardrobe", "bookshelf", "nightstand", "desk", "bed", "dresser",
            "credenza", "tv stand", "television", "console table", "sideboard", "ottoman"
        ]

        for keyword in commonFurnitureKeywords {
            if lower.contains(keyword) {
                let roomHasKeyword = activeFurnitures.contains { f in
                    f.name.localizedCaseInsensitiveContains(keyword)
                }
                if !roomHasKeyword {
                    return true // Hallucinated furniture piece!
                }
            }
        }
        return false
    }

    private func isTargetedByText(furniture: Furniture, text: String) -> Bool {
        let nameMatches = furniture.name.split(separator: " ").contains { word in
            text.localizedCaseInsensitiveContains(String(word))
        }
        return nameMatches || text.localizedCaseInsensitiveContains(furniture.category.rawValue)
    }
}

