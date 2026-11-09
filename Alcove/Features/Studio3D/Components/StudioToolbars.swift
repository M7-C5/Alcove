import SwiftUI

public struct StudioToolbars: View {
    let currentStage: StageType
    let selectedFurniture: Furniture?
    @Binding var daylightHour: Double
    @Binding var beforeAfterSplit: Double
    @Binding var cameraPreset: ViewportPreset
    @Binding var revealMode: HarmonyRevealMode
    let illuminationReport: IlluminationReport?
    let harmonyMetrics: HarmonyComparisonMetrics?
    let onRotate: (Double) -> Void
    let onToggleArchive: () -> Void
    let onAddFixture: (String, LightLayer) -> Void

    public init(
        currentStage: StageType,
        selectedFurniture: Furniture?,
        daylightHour: Binding<Double>,
        beforeAfterSplit: Binding<Double>,
        cameraPreset: Binding<ViewportPreset> = .constant(.topDown),
        revealMode: Binding<HarmonyRevealMode> = .constant(.splitSlider),
        illuminationReport: IlluminationReport? = nil,
        harmonyMetrics: HarmonyComparisonMetrics? = nil,
        onRotate: @escaping (Double) -> Void,
        onToggleArchive: @escaping () -> Void,
        onAddFixture: @escaping (String, LightLayer) -> Void = { _, _ in }
    ) {
        self.currentStage = currentStage
        self.selectedFurniture = selectedFurniture
        self._daylightHour = daylightHour
        self._beforeAfterSplit = beforeAfterSplit
        self._cameraPreset = cameraPreset
        self._revealMode = revealMode
        self.illuminationReport = illuminationReport
        self.harmonyMetrics = harmonyMetrics
        self.onRotate = onRotate
        self.onToggleArchive = onToggleArchive
        self.onAddFixture = onAddFixture
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // Camera Presets Bar (Universal across stages)
            cameraControlsBar

            // Stage-specific controls
            stageSpecificPanel
        }
    }

    private var cameraControlsBar: some View {
        HStack(spacing: 8) {
            ForEach(ViewportPreset.allCases) { preset in
                Button {
                    cameraPreset = preset
                } label: {
                    Image(systemName: preset.icon)
                        .font(.caption2.bold())
                        .padding(6)
                        .background(
                            Circle()
                                .fill(cameraPreset == preset ? Color.indigo : Color.secondary.opacity(0.18))
                        )
                        .foregroundStyle(cameraPreset == preset ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))
    }

    @ViewBuilder
    private var stageSpecificPanel: some View {
        switch currentStage {
        case .audit:
            VStack(alignment: .leading, spacing: 6) {
                Label("Audit Mode", systemImage: "magnifyingglass")
                    .font(.caption.bold())
                Text("Inspect clearance bottlenecks")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))

        case .rearrangement:
            if let item = selectedFurniture {
                VStack(spacing: 12) {
                    Text(item.name)
                        .font(.headline)

                    // Rotation Controls
                    HStack(spacing: 12) {
                        Button {
                            onRotate(-Double.pi / 4)
                        } label: {
                            Image(systemName: "rotate.left.fill")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            onRotate(Double.pi / 4)
                        } label: {
                            Image(systemName: "rotate.right.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(role: .destructive) {
                        onToggleArchive()
                    } label: {
                        Label(item.isArchived ? "Restore" : "Archive to Inventory", systemImage: "archivebox.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
            }

        case .illumination:
            VStack(alignment: .leading, spacing: 10) {
                Label("Daylight Hour: \(String(format: "%.0f:00", daylightHour))", systemImage: "sun.max.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)

                Slider(value: $daylightHour, in: 8.0...20.0, step: 1.0)
                    .tint(.orange)
                    .frame(width: 200)

                Divider()

                if let report = illuminationReport {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Layers Status: \(report.balanceScore)/100")
                            .font(.caption2.bold())
                            .foregroundStyle(report.isPassingScore ? .green : .orange)

                        HStack(spacing: 12) {
                            Label("\(Int(report.ambientLux)) lx", systemImage: "light.recessed.fill")
                                .font(.caption2)
                            Label("\(report.taskZonesCoveredCount)/\(max(1, report.totalTaskZonesCount)) Tasks", systemImage: "lamp.desk.fill")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 8) {
                    Button("+ Ambient") {
                        onAddFixture("Ceiling Light", .ambient)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption2)

                    Button("+ Task Lamp") {
                        onAddFixture("Desk Lamp", .task)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption2)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(.regularMaterial))

        case .harmony:
            VStack(alignment: .leading, spacing: 10) {
                if let metrics = harmonyMetrics {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Harmony Score")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(metrics.overallHarmonyScore)%")
                                .font(.headline.bold())
                                .foregroundStyle(.indigo)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Clearance Flow")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("+\(metrics.clearanceImprovementPercentage)%")
                                .font(.headline.bold())
                                .foregroundStyle(.green)
                        }
                    }
                    Divider()
                }

                // Harmony Reveal Mode Selector
                Picker("Reveal Mode", selection: $revealMode) {
                    ForEach(HarmonyRevealMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if revealMode == .splitSlider {
                    HStack {
                        Text("Baseline")
                            .font(.caption2.bold())
                            .foregroundStyle(beforeAfterSplit < 0.3 ? .indigo : .secondary)
                        Spacer()
                        Text("New Design")
                            .font(.caption2.bold())
                            .foregroundStyle(beforeAfterSplit > 0.7 ? .indigo : .secondary)
                    }
                    Slider(value: $beforeAfterSplit, in: 0.0...1.0)
                        .tint(.indigo)
                        .frame(width: 220)
                } else if revealMode == .overlayDiff {
                    HStack(spacing: 8) {
                        Label("Baseline (Ghosted)", systemImage: "square.dashed")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Label("New Design", systemImage: "square.fill")
                            .font(.caption2)
                            .foregroundStyle(.indigo)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(.regularMaterial))
        }
    }
}
