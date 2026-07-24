import SwiftUI
import os

/// Inline edit for an existing car (spec §6.4). Edits are staged in local state and only written
/// back to the `Car` (and `searchKey` recomputed) on Save, so Cancel leaves the model untouched.
struct CarEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let car: Car

    @State private var castingName: String
    @State private var brand: Brand
    @State private var colorway: String
    @State private var series: String
    @State private var huntStatus: HuntStatus
    @State private var condition: Condition
    @State private var pricePaid: Decimal?
    @State private var purchaseLocation: String
    @State private var notes: String

    /// A cleaned image staged for save. Following the file's staged-edit pattern, the new file is
    /// written (and the old one deleted) only when the user taps Save; Cancel discards it.
    @State private var stagedCleanedImage: UIImage?
    /// True while `PhotoCleanup.cleaned` is running.
    @State private var isCleaning = false
    /// Set when a cleanup run found no subject, so the UI can show a brief inline note.
    @State private var noSubjectFound = false
    /// The (original, cleaned) pair to preview; non-nil drives the cleanup sheet.
    @State private var cleanupPreview: EditCleanupPreview?
    /// Non-nil when a save failed, so the user is told rather than the failure being swallowed.
    @State private var saveError: ErrorAlert?

    private let photoStore: PhotoStore = DocumentsPhotoStore.shared
    private let logger = Logger(subsystem: "app.blister", category: "CarEdit")

    init(car: Car) {
        self.car = car
        _castingName = State(initialValue: car.castingName)
        _brand = State(initialValue: car.brand)
        _colorway = State(initialValue: car.colorway ?? "")
        _series = State(initialValue: car.series ?? "")
        _huntStatus = State(initialValue: car.huntStatus)
        _condition = State(initialValue: car.condition)
        _pricePaid = State(initialValue: car.purchasePriceINR)
        _purchaseLocation = State(initialValue: car.purchaseLocation ?? "")
        _notes = State(initialValue: car.notes ?? "")
    }

    private var isValid: Bool {
        !castingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                Section(String(localized: "Details")) {
                    TextField(String(localized: "Casting name"), text: $castingName)
                    Picker(String(localized: "Brand"), selection: $brand) {
                        ForEach(Brand.allCases) { Text($0.displayName).tag($0) }
                    }
                    TextField(String(localized: "Colorway"), text: $colorway)
                    TextField(String(localized: "Series"), text: $series)
                    Picker(String(localized: "Hunt status"), selection: $huntStatus) {
                        ForEach(HuntStatus.allCases) { Text($0.displayName).tag($0) }
                    }
                    Picker(String(localized: "Condition"), selection: $condition) {
                        ForEach(Condition.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                Section(String(localized: "Purchase")) {
                    TextField(
                        String(localized: "Price paid (₹)"),
                        value: $pricePaid,
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .keyboardType(.decimalPad)
                    TextField(String(localized: "Where"), text: $purchaseLocation)
                }
                Section(String(localized: "Notes")) {
                    TextField(String(localized: "Notes"), text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .sheet(item: $cleanupPreview) { preview in
                CleanupPreviewView(
                    original: preview.original,
                    cleaned: preview.cleaned,
                    onUse: { stagedCleanedImage = $0 },
                    onKeepOriginal: {}
                )
            }
            .errorAlert($saveError)
            .scrollContentBackground(.hidden)
            .background(DesignTokens.background)
            .navigationTitle(String(localized: "Edit Car"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    // MARK: Photo

    /// Shows the car's current photo (or the staged cleaned one) and offers the same "Clean up photo"
    /// affordance as Add Car. Only shown when the car actually has a photo to work with.
    @ViewBuilder private var photoSection: some View {
        if let filename = car.photoFilenames.first {
            Section(String(localized: "Photo")) {
                if let image = stagedCleanedImage ?? photoStore.thumbnail(for: filename) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                cleanupRow(filename: filename)
            }
        }
    }

    @ViewBuilder private func cleanupRow(filename: String) -> some View {
        if isCleaning {
            HStack(spacing: DesignTokens.spacingS) {
                ProgressView()
                    .controlSize(.small)
                Text(String(localized: "Cleaning up…"))
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        } else {
            Button {
                cleanUpPhoto(filename: filename)
            } label: {
                Label(String(localized: "Clean up photo"), systemImage: "wand.and.stars")
                    .font(.subheadline)
                    .frame(minHeight: DesignTokens.minTapTarget, alignment: .leading)
            }
            .buttonStyle(.borderless)
        }
        if noSubjectFound {
            Text(String(localized: "No subject found — keeping the original photo."))
                .font(.caption)
                .foregroundStyle(DesignTokens.secondaryText)
        }
    }

    /// Loads the full current image, runs on-device cleanup, and previews a non-nil result. nil
    /// surfaces an inline note and changes nothing.
    private func cleanUpPhoto(filename: String) {
        guard !isCleaning, let original = photoStore.fullImage(for: filename) else { return }
        isCleaning = true
        noSubjectFound = false
        Task {
            let result = await PhotoCleanup.cleaned(original)
            isCleaning = false
            if let result {
                cleanupPreview = EditCleanupPreview(original: original, cleaned: result)
            } else {
                noSubjectFound = true
                logger.info("Photo cleanup found no subject; keeping original.")
            }
        }
    }

    private func save() {
        guard isValid else { return }
        let photoApplied = applyStagedPhotoIfNeeded()
        car.castingName = castingName.trimmingCharacters(in: .whitespacesAndNewlines)
        car.brand = brand
        car.colorway = Self.trimmedOrNil(colorway)
        car.series = Self.trimmedOrNil(series)
        car.huntStatus = huntStatus
        car.condition = condition
        car.purchasePriceINR = pricePaid
        car.purchaseLocation = Self.trimmedOrNil(purchaseLocation)
        car.notes = Self.trimmedOrNil(notes)
        car.dateModified = Date()
        car.recomputeSearchKey()
        do {
            try modelContext.save()
        } catch {
            logger.error("Edit save failed: \(error.localizedDescription, privacy: .public)")
            saveError = ErrorAlert(
                message: String(localized: "Your changes couldn’t be saved. Please try again.")
            )
            return
        }
        // Data saved; if the cleaned-photo swap failed, keep the sheet open so its alert is seen.
        guard photoApplied else { return }
        dismiss()
    }

    /// Persists a staged cleaned image: writes a new file, points `photoFilenames` at it, and deletes
    /// the old one. Returns `false` (and surfaces an alert) if the write failed, leaving the existing
    /// photo untouched and the staged image available for a retry.
    private func applyStagedPhotoIfNeeded() -> Bool {
        guard let cleaned = stagedCleanedImage else { return true }
        let oldFilename = car.photoFilenames.first
        do {
            let newFilename = try photoStore.save(cleaned)
            var updated = car.photoFilenames
            if updated.isEmpty {
                updated = [newFilename]
            } else {
                updated[0] = newFilename
            }
            car.photoFilenames = updated
            if let oldFilename {
                do {
                    try photoStore.delete(oldFilename)
                } catch {
                    logger.error("Old photo delete failed: \(error.localizedDescription, privacy: .public)")
                }
            }
            stagedCleanedImage = nil
            return true
        } catch {
            logger.error("Cleaned photo save failed: \(error.localizedDescription, privacy: .public)")
            saveError = ErrorAlert(
                message: String(localized: "The cleaned-up photo couldn’t be saved. Your other changes were kept.")
            )
            return false
        }
    }

    private static func trimmedOrNil(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Identifiable (original, cleaned) pair so a preview can drive `.sheet(item:)`.
    private struct EditCleanupPreview: Identifiable {
        let id = UUID()
        let original: UIImage
        let cleaned: UIImage
    }
}
