import SwiftUI
import UIKit

public struct DashboardView: View {

    // Temporary data
    @State private var layouts: [String]
    @State private var centeredLayout: String?

    // Rename & delete
    @State private var layoutToRename: String?
    @State private var newLayoutName = ""
    @State private var layoutToDelete: String?

    @State private var openMenuLayout: String?

    // Scan integration
    private let onStartScanning: () -> Void

    // Design system colors
    private let brown = Color("AlcoveInk")
    private let yellow = Color("AlcovePrimaryFill")
    private let backgroundCream = Color("AlcoveBackground")

    private let buttonShadow = Color("AlcovePrimaryShadow")
    private let buttonHighlight = Color("AlcovePrimaryHighlight")

    private let cardSpacing: CGFloat = 32

    // Initializer
    public init(
        layouts: [String] = [],
        onStartScanning: @escaping () -> Void = {}
    ) {
        _layouts = State(initialValue: layouts)
        self.onStartScanning = onStartScanning
    }

    // Body
    public var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {

                    // Background
                    dashboardBackground
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                openMenuLayout = nil
                            }
                        }

                    // Main content
                    if layouts.isEmpty {
                        emptyStateView
                    } else {
                        filledStateView(
                            availableSize: geometry.size
                        )
                    }

                    // Header
                    VStack {
                        headerView
                        Spacer()
                    }

                    // Bottom button
                    VStack {
                        Spacer()
                        startScanningButton
                            .padding(.bottom, 48)
                    }
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
                .overlay {
                    ZStack {

                        // Dimmed background
                        if layoutToRename != nil || layoutToDelete != nil {
                            Color.black.opacity(0.30)
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        layoutToRename = nil
                                        layoutToDelete = nil
                                    }
                                }
                                .transition(.opacity)
                        }

                        // Edit Name alert
                        if layoutToRename != nil {
                            LayoutAlert(
                                type: .edit,
                                layoutName: $newLayoutName,
                                onCancel: {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        layoutToRename = nil
                                    }
                                },
                                onConfirm: {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        renameLayout()
                                    }
                                }
                            )
                            .offset(y: -55)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(
                                        with: .scale(scale: 0.92)
                                    ),
                                    removal: .opacity.combined(
                                        with: .scale(scale: 0.97)
                                    )
                                )
                            )
                        }

                        // Delete confirmation alert
                        if let roomName = layoutToDelete {
                            LayoutAlert(
                                type: .delete,
                                layoutName: .constant(roomName),
                                onCancel: {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        layoutToDelete = nil
                                    }
                                },
                                onConfirm: {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        deleteLayout()
                                    }
                                }

                            )
                            .offset(y: -55)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(
                                        with: .scale(scale: 0.92)
                                    ),
                                    removal: .opacity.combined(
                                        with: .scale(scale: 0.97)
                                    )
                                )
                            )
                        }
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
    }

    // Background
    @ViewBuilder
    private var dashboardBackground: some View {
        GeometryReader { geometry in
            Image("DashboardPattern")
                .resizable()
                .scaledToFill()
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
                .clipped()
        }
        .ignoresSafeArea()
    }

    // Header
    private var headerView: some View {
        HStack(alignment: .top) {

            Text("Rooms")
                .font(.custom("Cleanow", size: 36, relativeTo: .largeTitle))
                .foregroundStyle(brown)

            Spacer()
        }
        .padding(.horizontal, 34)
        .padding(.top, 18)
    }

    // Empty state
    private var emptyStateView: some View {
        VStack(spacing: 0) {

            Image(systemName: "square.split.bottomrightquarter")
                .font(.system(size: 55))
                .foregroundStyle(Color("AlcoveEmptyStateText"))
                .padding(.bottom, 15)

            Text("No Layout Yet.")
                .font(.custom("Cleanow", size: 30, relativeTo: .title))
                .foregroundStyle(Color("AlcoveEmptyStateText"))
                .padding(.bottom, 6)

            Text(
                "Create a layout to start planning and arranging your room.\nTap the 'Start Scanning' button to get started."
            )
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .foregroundStyle(Color("AlcoveEmptyStateText"))
            .multilineTextAlignment(.center)
            .lineSpacing(9)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: -5)
    }

    // Filled state
    private func filledStateView(
        availableSize: CGSize
    ) -> some View {

        let cardWidth = min(
            600,
            availableSize.width * 0.46
        )

        let cardHeight = cardWidth * 0.94

        return ScrollView(.horizontal) {
            LazyHStack(spacing: cardSpacing) {

                ForEach(layouts, id: \.self) { layout in

                    LayoutCardView(
                        layoutName: layout,
                        cardWidth: cardWidth,
                        cardHeight: cardHeight,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                openMenuLayout = nil
                            }
                            // TODO: Connect to Stage 4
                        },

                        onEdit: {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                openMenuLayout = nil
                            }
                            newLayoutName = layout

                            withAnimation(
                                .spring(response: 0.34, dampingFraction: 0.86)
                            ) {
                                layoutToRename = layout
                            }
                        },

                        onDelete: {
                            openMenuLayout = nil

                            withAnimation(
                                .spring(response: 0.34, dampingFraction: 0.86)
                            ) {
                                layoutToDelete = layout
                            }
                        },
                        openMenuLayout: $openMenuLayout
                    )
                    .scrollTransition(
                        .interactive(timingCurve: .easeInOut),
                        axis: .horizontal
                    ) { content, phase in
                        content
                            .scaleEffect(1 - 0.07 * abs(phase.value))
                            .rotationEffect(.degrees(phase.value * 5))
                            .offset(y: 14 * abs(phase.value))
                    }
                    .id(layout)
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .onScrollPhaseChange { _, newPhase in
            if newPhase == .interacting || newPhase == .decelerating {
                guard openMenuLayout != nil else { return }

                withAnimation(.easeInOut(duration: 0.18)) {
                    openMenuLayout = nil
                }
            }
        }

        .scrollTargetBehavior(
            .viewAligned(
                limitBehavior: .always,
                anchor: .center
            )
        )
        .scrollPosition(id: $centeredLayout)
        .contentMargins(
            .horizontal,
            max(0, (availableSize.width - cardWidth) / 2),
            for: .scrollContent
        )

        .frame(
            height: cardHeight + 110
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .offset(y: -25)
        .onAppear {
            if centeredLayout == nil {
                centeredLayout = layouts.first
            }
        }
    }

    // Start scanning button
    private var startScanningButton: some View {
        Button {
            onStartScanning()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "viewfinder")
                    .font(.system(size: 28, weight: .bold))

                Text("Start Scanning")
                    .font(.custom("Cleanow", size: 36, relativeTo: .title))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Color("AlcoveInk"))
            .padding(.horizontal, 36)
            .frame(height: 87)
            .background {
                GeometryReader { geometry in
                    let border: CGFloat = 5
                    let band: CGFloat = 7

                    ZStack {
                        // Orange bottom shadow
                        Capsule()
                            .fill(Color("AlcovePrimaryShadow"))
                            .padding(border)

                        // Pale yellow top highlight
                        Capsule()
                            .fill(Color("AlcovePrimaryHighlight"))
                            .padding(.horizontal, border)
                            .padding(.top, border)
                            .padding(.bottom, border + band)
                            .mask(alignment: .top) {
                                Rectangle()
                                    .frame(height: geometry.size.height * 0.52)
                            }

                        // Main yellow surface
                        Capsule()
                            .fill(Color("AlcovePrimaryFill"))
                            .padding(.horizontal, border)
                            .padding(.top, border + band)
                            .padding(.bottom, border + band)

                        // Brown outer border
                        Capsule()
                            .strokeBorder(Color("AlcoveInk"), lineWidth: border)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start scanning a room")
    }

    // Rename logic
    private func renameLayout() {
        guard let oldName = layoutToRename else {
            return
        }

        let trimmedName =
            newLayoutName
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !trimmedName.isEmpty,
            let index = layouts.firstIndex(of: oldName),
            trimmedName == oldName || !layouts.contains(trimmedName)
        else {
            layoutToRename = nil
            return
        }

        layouts[index] = trimmedName

        if centeredLayout == oldName {
            centeredLayout = trimmedName
        }

        layoutToRename = nil
    }

    // Delete logic
    private func deleteLayout() {
        guard let layout = layoutToDelete else {
            return
        }

        layouts.removeAll { $0 == layout }

        if centeredLayout == layout {
            centeredLayout = layouts.first
        }

        layoutToDelete = nil
    }
}

#Preview("Empty Dashboard", traits: .landscapeRight) {
    DashboardView(layouts: [])
}

#Preview("One Room", traits: .landscapeRight) {
    DashboardView(layouts: [
        "M's Bedroom"
    ])
}

#Preview("Multiple Rooms", traits: .landscapeRight) {
    DashboardView(layouts: [
        "Living Room",
        "M's Bedroom",
        "J's Bedroom",
    ])
}

#Preview("Dashboard - Larger Text", traits: .landscapeRight) {
    DashboardView(
        layouts: [
            "Living Room",
            "M's Bedroom",
            "J's Bedroom",
        ]
    )
    .dynamicTypeSize(.accessibility1)
}
