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
    @State private var editor: LightingSetupViewModel
    @State private var preset: ViewportPreset = .top
    @State private var cameraRequestID = 0
    @State private var placement = LightingPlacementState()
    @State private var showingDelete = false
    @State private var headerOverlapped = false
    @State private var sourcesExpanded = true
    @State private var previewExpanded = true
    @State private var editingExpanded = true
    @State private var saveError: String?

    init(room: Room, settings: Binding<LightingSimulationSettings>, isARPresented: Bool,
         onOpenAR: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.room = room
        self._settings = settings
        self.onBack = onBack
        self.isARPresented = isARPresented
        self.onOpenAR = onOpenAR
        let editor = LightingSetupViewModel(room: room)
        editor.selectedID = editor.drafts.first?.id
        _editor = State(initialValue: editor)
    }

    var body: some View {
        GeometryReader { proxy in
            let panelWidth = min(288.0, max(240.0, proxy.size.width * 0.21))
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
                .padding(20)

                floatingPanels(width: panelWidth, height: max(200, proxy.size.height - 230))
                    .padding(.top, 160)
                    .padding(.bottom, 70)
            }

        }
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
        HStack(spacing: 16) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.headline.bold())
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(width: 44, height: 44)
                    .background(LightingTheme.row, in: Circle())
                    .overlay(Circle().stroke(LightingTheme.ink, lineWidth: 2))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            Text("Stage 3: Mark & Simulate Your Room Lighting")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .opacity(headerOverlapped ? 0 : 1)
                .accessibilityHidden(headerOverlapped)
            Button(action: save) {
                Label("Save", systemImage: "checkmark")
            }
            .buttonStyle(LightingPrimaryButtonStyle())
            .disabled(!editor.hasUnsavedChanges)
            .opacity(editor.hasUnsavedChanges ? 1 : 0.55)
            StudioViewportActions(
                onSelectPreset: { preset = $0; cameraRequestID += 1 },
                onOpenAR: onOpenAR,
                cameraDisabled: placement.isActive,
                layoutOnly: $settings.layoutOnly
            )
        }
    }

    @ViewBuilder private var stageProgress: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Text("Step 3 of 4 · Lighting")
                .font(.headline)
                .frame(maxWidth: .infinity)
        } else {
            stageBadges
        }
    }

    private var stageBadges: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(StageType.allCases) { stage in
                let completed = room.isCompleted(stage)
                let active = stage == .illumination
                VStack(spacing: 8) {
                    ZStack {
                        Circle().fill(active ? LightingTheme.accent : completed ? Color.green.opacity(0.2) : LightingTheme.border)
                        Circle().stroke(LightingTheme.ink.opacity(0.7), lineWidth: 1.5)
                        if completed {
                            Image(systemName: "checkmark").font(.headline.bold())
                        } else {
                            Text("\(stage.stageNumber)").font(.system(.headline, design: .rounded, weight: .bold))
                        }
                    }
                    .frame(width: 40, height: 40)
                    Text(progressTitle(stage)).font(.caption)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(active ? .isSelected : [])
                if stage != .harmony {
                    Capsule().fill(LightingTheme.border).frame(maxWidth: 56).frame(height: 2).padding(.top, 20)
                }
            }
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    private func floatingPanels(width: Double, height: Double) -> some View {
        HStack(alignment: .top, spacing: 0) {
            LightingCollapsiblePanel(title: "Your lights", expanded: $sourcesExpanded, edge: .leading) {
                LightingSourcePanel(editor: editor, isAdding: placement.isActive, onAdd: togglePlacement)
                    .frame(width: width, height: height)
            }
            .frame(height: height)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 20) {
                LightingCollapsiblePanel(title: "Lighting preview", expanded: $previewExpanded, edge: .trailing) {
                    ScrollView {
                        LightingSimulationPanel(settings: $settings,
                            activeFixtureCount: editor.drafts.filter { settings.output(for: $0) > 0 }.count)
                    }
                    .scrollClipDisabled()
                    .frame(width: width, height: min(245, height * 0.42))
                }
                .frame(height: min(245, height * 0.42))
                LightingCollapsiblePanel(title: "Light settings", expanded: $editingExpanded, edge: .trailing) {
                    ScrollView {
                        LightingEditPanel(editor: editor, minimumHeight: max(160, height - min(245, height * 0.42) - 20),
                                          onDelete: { showingDelete = true })
                    }
                    .scrollClipDisabled()
                    .frame(width: width, height: max(160, height - min(245, height * 0.42) - 20))
                }
                .frame(height: max(160, height - min(245, height * 0.42) - 20))
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

    private func progressTitle(_ stage: StageType) -> String {
        switch stage {
        case .audit: return "Audit"
        case .rearrangement: return "Rearrange"
        case .illumination: return "Lighting"
        case .harmony: return "Harmony"
        }
    }

    private func save() {
        do { try editor.save(in: room, context: modelContext) }
        catch { saveError = error.localizedDescription }
    }
}
