import SwiftUI

public struct StudioToolbars: View {
    let currentStage: StageType
    let selectedFurniture: Furniture?
    let selectedLightFixture: LightFixture?
    let allFixtures: [LightFixture]
    @Binding var daylightHour: Double
    @Binding var beforeAfterSplit: Double
    @Binding var cameraPreset: ViewportPreset
    @Binding var revealMode: HarmonyRevealMode
    let illuminationReport: IlluminationReport?
    let harmonyMetrics: HarmonyComparisonMetrics?
    let onRotate: (Double) -> Void
    let onToggleArchive: () -> Void
    let onAddFixture: (String, LightLayer) -> Void
    let onOpenLightingSetup: () -> Void
    let onOpenLightingSimulation: () -> Void
    let onSelectFixture: ((UUID?) -> Void)?
    let onMoveFixture: ((Double, Double) -> Void)?
    let onUpdateFixture: ((Double?, Int?, String?) -> Void)?
    let onDeleteFixture: (() -> Void)?
    let onToggleFixturePower: ((UUID) -> Void)?
    let onOpenAR: (() -> Void)?

    public init(
        currentStage: StageType,
        selectedFurniture: Furniture?,
        selectedLightFixture: LightFixture? = nil,
        allFixtures: [LightFixture] = [],
        daylightHour: Binding<Double> = .constant(12.0),
        beforeAfterSplit: Binding<Double>,
        cameraPreset: Binding<ViewportPreset> = .constant(.top),
        revealMode: Binding<HarmonyRevealMode> = .constant(.splitSlider),
        illuminationReport: IlluminationReport? = nil,
        harmonyMetrics: HarmonyComparisonMetrics? = nil,
        onRotate: @escaping (Double) -> Void,
        onToggleArchive: @escaping () -> Void,
        onAddFixture: @escaping (String, LightLayer) -> Void = { _, _ in },
        onOpenLightingSetup: @escaping () -> Void = {},
        onOpenLightingSimulation: @escaping () -> Void = {},
        onSelectFixture: ((UUID?) -> Void)? = nil,
        onMoveFixture: ((Double, Double) -> Void)? = nil,
        onUpdateFixture: ((Double?, Int?, String?) -> Void)? = nil,
        onDeleteFixture: (() -> Void)? = nil,
        onToggleFixturePower: ((UUID) -> Void)? = nil,
        onOpenAR: (() -> Void)? = nil
    ) {
        self.currentStage = currentStage
        self.selectedFurniture = selectedFurniture
        self.selectedLightFixture = selectedLightFixture
        self.allFixtures = allFixtures
        self._daylightHour = daylightHour
        self._beforeAfterSplit = beforeAfterSplit
        self._cameraPreset = cameraPreset
        self._revealMode = revealMode
        self.illuminationReport = illuminationReport
        self.harmonyMetrics = harmonyMetrics
        self.onRotate = onRotate
        self.onToggleArchive = onToggleArchive
        self.onAddFixture = onAddFixture
        self.onOpenLightingSetup = onOpenLightingSetup
        self.onOpenLightingSimulation = onOpenLightingSimulation
        self.onSelectFixture = onSelectFixture
        self.onMoveFixture = onMoveFixture
        self.onUpdateFixture = onUpdateFixture
        self.onDeleteFixture = onDeleteFixture
        self.onToggleFixturePower = onToggleFixturePower
        self.onOpenAR = onOpenAR
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
                        .frame(minWidth: 44, minHeight: 44)
                        .background(
                            Circle()
                                .fill(cameraPreset == preset ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.18))
                        )
                        .foregroundStyle(cameraPreset == preset ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(preset.title)
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
                if let fixture = selectedLightFixture {
                    // Selected Light Editor Header
                    HStack {
                        Label(fixture.name, systemImage: fixture.layer.icon)
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                        Spacer()
                        Button {
                            onSelectFixture?(nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Power & Directional Nudges
                    HStack(spacing: 8) {
                        Button {
                            onToggleFixturePower?(fixture.id)
                        } label: {
                            Label(fixture.isOn ? "On" : "Off", systemImage: fixture.isOn ? "lightbulb.fill" : "lightbulb.slash")
                                .font(.caption2.bold())
                                .foregroundStyle(fixture.isOn ? .yellow : .secondary)
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        // Directional Nudge buttons
                        HStack(spacing: 4) {
                            Button { onMoveFixture?(-0.2, 0) } label: { Image(systemName: "arrow.left") }
                            Button { onMoveFixture?(0, -0.2) } label: { Image(systemName: "arrow.up") }
                            Button { onMoveFixture?(0, 0.2) } label: { Image(systemName: "arrow.down") }
                            Button { onMoveFixture?(0.2, 0) } label: { Image(systemName: "arrow.right") }
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                    }

                    // Brightness slider (lumens)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Brightness")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(fixture.lumens)) lm")
                                .font(.caption2.bold())
                        }
                        Slider(
                            value: Binding(
                                get: { fixture.lumens },
                                set: { onUpdateFixture?($0, nil, nil) }
                            ),
                            in: 200...2000,
                            step: 50
                        )
                        .tint(.orange)
                    }

                    // Warmth / Kelvin slider
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Warmth")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(fixture.colorTemperatureKelvin)K")
                                .font(.caption2.bold())
                        }
                        Slider(
                            value: Binding(
                                get: { Double(fixture.colorTemperatureKelvin) },
                                set: { onUpdateFixture?(nil, Int($0), nil) }
                            ),
                            in: 2200...5500,
                            step: 100
                        )
                        .tint(.yellow)
                    }

                    // Delete button
                    Button(role: .destructive) {
                        onDeleteFixture?()
                    } label: {
                        Label("Remove Light", systemImage: "trash")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                } else {
                    // Summary and Add Lights
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
                        Divider()
                    }

                    Text("Add Lighting Layers")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
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

                        Button("+ Accent") {
                            onAddFixture("Wall Sconce", .accent)
                        }
                        .buttonStyle(.bordered)
                        .font(.caption2)
                    }

                    if !allFixtures.isEmpty {
                        Divider()
                        Text("Room Fixtures (Tap to Edit):")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)

                        ForEach(allFixtures) { fix in
                            Button {
                                onSelectFixture?(fix.id)
                            } label: {
                                HStack {
                                    Image(systemName: fix.layer.icon)
                                        .font(.caption2)
                                    Text(fix.name)
                                        .font(.caption2)
                                    Spacer()
                                    Text("\(Int(fix.lumens)) lm")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .frame(width: 230)
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

                Divider()

                // AR Walkthrough Placeholder Button
                Button {
                    onOpenAR?()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arkit")
                            .font(.headline)
                        Text("View in AR Walkthrough")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.indigo.gradient))
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(.regularMaterial))
        }
    }
}
