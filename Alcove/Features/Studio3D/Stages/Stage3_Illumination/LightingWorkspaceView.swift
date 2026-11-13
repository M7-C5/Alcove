import SwiftUI
import SwiftData

/// A bounded three-column workspace: light sources, room, then simulation and editing.
struct LightingWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let room: Room
    @Binding var settings: LightingSimulationSettings
    let onBack: () -> Void
    @State private var editor: LightingSetupViewModel
    @State private var preset: ViewportPreset = .top
    @State private var placement = LightingPlacementState()
    @State private var showingDelete = false
    @State private var saveError: String?
    @State private var showingARWalkthrough = false

    init(room: Room, settings: Binding<LightingSimulationSettings>, onBack: @escaping () -> Void) {
        self.room = room
        self._settings = settings
        self.onBack = onBack
        let editor = LightingSetupViewModel(room: room)
        editor.selectedID = editor.drafts.first?.id
        _editor = State(initialValue: editor)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = LightingWorkspaceLayout(width: proxy.size.width,
                                                  accessibilityText: dynamicTypeSize.isAccessibilitySize)
            VStack(spacing: 16) {
                header
                stageProgress
                if layout.usesColumns {
                    columns(layout)
                } else {
                    compactWorkspace(width: proxy.size.width)
                }
            }
            .padding(layout.inset)
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
        .fullScreenCover(isPresented: $showingARWalkthrough) {
            ARWalkthroughView(room: room)
        }
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
            Text("Stage 3: Light your room")
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Button(action: save) {
                Label("Save", systemImage: "checkmark")
            }
            .buttonStyle(LightingPrimaryButtonStyle())
            .disabled(!editor.hasUnsavedChanges)
            .opacity(editor.hasUnsavedChanges ? 1 : 0.55)
            Button { showingARWalkthrough = true } label: {
                Label("AR", systemImage: "arkit")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .frame(minWidth: 44, minHeight: 44)
                    .background(LightingTheme.row, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Life-size AR walkthrough")
            cameraMenu
        }
    }

    private var cameraMenu: some View {
        Menu {
            ForEach(ViewportPreset.allCases) { angle in
                Button { preset = angle } label: { Label(angle.title, systemImage: angle.systemImage) }
            }
            Divider()
            Toggle("Show room clearly", isOn: $settings.layoutOnly)
        } label: {
            Image(systemName: "cube")
                .font(.title3)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .frame(width: 44, height: 44)
                .background(LightingTheme.row, in: Circle())
                .overlay(Circle().stroke(LightingTheme.ink, lineWidth: 2))
        }
        .accessibilityLabel("Camera view")
        .disabled(placement.isActive)
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

    private func columns(_ layout: LightingWorkspaceLayout) -> some View {
        HStack(alignment: .top, spacing: layout.spacing) {
            LightingSourcePanel(editor: editor, isAdding: placement.isActive, onAdd: togglePlacement)
                .frame(width: layout.sourceWidth)
                .frame(maxHeight: .infinity)
            roomViewport()
                .frame(width: layout.viewportWidth)
                .frame(maxHeight: .infinity)
            ScrollView {
                inspectors
            }
            .scrollClipDisabled()
            .frame(width: layout.inspectorWidth)
        }
    }

    private func compactWorkspace(width: Double) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                roomViewport(previewHeight: min(480, max(280, width * 0.5)))
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                LightingSourcePanel(editor: editor, isAdding: placement.isActive, onAdd: togglePlacement)
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 480 : 320)
                inspectors
            }
        }
    }

    private func roomViewport(previewHeight: Double? = nil) -> some View {
        VStack(spacing: 16) {
            Text(viewportPrompt)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Group {
                if !showingARWalkthrough {
                    lightingPreview
                }
            }
            .frame(height: previewHeight.map { CGFloat($0) })
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(12)
            .lightingPanel()
            .accessibilityLabel("Room lighting layout")
            .accessibilityHint(placement.isActive ? "Tap to place a light. The top view is locked." : "Drag to turn the room. Pinch to zoom.")
            .accessibilityAction(named: "Add light at center") {
                if !placement.isActive { togglePlacement() }
                editor.place(unitX: 0.5, unitZ: 0.5)
            }
            viewportControls
            Text("Sunlight is a preview")
                .font(.caption)
                .foregroundStyle(LightingTheme.ink.opacity(0.85))
        }
    }

    private var lightingPreview: some View {
        LightingRoomPreview(
            snapshot: LightingRoomSnapshot(room: room, fixtures: editor.drafts),
            settings: settings,
            preset: preset,
            backgroundColor: UIColor(LightingTheme.canvas),
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

    private var inspectors: some View {
        VStack(spacing: 24) {
            LightingSimulationPanel(settings: $settings,
                                    activeFixtureCount: editor.drafts.filter { settings.output(for: $0) > 0 }.count)
            LightingEditPanel(editor: editor, onDelete: { showingDelete = true })
        }
        .frame(maxWidth: .infinity)
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
