import AudioToolbox
import SwiftUI

/// Shared camera trigger; menus are presented above the workspace, outside the header's bounds.
struct StudioCameraButton: View {
    @Binding var isPresented: Bool
    var isDisabled = false
    var onToggle: () -> Void = {}

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                onToggle()
                isPresented.toggle()
            }
            StudioViewportFeedback.snap()
        } label: {
            Image(systemName: "rotate.3d")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.alcoveInk)
                .frame(width: 49, height: 45)
                .background { StudioTactileCircleBackground(active: isPresented) }
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .accessibilityLabel("Camera view")
        .disabled(isDisabled)
        .buttonStyle(.plain)
        .onChange(of: isDisabled) { _, disabled in
            if disabled { isPresented = false }
        }
    }
}

enum StudioViewportFeedback {
    static func snap() {
        AudioServicesPlaySystemSound(1104)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
