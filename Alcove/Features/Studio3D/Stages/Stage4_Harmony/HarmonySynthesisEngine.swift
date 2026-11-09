import Foundation

/// Pure domain engine calculating objective Before/After synthesis metrics for Stage 4 Harmony Reveal.
public struct HarmonySynthesisEngine: Sendable {

    private let illuminationEngine: IlluminationSimulationEngine

    public init(illuminationEngine: IlluminationSimulationEngine = IlluminationSimulationEngine()) {
        self.illuminationEngine = illuminationEngine
    }

    /// Evaluates and compares the baseline scan against the working layout.
    public func synthesizeHarmony(room: Room, daylightHour: Double = 12.0) -> HarmonyComparisonMetrics {
        let baselineItems = (room.baselineLayout?.furnitures ?? []).filter { !$0.isArchived }
        let workingItems = (room.workingLayout?.furnitures ?? []).filter { !$0.isArchived }
        let archivedCount = (room.workingLayout?.furnitures ?? []).filter { $0.isArchived }.count

        let roomArea = max(1.0, room.dimensionsWidth * room.dimensionsLength)

        // 1. Calculate bottlenecks in baseline vs working
        let baselineBottlenecks = calculateClearanceBottlenecks(
            items: baselineItems,
            roomWidth: room.dimensionsWidth,
            roomLength: room.dimensionsLength
        )
        let workingBottlenecks = calculateClearanceBottlenecks(
            items: workingItems,
            roomWidth: room.dimensionsWidth,
            roomLength: room.dimensionsLength
        )

        // Improvement percentage in bottlenecks
        let clearanceImprovement: Int
        if baselineBottlenecks > 0 {
            let reduction = Double(baselineBottlenecks - workingBottlenecks)
            clearanceImprovement = max(0, Int((reduction / Double(baselineBottlenecks)) * 100.0))
        } else {
            clearanceImprovement = workingBottlenecks == 0 ? 100 : 0
        }

        // 2. Floor utilization percentage
        let baselineFootprint = baselineItems.reduce(0.0) { $0 + ($1.width * $1.length) }
        let workingFootprint = workingItems.reduce(0.0) { $0 + ($1.width * $1.length) }
        let baselineUtil = Int(min(100.0, (baselineFootprint / roomArea) * 100.0))
        let workingUtil = Int(min(100.0, (workingFootprint / roomArea) * 100.0))

        // 3. Illumination calculation
        let workingFixtures = room.workingLayout?.lightFixtures ?? []
        let illumReport = illuminationEngine.evaluateIllumination(
            fixtures: workingFixtures,
            roomWidth: room.dimensionsWidth,
            roomLength: room.dimensionsLength,
            furnitures: workingItems,
            hourOfDay: daylightHour
        )
        let illumScore = illumReport.balanceScore

        // 4. Overall Harmony synthesis score (0 - 100)
        // Clearance (40 pts) + Illumination (30 pts) + Space Utilization (30 pts)
        let clearancePts = max(0, 40 - (workingBottlenecks * 10))
        let illumPts = Int((Double(illumScore) / 100.0) * 30.0)
        let spacePts = (workingUtil >= 20 && workingUtil <= 55) ? 30 : 20
        let overallScore = min(100, max(0, clearancePts + illumPts + spacePts))

        // 5. Verdict text
        let verdict: String
        if overallScore >= 85 {
            verdict = "Exceptional harmony! Circulation flows effortlessly and functional zones are thoughtfully balanced."
        } else if overallScore >= 70 {
            verdict = "Well-balanced layout! Significant improvement in walkway clearances and natural light access."
        } else {
            verdict = "Promising progress. Review clearance spacing between major furniture pieces to elevate flow."
        }

        return HarmonyComparisonMetrics(
            baselineBottlenecksCount: baselineBottlenecks,
            workingBottlenecksCount: workingBottlenecks,
            clearanceImprovementPercentage: clearanceImprovement,
            baselineFloorUtilizationPercentage: baselineUtil,
            workingFloorUtilizationPercentage: workingUtil,
            archivedItemsCount: archivedCount,
            activeItemsCount: workingItems.count,
            illuminationScore: illumScore,
            overallHarmonyScore: overallScore,
            summaryVerdict: verdict
        )
    }

    private func calculateClearanceBottlenecks(
        items: [Furniture],
        roomWidth: Double,
        roomLength: Double
    ) -> Int {
        var count = 0
        guard items.count > 1 else { return 0 }

        for i in 0..<items.count {
            for j in (i + 1)..<items.count {
                let a = items[i]
                let b = items[j]

                let dx = a.positionX - b.positionX
                let dz = a.positionZ - b.positionZ
                let dist = sqrt(dx * dx + dz * dz)

                let requiredClearance = (a.width + a.length + b.width + b.length) / 4.0 + 0.35
                if dist < requiredClearance {
                    count += 1
                }
            }
        }
        return count
    }
}
