import SwiftUI
import SwiftData

/// Full-screen room canvas with independently collapsible floating inspectors.
struct LightingWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let room: Room
    @Binding var settings: LightingSimulationSettings
    let onBack: () -> Void
    let isARPresented: Bool
    let onOpenAR: () -> Void
    let onSelectStage: ((StageType) -> Void)?
    @State private var editor: LightingSetupViewModel
    @State private var preset: ViewportPreset = .top
    @State private var cameraRequestID = 0
    @State private var placement = LightingPlacementState()
    @State private var showingDelete = false
    @State private var headerActionsWidth: CGFloat = 300
    @State private var headerOverlapped = false
    @State private var sourcesExpanded = true
    @State private var previewExpanded = true
    @State private var editingExpanded = true
    @State private var saveError: String?

    init(room: Room, settings: Binding<LightingSimulationSettings>, isARPresented: Bool,
         onOpenAR: @escaping () -> Void,
         onSelectStage: ((StageType) -> Void)? = nil,
         onBack: @escaping () -> Void) {
        self.room = room
        self._settings = settings
        self.onBack = onBack
        self.isARPresented = isARPresented
        self.onOpenAR = onOpenAR
        self.onSelectStage = onSelectStage
        let editor = LightingSetupViewModel(room: room)
        editor.selectedID = editor.drafts.first?.id
        _editor = State(initialValue: editor)
    }

    var body: some View {
        GeometryReader { proxy in
            let panelWidth = min(300.0, max(240.0, proxy.size.width * 0.22))
            ZStack {
                if !isARPresented {
                    lightingPreview
                        .ignoresSafeArea()
                        .accessibilityLabel("Room lighting layout")
                        .accessibilityHint("Drag to turn the room. Pinch to zoom.")
                        .accessibilityAction(named: "Add light at center") {
                            if !placement.isActive { togglePlacement() }
                            editor.place(unitX: 0.5, unitZ: 0.5)
                        }
                }
                VStack(spacing: 10) {
                    header
                    stageProgress
                        .opacity(headerOverlapped ? 0 : 1)
                        .accessibilityHidden(headerOverlapped)
                    Text(viewportPrompt)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 60)
                        .opacity(headerOverlapped ? 0 : 1)
                    Spacer(minLength: 0)
                    viewportControls
                    Text(room.compassOrientation == nil ? "Sunlight preview · Sample direction" : "Sunlight preview · Aligned to magnetic north")
                        .font(.caption2)
                }
                .padding(.horizontal, 20)
                .padding(.top, max(52, proxy.safeAreaInsets.top + 20))
                .padding(.bottom, max(32, proxy.safeAreaInsets.bottom + 12))

                floatingPanels(width: panelWidth, height: max(200, proxy.size.height - 262))
                    .padding(.top, 192)
                    .padding(.bottom, 70)
            }

        }
        .clipped()
        .ignoresSafeArea()
        .background { LightingWorkspaceBackground() }
        .foregroundStyle(LightingTheme.ink)
        .tint(LightingTheme.ink)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(editor.selectionCount > 1 ? "Delete \(editor.selectionCount) selected lights?" : "Delete this light?", isPresented: $showingDelete, titleVisibility: .visible) {
            Button(editor.selectionCount > 1 ? "Delete \(editor.selectionCount) Lights" : "Delete Light", role: .destructive) { editor.deleteSelected() }
        }
        .alert("Could not save lights", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "Please try again.") }
        .sensoryFeedback(.impact(weight: .light), trigger: editor.drafts.count)
    }

    private var header: some View {
        ZStack {
            Text("Stage 4: Mark & Simulate Your Room Lighting")
                .font(.custom("Cleanow", size: 36, relativeTo: .largeTitle))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, headerActionsWidth + 16)
                .opacity(headerOverlapped ? 0 : 1)
                .accessibilityHidden(headerOverlapped)

            HStack {
                Button(action: onBack) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        Text("Previous Stage")
                            .font(.custom("Cleanow", size: 16, relativeTo: .subheadline))
                    }
                    .foregroundStyle(Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0))
                    .padding(.horizontal, 16)
                    .frame(minWidth: 44, minHeight: 44)
                    .background {
                        ZStack {
                            Capsule()
                                .fill(Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0))

                            ZStack {
                                VStack(spacing: 0) {
                                    Color(red: 0xF9 / 255.0, green: 0xE4 / 255.0, blue: 0xC9 / 255.0)
                                    Color(red: 0xE9 / 255.0, green: 0xC7 / 255.0, blue: 0x9D / 255.0)
                                }

                                Capsule()
                                    .fill(Color(red: 0xFF / 255.0, green: 0xF7 / 255.0, blue: 0xE7 / 255.0))
                                    .padding(.top, 2)
                                    .padding(.bottom, 3.5)
                            }
                            .clipShape(Capsule())
                            .padding(2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous Stage")
                Spacer(minLength: 0)
                HStack(spacing: 16) {
                    TactilePillButton(title: "Save", size: .compact, systemImage: "checkmark", action: save)
                        .disabled(!editor.hasUnsavedChanges)
                        .opacity(editor.hasUnsavedChanges ? 1 : 0.55)
                    StudioViewportActions(
                        onSelectPreset: { preset = $0; cameraRequestID += 1 },
                        onOpenAR: onOpenAR,
                        cameraDisabled: placement.isActive,
                        layoutOnly: $settings.layoutOnly
                    )
                }
                .fixedSize(horizontal: true, vertical: false)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { headerActionsWidth = $0 }
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var stageProgress: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Text("Step 4 of 5 · Lighting")
                .font(.headline)
                .frame(maxWidth: .infinity)
        } else {
            stageBadges
        }
    }

    private var stageBadges: some View {
        let titles = ["Scan", "Check", "Rearrange", "Lighting", "Result"]
        let completedColor = Color(red: 0.87, green: 0.87, blue: 0.69)
        let upcomingColor = Color(red: 0.91, green: 0.91, blue: 0.91)
        let upcomingInk = Color(red: 0.71, green: 0.71, blue: 0.71)
        return HStack(alignment: .top, spacing: 8) {
            ForEach(titles.indices, id: \.self) { index in
                let active = index == 3
                let stageType: StageType? = switch index {
                case 1: .audit
                case 2: .rearrangement
                case 4: .harmony
                default: nil
                }
                let completed: Bool = switch index {
                case 0: true
                case 1: room.isCompleted(.audit)
                case 2: room.isCompleted(.rearrangement)
                case 4: room.isCompleted(.harmony)
                default: false
                }
                let badgeContent = VStack(spacing: 8) {
                    ZStack {
                        Circle().fill(completed ? completedColor : active ? Color.alcovePrimaryFill : upcomingColor)
                        Circle().stroke(active || completed ? LightingTheme.ink : upcomingInk, lineWidth: 2)
                        Text("\(index + 1)")
                            .font(.custom("Cleanow", size: 24, relativeTo: .title2))
                    }
                    .foregroundStyle(active || completed ? LightingTheme.ink : upcomingInk)
                    .frame(width: 56, height: 56)
                    Text(titles[index])
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(width: 76)
                .contentShape(Rectangle())

                Group {
                    if completed, let stageType, let onSelectStage {
                        Button {
                            onSelectStage(stageType)
                        } label: {
                            badgeContent
                        }
                        .buttonStyle(.plain)
                    } else {
                        badgeContent
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Step \(index + 1), \(titles[index]), \(completed ? "completed" : active ? "current" : "upcoming")")
                .accessibilityAddTraits(active ? .isSelected : [])
                if index < titles.count - 1 {
                    Capsule()
                        .fill(completed ? completedColor : upcomingInk)
                        .frame(maxWidth: .infinity)
                        .frame(height: 3)
                        .padding(.top, 27)
                }
            }
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }

    private func floatingPanels(width: Double, height: Double) -> some View {
        HStack(alignment: .top, spacing: 0) {
            LightingCollapsiblePanel(title: "Your lights", expanded: $sourcesExpanded, edge: .leading, width: width) {
                LightingSourcePanel(editor: editor, isAdding: placement.isActive, onAdd: togglePlacement)
                    .frame(width: width, height: height)
            }
            .frame(height: height)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 20) {
                LightingCollapsiblePanel(title: "Lighting preview", expanded: $previewExpanded, edge: .trailing, width: width) {
                    LightingSimulationPanel(settings: $settings,
                        activeFixtureCount: editor.drafts.filter { settings.output(for: $0) > 0 }.count)
                    .frame(width: width, height: min(225, height * 0.38))
                }
                .frame(height: min(225, height * 0.38))
                LightingCollapsiblePanel(title: "Light settings", expanded: $editingExpanded, edge: .trailing, width: width) {
                    LightingEditPanel(editor: editor, minimumHeight: max(160, height - min(225, height * 0.38) - 20),
                                      onDelete: { showingDelete = true })
                    .frame(width: width, height: max(160, height - min(225, height * 0.38) - 20))
                }
                .frame(height: max(160, height - min(225, height * 0.38) - 20))
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var lightingPreview: some View {
        LightingRoomPreview(
            snapshot: LightingRoomSnapshot(room: room, fixtures: editor.drafts),
            settings: settings,
            preset: preset,
            cameraRequestID: cameraRequestID,
            onHeaderOverlap: { headerOverlapped = $0 },
            backgroundColor: .clear,
            onPlaceLight: { point in
                    guard !editor.isSelectingMultiple else { return }
                    editor.place(unitX: Double(point.x), unitZ: Double(point.y))
                },
            onSelectLight: { editor.select($0) },
            onClearSelection: { editor.dismissSelection() },
                onMoveLight: { id, point in editor.move(id, x: Double(point.x), z: Double(point.y)) },
            isPlacementMode: placement.isActive,
            selectedFixtureIDs: editor.selectedIDs,
            isSelectingMultiple: editor.isSelectingMultiple
        )
    }

    @ViewBuilder private var viewportControls: some View {
        if placement.isActive {
            HStack(spacing: 16) {
                Label("Top view locked", systemImage: "lock.fill").font(.caption)
                Button("Done", action: togglePlacement)
                    .font(.subheadline.bold())
                    .frame(minWidth: 64, minHeight: 44)
                    .background(LightingTheme.row, in: Capsule())
            }
        } else {
            Text("Drag to turn · Pinch to zoom").font(.caption)
        }
    }

    private func togglePlacement() {
        if placement.isActive {
            preset = placement.finish()
        } else {
            placement.begin(from: preset)
            preset = .top
            editor.prepareForPlacement()
        }
    }

    private var viewportPrompt: String {
        if editor.isSelectingMultiple { return "Tap lights in the room or list to select them." }
        if placement.isActive { return "Tap to add a light. Drag a selected light to move it." }
        if editor.drafts.isEmpty { return "Tap Add light to get started." }
        return "Tap a light to edit it. Drag the move icon to reposition it."
    }

    private func save() {
        do { try editor.save(in: room, context: modelContext) }
        catch { saveError = error.localizedDescription }
    }
}
