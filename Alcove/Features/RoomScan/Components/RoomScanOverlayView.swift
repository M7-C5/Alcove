import SwiftUI

/// Live scan HUD overlay featuring Alcove's cream `Cancel ✕` and yellow `Done ✓` tactile pill buttons.
public struct RoomScanOverlayView: View {
    public let state: RoomScanViewModel.ScanState
    public let onDone: () -> Void
    public let onCancel: () -> Void

    public init(
        state: RoomScanViewModel.ScanState,
        onDone: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.state = state
        self.onDone = onDone
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                scanPillButton(
                    title: "Cancel",
                    systemImage: "xmark",
                    isPrimary: false,
                    action: onCancel
                )
                .disabled(state == .processing)
                .accessibilityLabel("Cancel room scan")

                Spacer()

                if state == .scanning {
                    scanPillButton(
                        title: "Done",
                        systemImage: "checkmark",
                        isPrimary: true,
                        action: onDone
                    )
                    .accessibilityLabel("Finish room scan")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()

            if state == .processing {
                VStack(spacing: 14) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(Color.alcoveInk)
                    Text("Processing room scan...")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.alcoveInk)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
                .background(Color.alcoveSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.alcoveInk, lineWidth: 3)
                )

                Spacer()
            }
        }
    }

    private func scanPillButton(
        title: String,
        systemImage: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let mainColor = isPrimary ? Color.alcovePrimaryFill : Color.alcoveSurfaceElevated
        let highlightColor = isPrimary ? Color.alcovePrimaryHighlight : Color.alcoveSecondaryHighlight
        let shadowColor = isPrimary ? Color.alcovePrimaryShadow : Color.alcoveSecondaryShadow

        return Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.custom("Cleanow", size: 22, relativeTo: .title3))
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .heavy))
            }
            .foregroundStyle(Color.alcoveInk)
            .padding(.horizontal, 22)
            .frame(minWidth: 112, minHeight: 50)
            .background {
                GeometryReader { geometry in
                    let border: CGFloat = 3.5
                    let band: CGFloat = 5
                    ZStack {
                        Capsule()
                            .fill(Color.alcoveInk)

                        Capsule()
                            .fill(shadowColor)
                            .padding(border)

                        Capsule()
                            .fill(highlightColor)
                            .padding(.horizontal, border)
                            .padding(.top, border)
                            .padding(.bottom, border + band)
                            .mask(alignment: .top) {
                                Rectangle().frame(height: geometry.size.height * 0.52)
                            }

                        Capsule()
                            .fill(mainColor)
                            .padding(.horizontal, border)
                            .padding(.top, border + band)
                            .padding(.bottom, border + band)

                        Capsule()
                            .strokeBorder(Color.alcoveInk, lineWidth: border)
                    }
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
