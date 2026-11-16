import AudioToolbox
import SwiftUI

/// The same POV menu and AR entry used by Audit and Lighting.
struct StudioViewportActions: View {
    let onSelectPreset: (ViewportPreset) -> Void
    let onOpenAR: () -> Void
    var cameraDisabled = false
    var layoutOnly: Binding<Bool>?

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(ViewportPreset.allCases) { preset in
                    if preset == .dollhouse { Divider() }
                    Button {
                        onSelectPreset(preset)
                        StudioViewportFeedback.snap()
                    } label: {
                        Label(preset.title, systemImage: preset.systemImage)
                    }
                }
                if let layoutOnly {
                    Divider()
                    Toggle("Show room clearly", isOn: layoutOnly)
                }
            } label: {
                Image(systemName: "rotate.3d")
                    .font(.body.weight(.semibold))
                    .modifier(StudioViewportActionSurface())
            }
            .accessibilityLabel("Point of View")
            .disabled(cameraDisabled)

            Button {
                onOpenAR()
                StudioViewportFeedback.snap()
            } label: {
                Text("AR")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .modifier(StudioViewportActionSurface())
            }
            .accessibilityLabel("Launch 1:1 Life-Size AR Walkthrough")
        }
        .buttonStyle(.plain)
    }
}

private struct StudioViewportActionSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().stroke(Color.primary.opacity(0.08), lineWidth: 1))
            .shadow(color: Color.primary.opacity(0.04), radius: 8, y: 2)
    }
}

enum StudioViewportFeedback {
    static func snap() {
        AudioServicesPlaySystemSound(1104)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
}
