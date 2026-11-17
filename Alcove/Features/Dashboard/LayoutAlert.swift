import SwiftUI

struct LayoutAlert: View {

    enum AlertType {
        case edit
        case delete
    }

    let type: AlertType
    @Binding var layoutName: String

    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var hasTypedName = false

    // Design system colors
    private let brown = Color.alcoveInk
    private let cream = Color.alcoveSurface

    // Save/Yes button
    private let yellow = Color.alcovePrimaryFill
    private let yellowHighlight = Color.alcovePrimaryHighlight
    private let orange = Color.alcovePrimaryShadow

    // Cancel/No button
    private let cancelFill = Color.alcoveSurfaceElevated
    private let cancelHighlight = Color.alcoveSecondaryHighlight
    private let cancelShadow = Color.alcoveSecondaryShadow

    // Text field
    private let placeholderColor = Color.alcovePlaceholderText

    private var isEditing: Bool {
        type == .edit
    }

    private var otterHeadAsset: String {
        isEditing ? "EditOtterHead" : "DeleteOtterHead"
    }

    private var alertTitle: String {
        if isEditing {
            return "Edit name"
        } else {
            return "Are you sure you want to delete \n\(layoutName)?"
        }
    }

    // Alert Container
    var body: some View {
        VStack(spacing: 0) {

            // Heading
            Text(alertTitle)
                .font(
                    .custom(
                        "Cleanow",
                        size: isEditing ? 30 : 27,
                        relativeTo: .title
                    )
                )
                .foregroundStyle(brown)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)

            // Description
            Text(
                isEditing
                    ? "Enter a name for this layout."
                    : "Your changes would not be saved."
            )
            .font(
                .system(
                    .title2,
                    design: .rounded,
                    weight: .semibold
                )
            )
            .foregroundStyle(brown)
            .multilineTextAlignment(.center)
            .padding(.top, 16)

            // Text field for Edit only
            if isEditing {
                TextField(
                    "Room name",
                    text: $layoutName,
                    prompt: Text("Room name")
                        .foregroundColor(placeholderColor)
                )
                .font(
                    .system(
                        .title2,
                        design: .rounded,
                        weight: .semibold

                    )
                )
                .foregroundStyle(
                    hasTypedName ? brown : placeholderColor
                )
                .padding(.horizontal, 32)
                .frame(height: 68)
                .background(
                    cancelFill,
                    in: Capsule()
                )
                .textInputAutocapitalization(.words)
                .onChange(of: layoutName) { _, _ in
                    hasTypedName = true
                }
                .padding(.top, 26)
            }

            // Action buttons
            HStack(spacing: 22) {

                alertButton(
                    title: isEditing ? "Cancel" : "No",
                    isPrimary: false,
                    action: onCancel
                )

                alertButton(
                    title: isEditing ? "Save" : "Yes",
                    isPrimary: true,
                    action: onConfirm
                )
            }
            .padding(.top, 28)
        }
        .padding(.horizontal, 36)
        .padding(.top, 42)
        .padding(.bottom, 36)
        .frame(width: isEditing ? 450 : 431)

        // Alert background & otter
        .background {
            RoundedRectangle(cornerRadius: 50)
                .fill(cream)
                .background(alignment: .top) {

                    // Otter head BEHIND the alert
                    Image(otterHeadAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 190)
                        .offset(y: -116)
                        .allowsHitTesting(false)
                }
        }

        // Brown border IN FRONT of the head
        .overlay {
            RoundedRectangle(cornerRadius: 50)
                .strokeBorder(brown, lineWidth: 5)
        }

        // Otter paws IN FRONT of the border
        .overlay(alignment: .top) {
            Image("OtterPaws")
                .resizable()
                .scaledToFit()
                .frame(width: 140)
                .offset(x: 7, y: -15)
                .allowsHitTesting(false)
        }

        .padding(.top, 145)

    }  // Closes var body

    // Reusable buttons
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
                            // Brown outer base
                            Capsule()
                                .fill(brown)

                            // Bottom highlight/shadow band
                            Capsule()
                                .fill(bottomColor)
                                .padding(border)

                            // Top light highlight
                            Capsule()
                                .fill(topColor)
                                .padding(.horizontal, border)
                                .padding(.top, border)
                                .padding(.bottom, border + band)
                                .mask(alignment: .top) {
                                    Rectangle()
                                        .frame(
                                            height: geometry.size.height * 0.52
                                        )
                                }

                            // Main fill
                            Capsule()
                                .fill(mainColor)
                                .padding(.horizontal, border)
                                .padding(.top, border + band)
                                .padding(.bottom, border + band)

                            // Brown outline
                            Capsule()
                                .strokeBorder(
                                    brown,
                                    lineWidth: border
                                )
                        }
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

#Preview("Edit Alert") {
    @Previewable @State var name = "S's Bedroom"

    ZStack {
        Color.black.opacity(0.7)
            .ignoresSafeArea()

        LayoutAlert(
            type: .edit,
            layoutName: $name,
            onCancel: {},
            onConfirm: {}
        )
    }
}

#Preview("Delete Alert") {
    @Previewable @State var name = "S's Bedroom"

    ZStack {
        Color.black.opacity(0.7)
            .ignoresSafeArea()

        LayoutAlert(
            type: .delete,
            layoutName: $name,
            onCancel: {},
            onConfirm: {}
        )
    }
}
