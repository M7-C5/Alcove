import AudioToolbox
import SwiftUI

struct StudioViewportActions: View {
    let onSelectPreset: (ViewportPreset) -> Void
    let onOpenAR: () -> Void
    var cameraDisabled = false
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
                    .frame(width: 54, height: 45)
                    .background { StudioTactileCircleBackground(active: cameraPresented) }
                    .contentShape(Capsule())
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
                })
                .fixedSize(horizontal: true, vertical: true)
                .transition(.opacity.combined(with: .scale(scale: 0.18, anchor: .topTrailing)))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.80), value: cameraPresented)
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
