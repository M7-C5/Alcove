import SwiftUI

/// Dedicated presentation sheet displaying the Room Harmony Scorecard for Stage 4 (The Harmony Reveal).
/// Presents objective spatial metrics, clearance improvements, floor utilization, lighting balance,
/// and Mascot AI commentary designed specifically for iPad landscape ergonomics.
public struct RoomHarmonyScorecardSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let room: Room
    public let metrics: HarmonyComparisonMetrics
    public let onInteractiveSplitTapped: () -> Void
    public let onStartGuidedTour: () -> Void
    public let onOpenARWalkthrough: () -> Void
    public let onCompleteCurriculum: () -> Void

    public init(
        room: Room,
        metrics: HarmonyComparisonMetrics,
        onInteractiveSplitTapped: @escaping () -> Void,
        onStartGuidedTour: @escaping () -> Void,
        onOpenARWalkthrough: @escaping () -> Void,
        onCompleteCurriculum: @escaping () -> Void
    ) {
        self.room = room
        self.metrics = metrics
        self.onInteractiveSplitTapped = onInteractiveSplitTapped
        self.onStartGuidedTour = onStartGuidedTour
        self.onOpenARWalkthrough = onOpenARWalkthrough
        self.onCompleteCurriculum = onCompleteCurriculum
    }

    private var evaluationStatus: (icon: String, label: String, color: Color) {
        if metrics.overallHarmonyScore >= 85 {
            return ("sparkles", "Exceptional Spatial Harmony", .green)
        } else if metrics.overallHarmonyScore >= 70 {
            return ("checkmark.seal.fill", "Well-Balanced Layout", .indigo)
        } else {
            return ("arrow.up.right.circle.fill", "Solid Flow Improvement", .orange)
        }
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Evaluation Header
                    scorecardHeroSection

                    // 2-Column Metrics Grid for iPad Landscape
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        circulationCard
                        floorUtilizationCard
                        lightingBalanceCard
                        curriculumMilestoneCard
                    }

                    // Bottom Action Ribbon
                    actionControlsRibbon
                }
                .padding(24)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Room Harmony Evaluation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.body.weight(.medium))
                }
            }
        }
    }

    // MARK: - Hero Evaluation Section

    private var scorecardHeroSection: some View {
        HStack(spacing: 28) {
            // Circular Evaluation Status Icon Badge
            ZStack {
                Circle()
                    .fill(evaluationStatus.color.opacity(0.14))
                    .frame(width: 108, height: 108)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [evaluationStatus.color, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 6
                    )
                    .frame(width: 108, height: 108)

                Image(systemName: evaluationStatus.icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(evaluationStatus.color)
            }

            // Room Title & Mascot Verdict
            VStack(alignment: .leading, spacing: 8) {
                Text(evaluationStatus.label)
                    .font(.headline.bold())
                    .foregroundStyle(evaluationStatus.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(evaluationStatus.color.opacity(0.12), in: Capsule())

                Text(room.name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 8) {
                    Text("🦉")
                        .font(.title2)
                    Text(metrics.summaryVerdict)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineSpacing(2)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
        )
    }

    // MARK: - Metric Cards

    private var circulationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Circulation & Clearance", systemImage: "figure.walk")
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text("+\(metrics.clearanceImprovementPercentage)% Flow")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.12), in: Capsule())
            }

            Divider()

            // Bottlenecks Count Comparison
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Baseline Bottlenecks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(metrics.baselineBottlenecksCount) detected")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(metrics.baselineBottlenecksCount > 0 ? .red : .primary)
                }

                Image(systemName: "arrow.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Optimized Bottlenecks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(metrics.workingBottlenecksCount) remaining")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(metrics.workingBottlenecksCount == 0 ? .green : .orange)
                }
            }

            // Tightest Walkway Measurement
            VStack(alignment: .leading, spacing: 4) {
                Text("Narrowest Walkway Clearance")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text("\(Int(metrics.baselineTightestWalkwayMeters * 100)) cm")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("\(Int(metrics.workingTightestWalkwayMeters * 100)) cm")
                        .font(.headline.bold())
                        .foregroundStyle(.green)
                }

                Text("Panero & Zelnik standard: min 76 cm for primary circulation.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var floorUtilizationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Floor Utilization & Density", systemImage: "square.split.diagonal.2x2")
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(metrics.workingFloorUtilizationPercentage)%")
                    .font(.subheadline.bold())
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.indigo.opacity(0.12), in: Capsule())
            }

            Divider()

            // Floor Density Comparison
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Baseline Footprint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(metrics.baselineFloorUtilizationPercentage)% of room")
                        .font(.subheadline.weight(.semibold))
                }

                Image(systemName: "arrow.right")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Working Footprint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(metrics.workingFloorUtilizationPercentage)% of room")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.indigo)
                }
            }

            // Inventory Summary
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Pieces")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(metrics.activeItemsCount) items placed")
                        .font(.subheadline.weight(.semibold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Archived Items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(metrics.archivedItemsCount) in inventory")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(metrics.archivedItemsCount > 0 ? .orange : .secondary)
                }
            }

            Text("Target ratio: 25% – 45% creates breathable spatial balance.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var lightingBalanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Layered Illumination", systemImage: "lightbulb.2")
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text(metrics.illuminationScore >= 70 ? "Balanced" : "Needs Layers")
                    .font(.subheadline.bold())
                    .foregroundStyle(metrics.illuminationScore >= 70 ? .green : .orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((metrics.illuminationScore >= 70 ? Color.green : Color.orange).opacity(0.12), in: Capsule())
            }

            Divider()

            Text("Three-layer lighting standard provides ambient balance, task clarity, and focal warmth.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "sun.max.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text("Daylight Path")
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.yellow.opacity(0.12), in: Capsule())

                HStack(spacing: 6) {
                    Image(systemName: "lamp.desk.fill")
                        .font(.caption)
                        .foregroundStyle(.indigo)
                    Text("Task Lighting")
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.indigo.opacity(0.12), in: Capsule())

                HStack(spacing: 6) {
                    Image(systemName: "light.recessed.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Ambient Glow")
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.12), in: Capsule())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    private var curriculumMilestoneCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Curriculum Mastery", systemImage: "graduationcap")
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text("Stage 4 Complete")
                    .font(.subheadline.bold())
                    .foregroundStyle(.indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.indigo.opacity(0.12), in: Capsule())
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("1. Spatial Audit & Baseline").font(.caption.weight(.medium))
                }
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("2. Anthropometric Rearrangement").font(.caption.weight(.medium))
                }
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("3. Daylight & Multi-layer Illumination").font(.caption.weight(.medium))
                }
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.indigo)
                    Text("4. Harmony Synthesis & Verification").font(.caption.weight(.medium))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }

    // MARK: - Action Controls Ribbon

    private var actionControlsRibbon: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Interactive 3D Split Comparison Button
                Button {
                    dismiss()
                    onInteractiveSplitTapped()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.2.square")
                            .font(.headline)
                        Text("Interactive 3D Split")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Guided 3D Architectural Tour Button
                Button {
                    dismiss()
                    onStartGuidedTour()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "video.badge.waveform.fill")
                            .font(.headline)
                        Text("Start 3D Tour")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.indigo, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // AR Walkthrough Button
                Button {
                    dismiss()
                    onOpenARWalkthrough()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arkit")
                            .font(.headline)
                        Text("AR Walkthrough")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // Finish Curriculum Button
            Button {
                dismiss()
                onCompleteCurriculum()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.headline)
                    Text("Save Room & Finish Curriculum")
                        .font(.headline.bold())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }
}

