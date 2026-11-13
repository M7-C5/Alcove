import SwiftUI

/// Catalog sheet used for both adding new furniture and swapping an existing item in Stage 2.
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
        NavigationStack {
            VStack(spacing: 16) {
                categoryFilterBar

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                        ForEach(filteredItems) { item in
                            catalogCard(for: item)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .padding(.top, 12)
            .background(Color.alcoveBackground)
            .navigationTitle(swapTarget.map { "Swap \($0.name)" } ?? "Add Furniture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onDismiss)
                        .foregroundStyle(Color.alcoveInk)
                }
            }
        }
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
            .padding(.horizontal, 20)
        }
    }

    private func filterChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.alcoveInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(
                    isSelected ? Color.alcovePrimaryFill : Color.alcoveSurface,
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .stroke(Color.alcoveInk.opacity(isSelected ? 0.55 : 0.16), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func catalogCard(for item: FurnitureCatalogItem) -> some View {
        Button {
            onSelectItem(item)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: item.category.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.alcoveInk)
                        .frame(width: 40, height: 40)
                        .background(Color.alcoveBackground, in: Circle())

                    Spacer()

                    Text(item.category.rawValue.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.alcoveMutedInk)
                }

                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(Color.alcoveInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(String(format: "%.1fm × %.1fm × %.1fm", item.width, item.length, item.height))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.alcoveMutedInk)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(Color.alcoveSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.alcoveInk.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.name), \(item.category.rawValue), \(String(format: "%.1f by %.1f meters", item.width, item.length))")
    }
}
