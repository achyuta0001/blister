import SwiftUI

/// Renders the ``AisleVerdict`` at arm's-length scale (spec §6.1, §7). Owned by Agent 4.
///
/// The giant verdict word is the whole point: readable in bad shop lighting, one-handed. Everything
/// else — photo, colorway chips, one-tap actions — hangs off it. Pure presentation; all mutations are
/// delegated back to the parent through the callbacks.
struct VerdictDisplay: View {
    let verdict: AisleVerdict
    let onAddOwned: () -> Void
    let onAddWanted: () -> Void
    let onClearScan: () -> Void

    /// Scales with Dynamic Type but starts very large.
    @ScaledMetric(relativeTo: .largeTitle) private var verdictSize: CGFloat = 50

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingL) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.spacingM)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder private var content: some View {
        switch verdict {
        case .idle:
            idle
        case let .inCollection(primary, ownedCastings):
            headline(String(localized: "IN COLLECTION"), symbol: "checkmark.circle.fill")
            matchCard(primary: primary, castings: ownedCastings,
                      castingLabel: String(localized: "Owned colorways"))
        case let .onWishlist(primary, wantedCastings):
            headline(String(localized: "ON YOUR WISHLIST"), symbol: "star.circle.fill")
            note(String(localized: "Not owned yet — you flagged this casting to hunt for."))
            matchCard(primary: primary, castings: wantedCastings,
                      castingLabel: String(localized: "Wishlisted colorways"))
        case let .notInCollection(query, catalogHint):
            headline(String(localized: "NOT IN COLLECTION"), symbol: "xmark.circle")
            queryEcho(query)
            if let catalogHint {
                catalogHintCard(catalogHint)
            }
            addActions
        case let .barcodeHint(matches):
            headline(String(localized: "POSSIBLE MATCH"), symbol: "barcode.viewfinder")
            note(String(localized: "Barcodes are often shared across a whole assortment, so this is a hint — check the colorway against the car in your hand."))
            ForEach(matches) { car in
                candidateRow(car)
            }
            clearScanButton
        case let .barcodeMiss(barcode):
            headline(String(localized: "NO BARCODE MATCH"), symbol: "barcode.viewfinder")
            note(String(localized: "Nothing on file for this barcode. Barcodes are shared across assortments, so type the casting name to be sure."))
            Text(barcode)
                .font(.footnote.monospaced())
                .foregroundStyle(DesignTokens.secondaryText)
            addActions
            clearScanButton
        }
    }

    // MARK: - Pieces

    private var idle: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
            Text(String(localized: "Aisle Check"))
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                .tracking(DesignTokens.headingTracking)
                .foregroundStyle(DesignTokens.primaryText)
            Text(String(localized: "Type a casting name — or scan a barcode — to know in three seconds whether it is already yours."))
                .font(.body)
                .foregroundStyle(DesignTokens.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DesignTokens.spacingL)
    }

    private func headline(_ text: String, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spacingS) {
            Image(systemName: symbol)
                .font(.system(size: verdictSize * 0.42, weight: .bold))
            Text(text)
                .font(.system(size: verdictSize, weight: .heavy, design: .rounded))
                .tracking(DesignTokens.headingTracking)
                .minimumScaleFactor(0.5)
                .allowsTightening(true)
                .lineLimit(2)
        }
        .foregroundStyle(DesignTokens.primaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(Text(text))
    }

    private func matchCard(primary: Car, castings: [Car], castingLabel: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingM) {
            HStack(alignment: .top, spacing: DesignTokens.spacingM) {
                photo(for: primary)
                    .frame(width: 132, height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(DesignTokens.hairline, lineWidth: 1))
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text(primary.castingName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DesignTokens.primaryText)
                    Text(primary.brand.displayName)
                        .font(.subheadline)
                        .foregroundStyle(DesignTokens.secondaryText)
                    if let series = primary.series, !series.isEmpty {
                        Text(series)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.secondaryText)
                    }
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
                Text(castingLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.secondaryText)
                    .textCase(.uppercase)
                colorwayChips(castings)
            }
        }
    }

    private func colorwayChips(_ cars: [Car]) -> some View {
        // A simple wrapping row is overkill here; a vertical list keeps each colorway legible at
        // arm's length, which is the point.
        VStack(alignment: .leading, spacing: DesignTokens.spacingS) {
            ForEach(cars) { car in
                HStack(spacing: DesignTokens.spacingS) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(DesignTokens.secondaryText)
                    Text(colorwayText(for: car))
                        .font(.body.weight(.medium))
                        .foregroundStyle(DesignTokens.primaryText)
                    if let badge = car.huntStatus.badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .overlay(Capsule().stroke(DesignTokens.hairline, lineWidth: 1))
                            .foregroundStyle(DesignTokens.secondaryText)
                    }
                }
                .padding(.horizontal, DesignTokens.spacingM)
                .padding(.vertical, DesignTokens.spacingS)
                .frame(minHeight: DesignTokens.minTapTarget, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DesignTokens.background)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(DesignTokens.hairline, lineWidth: 1))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func candidateRow(_ car: Car) -> some View {
        HStack(spacing: DesignTokens.spacingM) {
            photo(for: car)
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(DesignTokens.hairline, lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(car.castingName)
                    .font(.headline)
                    .foregroundStyle(DesignTokens.primaryText)
                Text(colorwayText(for: car))
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.secondaryText)
                Text(car.status.displayName)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: DesignTokens.minTapTarget)
        .accessibilityElement(children: .combine)
    }

    private var addActions: some View {
        VStack(spacing: DesignTokens.spacingS) {
            Button(action: onAddOwned) {
                actionLabel(String(localized: "Add to Garage"), symbol: "plus.square.fill.on.square.fill", filled: true)
            }
            Button(action: onAddWanted) {
                actionLabel(String(localized: "Add to Wishlist"), symbol: "star", filled: false)
            }
        }
    }

    private func actionLabel(_ title: String, symbol: String, filled: Bool) -> some View {
        HStack {
            Image(systemName: symbol)
            Text(title).font(.headline)
        }
        .frame(maxWidth: .infinity, minHeight: DesignTokens.minTapTarget)
        .padding(.vertical, DesignTokens.spacingS)
        .foregroundStyle(filled ? DesignTokens.background : DesignTokens.primaryText)
        .background(filled ? DesignTokens.primaryText : DesignTokens.background)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DesignTokens.hairline, lineWidth: filled ? 0 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var clearScanButton: some View {
        Button(action: onClearScan) {
            Text(String(localized: "Back to typing"))
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: DesignTokens.minTapTarget)
                .foregroundStyle(DesignTokens.secondaryText)
        }
    }

    /// A "known casting" hint drawn from the bundled catalog when a miss still matches reference data.
    /// Reassures the user this is a real casting and shows a typical India price.
    private func catalogHintCard(_ entry: CatalogEntry) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
            HStack(spacing: DesignTokens.spacingS) {
                Image(systemName: "book.closed")
                    .foregroundStyle(DesignTokens.secondaryText)
                Text(String(localized: "Known casting"))
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
            Text(entry.castingName)
                .font(.headline)
                .foregroundStyle(DesignTokens.primaryText)
            Text(catalogHintDetail(entry))
                .font(.subheadline)
                .foregroundStyle(DesignTokens.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.spacingM)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(DesignTokens.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func catalogHintDetail(_ entry: CatalogEntry) -> String {
        var parts = [entry.brand.displayName]
        if let series = entry.series, !series.isEmpty { parts.append(series) }
        let head = parts.joined(separator: " · ")
        guard let price = entry.priceINR else { return head }
        return String(localized: "\(head) · typical ≈ ₹\(price)")
    }

    private func queryEcho(_ query: String) -> some View {
        Text(verbatim: "“\(query)”")
            .font(.title3.weight(.medium))
            .foregroundStyle(DesignTokens.secondaryText)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(DesignTokens.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func photo(for car: Car) -> some View {
        if let first = car.photoFilenames.first,
           let image = DocumentsPhotoStore.shared.thumbnail(for: first) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            TypographicPlaceholder(castingName: car.castingName, brand: car.brand)
        }
    }

    private func colorwayText(for car: Car) -> String {
        if let colorway = car.colorway?.trimmingCharacters(in: .whitespacesAndNewlines),
           !colorway.isEmpty {
            return colorway
        }
        return String(localized: "No colorway recorded")
    }
}
