import SwiftUI

struct LightingSourcePanel: View {
    @Bindable var editor: LightingSetupViewModel
    let isAdding: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sourceHeader
            StudioStageButton(title: isAdding ? "Save Lights" : "Add light", role: .add,
                              systemImage: isAdding ? "checkmark" : "plus.circle", fillsWidth: true, action: onAdd)
            if editor.isSelectingMultiple {
                selectionControls.transition(.opacity)
            }
            ScrollView {
                LazyVStack(spacing: 12) {
                    if editor.drafts.isEmpty {
                        Text(isAdding ? "Tap the room to place a light." : "Tap Add light to get started.")
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.vertical, 24)
                    }
                    ForEach(editor.drafts) { fixture in
                        sourceButton(fixture)
                    }
                }
                .padding(2)
            }
            .frame(maxHeight: .infinity)
            if editor.hasUnsavedChanges {
                Label("Unsaved changes", systemImage: "circle.fill")
                    .font(.caption)
            }
        }
        .padding(20)
        .animation(.easeInOut(duration: 0.16), value: editor.isSelectingMultiple)
        .animation(.easeInOut(duration: 0.16), value: isAdding)
        .lightingPanel()
    }

    private var sourceHeader: some View {
        HStack(spacing: 8) {
            Label("Your lights", systemImage: "lightbulb")
                .font(.custom("Cleanow", size: 20, relativeTo: .headline))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { editor.toggleMultipleSelection() } label: {
                Text(editor.isSelectingMultiple ? "Done" : "Select")
                    .font(.subheadline.bold())
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .disabled(editor.drafts.isEmpty)
            .opacity(editor.drafts.isEmpty ? 0.4 : 1)
            .accessibilityLabel(editor.isSelectingMultiple ? "Finish selecting lights" : "Select multiple lights")
        }
    }

    private var selectionControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(editor.selectionCount) selected").font(.subheadline.bold())
            HStack(spacing: 8) {
                Button { editor.selectAll() } label: {
                    Text("Select all").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .disabled(editor.selectionCount == editor.drafts.count)
                Spacer(minLength: 0)
                Button { editor.clearSelection() } label: {
                    Text("Clear").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .disabled(editor.selectionCount == 0)
            }
            .font(.caption.bold())
            .buttonStyle(.plain)
        }
    }

    private func sourceButton(_ fixture: LightFixture) -> some View {
        let selected = editor.selectedIDs.contains(fixture.id)
        return Button { editor.select(fixture.id) } label: {
            HStack(spacing: 8) {
                Image(systemName: fixture.resolvedKind.icon)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 24)
                    .opacity(fixture.isOn ? 1 : 0.5)
                Text(fixture.name)
                    .font(.custom("Cleanow", size: 16, relativeTo: .subheadline))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if editor.isSelectingMultiple {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                } else if selected {
                    Image(systemName: "checkmark")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 48)
            .background(selected ? Color.alcoveItemSurface : LightingTheme.row,
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(LightingTheme.ink.opacity(selected ? 1 : 0.3), lineWidth: 2))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.16), value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(editor.isSelectingMultiple ? (selected ? "Tap to deselect this light." : "Tap to add this light to your selection.") : "Tap to edit this light.")
    }
}

struct LightingSimulationPanel: View {
    @Binding var settings: LightingSimulationSettings
    let activeFixtureCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Lighting preview", systemImage: "sun.max")
                .font(.custom("Cleanow", size: 20, relativeTo: .headline))
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 0) {
                    lightToggle("Lights", isOn: $settings.artificialLightsOn)
                    Button { settings.showsLightFixtures.toggle() } label: {
                        Label(settings.showsLightFixtures ? "Hide fixtures" : "Show fixtures",
                              systemImage: settings.showsLightFixtures ? "eye.slash" : "eye")
                            .font(.caption.weight(.semibold))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(settings.showsLightFixtures ? "Visible" : "Hidden")
                    .accessibilityHint("Hides the lamp models while keeping their light on.")
                }
                .frame(maxWidth: .infinity)
                lightToggle("Sunlight", isOn: $settings.sunlightOn)
            }
            VStack(spacing: 0) {
                HStack {
                    Text("12 AM")
                    Spacer()
                    Text(settings.timeLabel).monospacedDigit()
                    Spacer()
                    Text("12 AM")
                }
                .font(.caption)
                Slider(value: Binding(get: { Double(settings.clampedMinute) },
                                      set: { settings.minuteOfDay = Int($0) }), in: 0...1439, step: 1)
                    .frame(minHeight: 44)
                    .tint(LightingTheme.accent)
                    .accessibilityLabel("Time of day")
                    .accessibilityValue(settings.timeLabel)
            }
            .disabled(!settings.sunlightOn)
            let sunlightActive = settings.sunlightOn &&
                IlluminationSimulationEngine().calculateDaylight(hourOfDay: settings.hourOfDay).intensityLux > 0
            if let limit = StudioLightBudget.maximumFixtures(sunlightActive: sunlightActive), activeFixtureCount > limit {
                Text("Showing the \(limit) brightest lights on this device.").font(.caption)
            }
        }
        .padding(20)
        .lightingPanel()
    }
    private func lightToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.subheadline.bold())
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(Color("AlcoveLightingToggle"))
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
    }

}

struct LightingEditPanel: View {
    @Binding var typePickerPresented: Bool
    @Bindable var editor: LightingSetupViewModel
    var minimumHeight: Double = 0
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Light settings", systemImage: "lamp.desk.fill")
                    .font(.custom("Cleanow", size: 20, relativeTo: .headline))
                Spacer(minLength: 0)
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash").foregroundStyle(.red).frame(width: 44, height: 44)
                }
                .disabled(editor.selected == nil)
                .accessibilityLabel(editor.selectionCount > 1 ? "Delete selected lights" : "Delete selected light")
            }
            selectionSummary
            lampTypePicker
            if let fixture = editor.selected {
                fixtureControls(fixture).transition(.opacity)
            } else {
                Text(editor.isSelectingMultiple ? "Select lights from the list or the room to edit them together." : "Choose a lamp type, then tap the room to place it.")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)
            }
        }
        .animation(.easeInOut(duration: 0.16), value: editor.selected?.id)
        .frame(minHeight: max(0, minimumHeight - 40), alignment: .top)
        .padding(20)
        .lightingPanel()
    }

    @ViewBuilder private var selectionSummary: some View {
        if editor.selectionCount > 1 {
            Text("Editing \(editor.selectionCount) lights")
                .font(.subheadline.bold())
            Text("Changes apply to all selected lights.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var lampTypePicker: some View {
        let current = editor.selected == nil ? editor.placementKind : editor.commonKind
        return Button { typePickerPresented.toggle() } label: {
            HStack(spacing: 8) {
                if let current { Image(systemName: current.icon).frame(width: 24) }
                Text(current?.title ?? "Mixed types")
                Image(systemName: "chevron.up.chevron.down").font(.caption.bold())
                Spacer(minLength: 0)
            }
            .font(.custom("Cleanow", size: 17, relativeTo: .subheadline))
            .foregroundStyle(LightingTheme.ink)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(LightingTheme.row, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LightingTheme.ink, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Lamp type")
        .disabled(editor.isSelectingMultiple && editor.selected == nil)
        .anchorPreference(key: LightingLampTypeAnchorKey.self, value: .bounds) { $0 }
    }

    private func fixtureControls(_ fixture: LightFixture) -> some View {
        let colorValue = editor.commonTemperature.map { "\($0) K" } ?? "Mixed"
        let brightnessValue = editor.commonBrightness.map { "\(Int($0)) lm" } ?? "Mixed"
        return VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 0) {
                HStack {
                    Text("Light color").font(.subheadline.bold())
                    Spacer(minLength: 4)
                    Text(colorValue).font(.caption).monospacedDigit()
                }
                LightingGradientSlider(value: Binding(
                    get: { Double(editor.selected?.colorTemperatureKelvin ?? fixture.colorTemperatureKelvin) },
                    set: { value in editor.updateSelected { $0.colorTemperatureKelvin = Int(value) } }
                ), range: 2200...6500, step: 100, colors: [.orange, .yellow, LightingTheme.row, .cyan],
                                       label: "Light color", formattedValue: editor.commonTemperature.map { "\($0) Kelvin" } ?? "Mixed values")
                HStack { Text("Warm"); Spacer(); Text("Cool") }.font(.caption)
            }
            VStack(spacing: 0) {
                HStack {
                    Text("Brightness").font(.subheadline.bold())
                    Spacer(minLength: 4)
                    Text(brightnessValue).font(.caption).monospacedDigit()
                }
                LightingGradientSlider(value: Binding(
                    get: { editor.selected?.lumens ?? fixture.lumens },
                    set: { value in editor.updateSelected { $0.lumens = value; $0.isOn = value > 0 } }
                ), range: 0...3000, step: 50,
                                       colors: [Color(uiColor: .darkGray), Color(uiColor: .systemGray6)],
                                       label: "Brightness", formattedValue: editor.commonBrightness.map { "\(Int($0)) lumens" } ?? "Mixed values")
                HStack { Text("Dim"); Spacer(); Text("Bright") }.font(.caption)
            }
        }
    }
}

/// Rendered by the workspace above every panel, without native popover chrome.
struct LightingLampTypeAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct LightingLampTypeMenu: View {
    let current: LightKind?
    let onSelect: (LightKind) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(LightKind.lightingKinds) { kind in
                Button { onSelect(kind) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark").frame(width: 18)
                            .opacity(current == kind ? 1 : 0)
                        Image(systemName: kind.icon).frame(width: 24)
                        Text(kind.title)
                        Spacer(minLength: 0)
                    }
                    .font(.custom("Cleanow", size: 17, relativeTo: .subheadline))
                    .foregroundStyle(LightingTheme.ink)
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(current == kind ? .isSelected : [])
            }
        }
        .padding(.vertical, 12)
        .frame(width: 270)
        .background(LightingTheme.row, in: RoundedRectangle(cornerRadius: 32))
        .overlay(RoundedRectangle(cornerRadius: 32).strokeBorder(LightingTheme.ink, lineWidth: 3))
    }
}
