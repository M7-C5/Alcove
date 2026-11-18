import SwiftUI

private enum CatalogFigmaPalette {
    static let borderBrown = Color(red: 0x6D / 255.0, green: 0x45 / 255.0, blue: 0x31 / 255.0)
    static let panelPeach = Color(red: 0xFE / 255.0, green: 0xEE / 255.0, blue: 0xDE / 255.0)
    static let cardCream = Color(red: 0xFF / 255.0, green: 0xFB / 255.0, blue: 0xF5 / 255.0)
    static let goldHighlight = Color(red: 0xFB / 255.0, green: 0xEA / 255.0, blue: 0xB6 / 255.0)
    static let goldFace = Color(red: 0xFB / 255.0, green: 0xD4 / 255.0, blue: 0x60 / 255.0)
    static let goldLip = Color(red: 0xFC / 255.0, green: 0xA6 / 255.0, blue: 0x0F / 255.0)
    static let creamHighlight = Color(red: 0xF9 / 255.0, green: 0xE4 / 255.0, blue: 0xC9 / 255.0)
    static let creamFace = Color(red: 0xFF / 255.0, green: 0xF7 / 255.0, blue: 0xE7 / 255.0)
    static let creamLip = Color(red: 0xE9 / 255.0, green: 0xC7 / 255.0, blue: 0x9D / 255.0)
}

/// Floating catalog popover used for both adding new furniture and swapping an existing item in Stage 2.
public struct FurnitureCatalogSheet: View {
    public let swapTarget: Furniture?
    public let onSelectItem: (FurnitureCatalogItem) -> Void
    public let onDismiss: () -> Void

    @State private var selectedCategory: FurnitureCategory?

    private static let availableCategories: [FurnitureCategory] = [
        .bed, .table, .seating, .storage, .lighting
    ]

    public init(
        swapTarget: Furniture?,
        onSelectItem: @escaping (FurnitureCatalogItem) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.swapTarget = swapTarget
        self.onSelectItem = onSelectItem
        self.onDismiss = onDismiss
        _selectedCategory = State(initialValue: swapTarget?.category)
    }

    private var filteredItems: [FurnitureCatalogItem] {
        FurnitureCatalog.presets(for: selectedCategory)
    }

    public var body: some View {
        VStack(spacing: 14) {
            Text(swapTarget.map { "Swap \($0.name)" } ?? "Add Furniture")
                .font(.custom("Cleanow", size: 20, relativeTo: .headline))
                .foregroundStyle(CatalogFigmaPalette.borderBrown)
                .padding(.top, 18)

            categoryFilterBar

            ScrollView(showsIndicators: false) {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(filteredItems) { item in
                        catalogCard(for: item)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
            }
            .frame(maxHeight: 270)
        }
        .frame(width: 390)
        .background(CatalogFigmaPalette.panelPeach)
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(Self.availableCategories, id: \.self) { category in
                    filterChip(
                        title: category.rawValue.capitalized,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 18)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let topHighlight = isSelected ? CatalogFigmaPalette.goldHighlight : CatalogFigmaPalette.creamHighlight
        let face = isSelected ? CatalogFigmaPalette.goldFace : CatalogFigmaPalette.creamFace
        let bottomLip = isSelected ? CatalogFigmaPalette.goldLip : CatalogFigmaPalette.creamLip

        return Button(action: action) {
            Text(title)
                .font(.custom("Cleanow", size: 15, relativeTo: .subheadline))
                .foregroundStyle(CatalogFigmaPalette.borderBrown)
                .padding(.horizontal, 16)
                .frame(minHeight: 38)
                .background {
                    ZStack {
                        Capsule()
                            .fill(CatalogFigmaPalette.borderBrown)

                        ZStack {
                            VStack(spacing: 0) {
                                topHighlight
                                bottomLip
                            }

                            Capsule()
                                .fill(face)
                                .padding(.top, 1.5)
                                .padding(.bottom, 3)
                        }
                        .clipShape(Capsule())
                        .padding(2)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
    }

    private func catalogCard(for item: FurnitureCatalogItem) -> some View {
        Button {
            onSelectItem(item)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: item.category.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CatalogFigmaPalette.borderBrown)

                    Text(item.category.rawValue.capitalized)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(CatalogFigmaPalette.borderBrown)
                }

                Text(item.name)
                    .font(.custom("Cleanow", size: 16, relativeTo: .subheadline))
                    .foregroundStyle(CatalogFigmaPalette.borderBrown)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(String(format: "%.1fm x %.1fm x %.1fm", item.width, item.length, item.height))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(CatalogFigmaPalette.borderBrown)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
            .background(
                CatalogFigmaPalette.cardCream,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(CatalogFigmaPalette.borderBrown, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name), \(item.category.rawValue), \(String(format: "%.1f by %.1f meters", item.width, item.length))")
    }
}
