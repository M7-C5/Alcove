import SwiftUI

/// Custom Alcove confirmation alert shown when tapping Done during room scanning,
/// featuring the peeking Otter mascot and cream/yellow tactile buttons.
struct RoomScanDoneAlert: View {
    let onNo: () -> Void
    let onYes: () -> Void

    private let brown = Color.alcoveInk
    private let cream = Color.alcoveSurface

    private let yellow = Color.alcovePrimaryFill
    private let yellowHighlight = Color.alcovePrimaryHighlight
    private let orange = Color.alcovePrimaryShadow

    private let cancelFill = Color.alcoveSurfaceElevated
    private let cancelHighlight = Color.alcoveSecondaryHighlight
    private let cancelShadow = Color.alcoveSecondaryShadow

    var body: some View {
        VStack(spacing: 0) {
            Text("Are you done scanning?")
                .font(.custom("Cleanow", size: 28, relativeTo: .title))
                .foregroundStyle(brown)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            Text("Make sure you have fully scanned the whole room to receive maximum results.")
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundStyle(brown)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)

            HStack(spacing: 22) {
                alertButton(title: "No", isPrimary: false, action: onNo)
                alertButton(title: "Yes", isPrimary: true, action: onYes)
            }
            .padding(.top, 26)
        }
        .padding(.horizontal, 36)
        .padding(.top, 42)
        .padding(.bottom, 34)
        .frame(width: 440)
        .background {
            RoundedRectangle(cornerRadius: 50)
                .fill(cream)
                .background(alignment: .top) {
                    Image("EditOtterHead")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 190)
                        .offset(y: -116)
                        .allowsHitTesting(false)
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 50)
                .strokeBorder(brown, lineWidth: 5)
        }
        .overlay(alignment: .top) {
            Image("OtterPaws")
                .resizable()
                .scaledToFit()
                .frame(width: 140)
                .offset(x: 7, y: -15)
                .allowsHitTesting(false)
        }
        .padding(.top, 130)
    }

    private func alertButton(
        title: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let mainColor = isPrimary ? yellow : cancelFill
        let topColor = isPrimary ? yellowHighlight : cancelHighlight
        let bottomColor = isPrimary ? orange : cancelShadow

        return Button(action: action) {
            Text(title)
                .font(.custom("Cleanow", size: 24, relativeTo: .title3))
                .foregroundStyle(brown)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background {
                    GeometryReader { geometry in
                        let border: CGFloat = 4
                        let band: CGFloat = 6

                        ZStack {
                            Capsule()
                                .fill(brown)

                            Capsule()
                                .fill(bottomColor)
                                .padding(border)

                            Capsule()
                                .fill(topColor)
                                .padding(.horizontal, border)
                                .padding(.top, border)
                                .padding(.bottom, border + band)
                                .mask(alignment: .top) {
                                    Rectangle()
                                        .frame(height: geometry.size.height * 0.52)
                                }

                            Capsule()
                                .fill(mainColor)
                                .padding(.horizontal, border)
                                .padding(.top, border + band)
                                .padding(.bottom, border + band)

                            Capsule()
                                .strokeBorder(brown, lineWidth: border)
                        }
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
