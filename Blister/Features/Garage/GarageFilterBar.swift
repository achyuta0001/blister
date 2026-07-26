import SwiftUI

/// Horizontally scrolling row of filter + sort chips (spec §6.2). Series and year options are
/// derived from the cars actually in the collection, so the bar never offers an empty filter.
struct GarageFilterBar: View {
    @Bindable var filters: GarageFilters
    let seriesOptions: [String]
    let yearOptions: [Int]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.spacingS) {
                sortChip
                brandChip
                huntChip
                conditionChip
                if !seriesOptions.isEmpty { seriesChip }
                if !yearOptions.isEmpty { yearChip }
                if filters.isActive { clearChip }
            }
            .padding(.horizontal, DesignTokens.spacingM)
            .padding(.vertical, DesignTokens.spacingXS)
        }
        .background(DesignTokens.background)
    }

    // MARK: Sort

    private var sortChip: some View {
        Menu {
            Picker(selection: $filters.sort) {
                ForEach(GarageSortOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            } label: { EmptyView() }
        } label: {
            GarageChipLabel(
                title: filters.sort.label,
                systemImage: "arrow.up.arrow.down"
            )
        }
        .accessibilityLabel(Text(String(localized: "Sort")))
        .accessibilityValue(Text(filters.sort.label))
    }

    // MARK: Filters

    private var brandChip: some View {
        Menu {
            Picker(selection: $filters.brand) {
                Text(String(localized: "All Brands")).tag(Brand?.none)
                ForEach(Brand.allCases) { brand in
                    Text(brand.displayName).tag(Brand?.some(brand))
                }
            } label: { EmptyView() }
        } label: {
            GarageChipLabel(
                title: filters.brand?.displayName ?? String(localized: "Brand"),
                isSelected: filters.brand != nil
            )
        }
        .accessibilityLabel(Text(String(localized: "Filter by brand")))
    }

    /// Nothing else in the app says what a Treasure Hunt is, so the filter that sorts by them says
    /// it. A disabled row, not a bare `Text` or a `Section` footer: a `Menu` is backed by a `UIMenu`,
    /// which lays out only real menu items. It also clips a row to two narrow lines — measured at
    /// roughly 40 characters — so the wording is kept short enough to survive intact.
    private var huntExplainer: some View {
        Button {} label: {
            Label(
                String(localized: "TH / $TH: rare cars hidden in cases."),
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundStyle(DesignTokens.secondaryText)
        }
        .disabled(true)
    }

    private var huntChip: some View {
        Menu {
            Picker(selection: $filters.huntStatus) {
                Text(String(localized: "All Hunts")).tag(HuntStatus?.none)
                ForEach(HuntStatus.allCases) { hunt in
                    Text(hunt.displayName).tag(HuntStatus?.some(hunt))
                }
            } label: { EmptyView() }
            huntExplainer
        } label: {
            GarageChipLabel(
                title: filters.huntStatus?.displayName ?? String(localized: "Hunt"),
                isSelected: filters.huntStatus != nil
            )
        }
        .accessibilityLabel(Text(String(localized: "Filter by hunt status")))
    }

    private var conditionChip: some View {
        Menu {
            Picker(selection: $filters.condition) {
                Text(String(localized: "All Conditions")).tag(Condition?.none)
                ForEach(Condition.allCases) { condition in
                    Text(condition.displayName).tag(Condition?.some(condition))
                }
            } label: { EmptyView() }
        } label: {
            GarageChipLabel(
                title: filters.condition?.displayName ?? String(localized: "Condition"),
                isSelected: filters.condition != nil
            )
        }
        .accessibilityLabel(Text(String(localized: "Filter by condition")))
    }

    private var seriesChip: some View {
        Menu {
            Picker(selection: $filters.series) {
                Text(String(localized: "All Series")).tag(String?.none)
                ForEach(seriesOptions, id: \.self) { series in
                    Text(series).tag(String?.some(series))
                }
            } label: { EmptyView() }
        } label: {
            GarageChipLabel(
                title: filters.series ?? String(localized: "Series"),
                isSelected: filters.series != nil
            )
        }
        .accessibilityLabel(Text(String(localized: "Filter by series")))
    }

    private var yearChip: some View {
        Menu {
            Picker(selection: $filters.year) {
                Text(String(localized: "All Years")).tag(Int?.none)
                ForEach(yearOptions, id: \.self) { year in
                    Text(String(year)).tag(Int?.some(year))
                }
            } label: { EmptyView() }
        } label: {
            GarageChipLabel(
                title: filters.year.map(String.init) ?? String(localized: "Year"),
                isSelected: filters.year != nil
            )
        }
        .accessibilityLabel(Text(String(localized: "Filter by year")))
    }

    private var clearChip: some View {
        Button {
            filters.clear()
        } label: {
            GarageChipLabel(
                title: String(localized: "Clear"),
                systemImage: "xmark"
            )
        }
        .accessibilityLabel(Text(String(localized: "Clear all filters")))
    }
}
