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
    let onNextStage: () -> Void
    let isAdvancing: Bool
    let onTapOtter: () -> Void
    let onSelectStage: ((StageType) -> Void)?
    let isResultMode: Bool
    let onSelectResultMode: ((ResultWorkspaceMode) -> Void)?
    let onToggleResultSplit: (() -> Void)?
    let onBackToDashboard: (() -> Void)?
    @State private var otterTapTrigger = 0
    @State private var editor: LightingSetupViewModel
    @State private var preset: ViewportPreset = .top
    @State private var cameraRequestID = 0
    @State private var placement = LightingPlacementState()
    @State private var showingDelete = false
    @State private var lampTypeMenuPresented = false
    @State private var headerOverlapped = false
    @State private var sourcesExpanded = true
    @State private var previewExpanded = true
    @State private var editingExpanded = true
    @State private var saveError: String?

    init(room: Room, settings: Binding<LightingSimulationSettings>, isARPresented: Bool,
         onOpenAR: @escaping () -> Void, onNextStage: @escaping () -> Void,
         isAdvancing: Bool = false, onTapOtter: @escaping () -> Void = {},
         onSelectStage: ((StageType) -> Void)? = nil,
         isResultMode: Bool = false,
         onSelectResultMode: ((ResultWorkspaceMode) -> Void)? = nil,
         onToggleResultSplit: (() -> Void)? = nil,
         onBackToDashboard: (() -> Void)? = nil,
         onBack: @escaping () -> Void) {
        self.room = room
        self._settings = settings
        self.onBack = onBack
        self.isARPresented = isARPresented
        self.onOpenAR = onOpenAR
        self.onNextStage = onNextStage
        self.isAdvancing = isAdvancing
        self.onTapOtter = onTapOtter
        self.onSelectStage = onSelectStage
        self.isResultMode = isResultMode
        self.onSelectResultMode = onSelectResultMode
        self.onToggleResultSplit = onToggleResultSplit
        self.onBackToDashboard = onBackToDashboard
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
                VStack(spacing: 12) {
                    header.zIndex(30)
                    if !isResultMode {
                        stageProgress
                            .opacity(headerOverlapped ? 0 : 1)
                            .accessibilityHidden(headerOverlapped)
                    }

                    Text(viewportPrompt)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 60)
                        .padding(.top, 10)
                        .opacity(headerOverlapped ? 0 : 1)
                    Spacer(minLength: 0)
                    viewportControls
//                    Text(room.compassOrientation == nil ? "Sunlight preview · Sample direction" : "Sunlight preview · Aligned to magnetic north")
//                        .font(.caption2)
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .safeAreaPadding(.top)
                .padding(.bottom, max(32, proxy.safeAreaInsets.bottom + 12))
                .animation(.easeInOut(duration: 0.2), value: headerOverlapped)
                .zIndex(30)

                floatingPanels(width: panelWidth, height: max(200, proxy.size.height - 262))
                    .padding(.top, 192)
                    .padding(.bottom, 70)

                VStack {
                    Spacer(minLength: 0)
                    HStack {
                        otterBadgeButton
                        Spacer(minLength: 0)
                    }
                }
                .padding(.leading, 24)
                .padding(.bottom, 24)

                if !isResultMode {
                    VStack {
                        Spacer(minLength: 0)
                        HStack {
                            Spacer(minLength: 0)
                            StudioStageButton(title: "Next Stage", role: .next,
                                              action: continueToNextStage)
                                .disabled(isAdvancing)
                                .accessibilityLabel("Save lighting and continue to next stage")
                        }
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, max(24, proxy.safeAreaInsets.bottom + 12))
                }
            }

        }
        .clipped()
        .ignoresSafeArea()
        .background { LightingWorkspaceBackground() }
        .foregroundStyle(LightingTheme.ink)
        .tint(LightingTheme.ink)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlayPreferenceValue(LightingLampTypeAnchorKey.self) { anchor in
            GeometryReader { geometry in
                if lampTypeMenuPresented, let anchor {
                    let field = geometry[anchor]
                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.001)
                            .ignoresSafeArea()
                            .onTapGesture { lampTypeMenuPresented = false }
                        LightingLampTypeMenu(
                            current: editor.selected == nil ? editor.placementKind : editor.commonKind
                        ) { kind in
                            editor.chooseKind(kind)
                            lampTypeMenuPresented = false
                        }
                        .offset(x: max(16, min(geometry.size.width - 286, field.minX - 48)),
                                y: max(16, field.minY - 96))
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.16), value: lampTypeMenuPresented)
        .overlay {
            if showingDelete {
                ZStack {
                    Color.black.opacity(0.28).ignoresSafeArea()
                    LayoutAlert(type: .delete, layoutName: .constant("this light source"),
                                customTitle: editor.selectionCount > 1
                                    ? "Are you sure you want to delete these light sources?"
                                    : "Are you sure you want to delete this light source?",
                                compact: true,
                                onCancel: { showingDelete = false },
                                onConfirm: {
                                    editor.deleteSelected()
                                    showingDelete = false
                                })
                }
                .accessibilityAddTraits(.isModal)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showingDelete)
        .buttonStyle(.plain)
        .alert("Could not save lights", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "Please try again.") }
        .sensoryFeedback(.impact(weight: .light), trigger: editor.drafts.count)
    }

    private var header: some View {
        StudioHeaderLayout(
            title: isResultMode ? "Result: Lighting" : "Stage 4: Mark & Simulate Your Room Lighting",
            titleHidden: headerOverlapped
        ) {
            StudioStageButton(title: isResultMode ? "Back" : "Previous Stage", role: .previous) {
                do {
                    try editor.save(in: room, context: modelContext)
                    if isResultMode, let onBackToDashboard {
                        onBackToDashboard()
                    } else {
                        onBack()
                    }
                } catch { saveError = error.localizedDescription }
            }
        } actions: {
            if isResultMode {
                HStack(spacing: 10) {
                    StudioResultIconButton(
                        systemImage: "arrow.left.and.right",
                        accessibilityLabel: "Before and After Result"
                    ) {
                        saveLightsAndSwitch {
                            if let onToggleResultSplit {
                                onToggleResultSplit()
                            } else {
                                onSelectResultMode?(.overview)
                            }
                        }
                    }
                    StudioViewportActions(
                        onSelectPreset: { preset = $0; cameraRequestID += 1 },
                        onOpenAR: onOpenAR,
                        cameraDisabled: placement.isActive
                    )
                    StudioResultIconButton(
                        systemImage: "lightbulb",
                        active: true,
                        accessibilityLabel: "Lighting"
                    ) {
                        saveLightsAndSwitch { onSelectResultMode?(.overview) }
                    }
                    StudioResultIconButton(
                        systemImage: "arrow.up.and.down.and.arrow.left.and.right",
                        accessibilityLabel: "Rearrange"
                    ) {
                        saveLightsAndSwitch { onSelectResultMode?(.rearrange) }
                    }
                    StudioResultIconButton(
                        labelText: "AR",
                        accessibilityLabel: "Launch 1:1 Life-Size AR Walkthrough"
                    ) {
                        onOpenAR()
                        StudioViewportFeedback.snap()
                    }
                }
            } else {
                StudioViewportActions(
                    onSelectPreset: { preset = $0; cameraRequestID += 1 },
                    onOpenAR: onOpenAR,
                    cameraDisabled: placement.isActive
                )
            }
        }
    }

    private func saveLightsAndSwitch(_ action: () -> Void) {
        do {
            try editor.save(in: room, context: modelContext)
            StudioViewportFeedback.snap()
            action()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private var stageProgress: some View {
        StudioStageProgress(
            stage: .illumination,
            room: room,
            accessibilityTitle: "Step 4 of 5 · Lighting",
            onSelectStage: onSelectStage
        )
    }

    private func floatingPanels(width: Double, height: Double) -> some View {
        // Reserve a separate footer row for Otter and Next Stage. Both columns
        // share this bottom edge rather than stretching Settings down to the button.
        let columnHeight = max(200, height - min(112, max(0, height - 560)))
        let previewHeight = min(270, max(250, height * 0.44))
        let editingHeight = max(160, columnHeight - previewHeight - 20)
        return HStack(alignment: .top, spacing: 0) {
            LightingCollapsiblePanel(title: "Your lights", expanded: $sourcesExpanded, edge: .leading, width: width) {
                LightingSourcePanel(editor: editor, isAdding: placement.isActive, onAdd: togglePlacement)
                    .frame(width: width, height: columnHeight)
            }
            .frame(height: columnHeight)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 20) {
                LightingCollapsiblePanel(title: "Lighting preview", expanded: $previewExpanded, edge: .trailing, width: width) {
                    LightingSimulationPanel(settings: $settings,
                        activeFixtureCount: editor.drafts.filter { settings.output(for: $0) > 0 }.count)
                    .frame(width: width, height: previewHeight)
                }
                .frame(height: previewHeight)
                LightingCollapsiblePanel(title: "Light settings", expanded: $editingExpanded, edge: .trailing, width: width) {
                    LightingEditPanel(typePickerPresented: $lampTypeMenuPresented, editor: editor, minimumHeight: editingHeight,
                                      onDelete: { showingDelete = true })
                    .frame(width: width, height: editingHeight)
                }
                .frame(height: editingHeight)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// UI integration point only; the parent can supply the assistant action later.
    private var otterBadgeButton: some View {
        Button {
            otterTapTrigger += 1
            onTapOtter()
        } label: {
            OtterAvatarBadgeView(size: 72, showsQuestionBadge: true)
                .frame(width: 72, height: 72)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: otterTapTrigger)
        .accessibilityLabel("Otter assistant")
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

    private func continueToNextStage() {
        guard !isAdvancing else { return }
        do {
            try editor.save(in: room, context: modelContext)
            onNextStage()
        } catch {
            saveError = error.localizedDescription
        }
    }
}
