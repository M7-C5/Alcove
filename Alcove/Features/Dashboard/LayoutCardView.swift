import SwiftUI
import UIKit

struct LayoutCardView: View {

    let layoutID: UUID
    let layoutName: String
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @Binding var openMenuLayoutID: UUID?

    private var isMenuOpen: Bool {
        openMenuLayoutID == layoutID
    }

    // Design system colors
    private let brown = Color.alcoveInk
    private let orange = Color.alcovePrimaryShadow
    private let cream = Color.alcoveCardBackground

    private let badgeGold = Color.alcoveBadgeGold
    private let thumbnailSurface = Color.alcoveSurfaceElevated

    private var badgeWidth: CGFloat {
        cardWidth * 0.22
    }

    private var badgeHeight: CGFloat {
        cardWidth * 0.18
    }

    var body: some View {
        ZStack {

            // Main room card
            Button(action: onTap) {
                VStack(spacing: 0) {

                    roomThumbnail
                        .frame(height: cardHeight * 0.70)
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: cardWidth * 0.15
                            )
                        )
                        .padding(.horizontal, cardWidth * 0.05)
                        .padding(.top, cardHeight * 0.07)

                    Spacer(minLength: 0)

                    HStack(spacing: 12) {
                        Text(layoutName)
                            .font(
                                .custom(
                                    "Cleanow",
                                    size: cardWidth * 0.058,
                                    relativeTo: .headline
                                )
                            )
                            .foregroundStyle(brown)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Spacer()

                        Color.clear
                            .frame(width: 40, height: 40)
                    }
                    .padding(.horizontal, cardWidth * 0.095)
                    .frame(height: cardHeight * 0.18)
                    .offset(y: -19)
                }
                .frame(width: cardWidth, height: cardHeight)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 95)
                            .fill(brown)

                        RoundedRectangle(cornerRadius: 88)
                            .fill(orange)
                            .padding(7)

                        RoundedRectangle(cornerRadius: 81)
                            .fill(cream)
                            .padding(14)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(layoutName)")

            // Three-dot button
            Button {
                withAnimation(
                    .spring(
                        response: 0.28,
                        dampingFraction: 0.82
                    )
                ) {
                    openMenuLayoutID = isMenuOpen ? nil : layoutID
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(brown)
                    .frame(width: 52, height: 52)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(
                x: cardWidth * 0.865,
                y: cardHeight * 0.872
            )

            // Floating edit/delete menu
            if isMenuOpen {
                VStack(alignment: .leading, spacing: 0) {

                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            openMenuLayoutID = nil
                        }
                        onEdit()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .frame(height: 52)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            openMenuLayoutID = nil
                        }
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .frame(
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .frame(height: 52)
                    }
                }
                .font(
                    .system(
                        .body,
                        design: .rounded,
                        weight: .medium
                    )
                )
                .foregroundStyle(brown)
                .padding(.horizontal, 18)
                .padding(.vertical, 4)
                .frame(width: 230)
                .background(
                    Color.alcoveSurface,
                    in: RoundedRectangle(cornerRadius: 28)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 28)
                        .strokeBorder(brown, lineWidth: 2.5)
                }
                .buttonStyle(.plain)
                .position(
                    x: cardWidth * 0.865 + 26 - 115,
                    y: cardHeight * 0.872 - 26
                )
                .transition(
                    .opacity.combined(
                        with: .scale(scale: 0.95)
                    )
                )
                .zIndex(2)
            }

        }
        .frame(width: cardWidth, height: cardHeight)

        // Otter head behind card
        .background(alignment: .top) {
            Image("EditOtterHead")
                .resizable()
                .scaledToFit()
                .frame(width: cardWidth * 0.30)
                .offset(
                    x: -cardWidth * 0.23,
                    y: -cardWidth * 0.18
                )
                .allowsHitTesting(false)
        }

        // Otter paws above card border
        .overlay(alignment: .top) {
            Image("OtterPaws")
                .resizable()
                .scaledToFit()
                .frame(width: cardWidth * 0.22)
                .offset(
                    x: -cardWidth * 0.22,
                    y: -cardWidth * 0.019
                )
                .allowsHitTesting(false)
        }
    }

    // Room thumbnail
    @ViewBuilder
    private var roomThumbnail: some View {
        if UIImage(named: "RoomThumbnail") != nil {
            Image("RoomThumbnail")
                .resizable()
                .scaledToFill()
                .frame(
                    width: cardWidth * 0.90,
                    height: cardHeight * 0.70
                )
                .clipped()
        } else {
            Rectangle()
                .fill(thumbnailSurface)
                .overlay {
                    Image(systemName: "bed.double.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(brown.opacity(0.25))
                }
        }
    }
}

#Preview("Alcove Room Card") {

    @Previewable @State var openMenu: UUID? = nil

    ZStack {
        Color.alcoveBackground
            .ignoresSafeArea()

        LayoutCardView(
            layoutID: UUID(),
            layoutName: "M's Bedroom",
            cardWidth: 570,
            cardHeight: 530,
            onTap: {},
            onEdit: {},
            onDelete: {},
            openMenuLayoutID: $openMenu
        )
    }
}
