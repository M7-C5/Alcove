import AudioToolbox
import SwiftUI

struct StudioViewportActions: View {
    let onSelectPreset: (ViewportPreset) -> Void
    let onOpenAR: () -> Void
    var cameraDisabled = false
    var layoutOnly: Binding<Bool>?
    @State private var cameraPresented = false
    @State private var selected: ViewportPreset = .top

    var body: some View {
        HStack(spacing: 10) {
            Button {
                cameraPresented.toggle()
                StudioViewportFeedback.snap()
            } label: {
                Image(systemName: "rotate.3d")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.alcoveInk)
                    .frame(width: 45, height: 45)
                    .background { StudioTactileCircleBackground(active: cameraPresented) }
                    .contentShape(Circle())
            }
            .accessibilityLabel("Camera view")
            .disabled(cameraDisabled)

        }
        .overlay(alignment: .topTrailing) {
            if cameraPresented {
                StudioCameraMenuContent(selected: selected, onSelect: { preset in
                    selected = preset
                    onSelectPreset(preset)
                    StudioViewportFeedback.snap()
                    cameraPresented = false
                }, layoutOnly: layoutOnly)
                .fixedSize(horizontal: true, vertical: true)
                .offset(y: 54)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
            }
        }
        .animation(.easeInOut(duration: 0.16), value: cameraPresented)
        .buttonStyle(.plain)
        .onChange(of: cameraDisabled) { _, disabled in
            if disabled { cameraPresented = false }
        }
    }
}

enum StudioViewportFeedback {
    static func snap() {
        AudioServicesPlaySystemSound(1104)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
