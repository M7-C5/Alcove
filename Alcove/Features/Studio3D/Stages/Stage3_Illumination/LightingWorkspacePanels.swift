import SwiftUI

struct LightingSourcePanel: View {
    @Bindable var editor: LightingSetupViewModel
    let isAdding: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sourceHeader
            Button(action: onAdd) {
                Label(isAdding ? "Done adding" : "Add light", systemImage: isAdding ? "checkmark" : "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LightingPrimaryButtonStyle(isCream: true))
            if editor.isSelectingMultiple { selectionControls }
            ScrollView {
                LazyVStack(spacing: 16) {
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
            }
            if editor.hasUnsavedChanges {
                Label("Unsaved changes", systemImage: "circle.fill")
                    .font(.caption)
            }
        }
        .padding(24)
        .lightingPanel()
    }

    private var sourceHeader: some View {
        HStack(spacing: 8) {
            Label("Your lights", systemImage: "lightbulb")
                .font(.system(.headline, design: .rounded, weight: .heavy))
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
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
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
            .background(selected ? LightingTheme.accent.opacity(0.25) : LightingTheme.row,
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(selected ? LightingTheme.ink.opacity(0.5) : .clear))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(editor.isSelectingMultiple ? (selected ? "Tap to deselect this light." : "Tap to add this light to your selection.") : "Tap to edit this light.")
    }
}

struct LightingSimulationPanel: View {
    @Binding var settings: LightingSimulationSettings
    let activeFixtureCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Lighting preview", systemImage: "sun.max")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 16) {
                lightToggle("Lights", isOn: $settings.artificialLightsOn)
                lightToggle("Sunlight", isOn: $settings.sunlightOn)
            }
            .disabled(settings.layoutOnly)
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
                    .tint(.blue)
                    .accessibilityLabel("Time of day")
                    .accessibilityValue(settings.timeLabel)
            }
            .disabled(settings.layoutOnly || !settings.sunlightOn)
            if activeFixtureCount > 7 {
                Text("Showing your seven brightest lights.").font(.caption)
            }
        }
        .padding(24)
        .lightingPanel()
    }
    private func lightToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.subheadline.bold())
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(.green)
                .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity)
    }

}

struct LightingEditPanel: View {
    @Bindable var editor: LightingSetupViewModel
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Light settings", systemImage: "lamp.desk.fill")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
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
                fixtureControls(fixture)
            } else {
                Text(editor.isSelectingMultiple ? "Select lights from the list or the room to edit them together." : "Choose a lamp type, then tap the room to place it.")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 16)
            }
        }
        .padding(24)
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
        Picker("Lamp type", selection: Binding<LightKind?>(
            get: { editor.selected == nil ? editor.placementKind : editor.commonKind },
            set: { if let kind = $0 { editor.chooseKind(kind) } }
        )) {
            if editor.selected != nil && editor.commonKind == nil {
                Text("Mixed types").tag(nil as LightKind?)
            }
            if let current = editor.commonKind, !LightKind.lightingKinds.contains(current) {
                Label(current.title, systemImage: current.icon)
                    .tag(Optional(current))
                    .disabled(true)
            }
            ForEach(LightKind.lightingKinds) { kind in
                Label(kind.title, systemImage: kind.icon).tag(Optional(kind))
            }
        }
        .font(.subheadline)
        .pickerStyle(.menu)
        .labelsHidden()
        .accessibilityLabel("Lamp type")
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(LightingTheme.row, in: RoundedRectangle(cornerRadius: 12))
        .disabled(editor.isSelectingMultiple && editor.selected == nil)
    }

    private func fixtureControls(_ fixture: LightFixture) -> some View {
        let colorValue = editor.commonTemperature.map { "\($0) K" } ?? "Mixed"
        let brightnessValue = editor.commonBrightness.map { "\(Int($0)) lm" } ?? "Mixed"
        return VStack(alignment: .leading, spacing: 16) {
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
