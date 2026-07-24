import SwiftUI
import SwiftData
import PhotosUI
import os

/// Add Car (spec §6.3). **Owned by Agent 3.**
///
/// Camera-first capture aimed at under 15 seconds per car: the view opens straight to the camera,
/// the user shoots / picks / skips a photo, then fills one short form where only the casting name is
/// required. Save inserts the car and returns to the previous screen; "Save and add another" keeps
/// the camera open for batch entry. Casting name, series, and colorway autocomplete from values
/// already in the collection. Present modally from a "+" toolbar button.
struct AddCarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allCars: [Car]

    @State private var model = AddCarModel()
    @State private var showCamera = false
    @State private var libraryItem: PhotosPickerItem?

    /// True while `PhotoCleanup.cleaned` is running for the captured image.
    @State private var isCleaning = false
    /// Set when a cleanup run found no subject, so the UI can show a brief inline note.
    @State private var noSubjectFound = false
    /// The (original, cleaned) pair to preview; non-nil drives the cleanup sheet.
    @State private var cleanupPreview: CleanupPreview?
    /// Non-nil when a save failed, so the user is told rather than the failure being swallowed.
    @State private var saveError: ErrorAlert?
    /// Non-nil while the duplicate-colorway confirmation is showing; carries the `addAnother` flag of
    /// the save the user tried, so confirming resumes the right save.
    @State private var pendingDuplicateAddAnother: Bool?

    private let photoStore: PhotoStore = DocumentsPhotoStore.shared
    private let recognizer = CardTextRecognizer()
    private let logger = Logger(subsystem: "app.blister", category: "AddCar")

    var body: some View {
        NavigationStack {
            Form {
                photoSection
                detailsSection
                purchaseSection
                addAnotherSection
            }
            .scrollContentBackground(.hidden)
            .background(DesignTokens.background)
            .navigationTitle(String(localized: "Add Car"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) { save(addAnother: false) }
                        .disabled(!model.isValid)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker(
                    onImage: { image in
                        model.capturedImage = image
                        showCamera = false
                    },
                    onCancel: { showCamera = false }
                )
                .ignoresSafeArea()
            }
            .sheet(item: $cleanupPreview) { preview in
                CleanupPreviewView(
                    original: preview.original,
                    cleaned: preview.cleaned,
                    onUse: { model.capturedImage = $0 },
                    onKeepOriginal: {}
                )
            }
            .errorAlert($saveError)
            .confirmationDialog(
                String(localized: "You already own this colorway"),
                isPresented: Binding(
                    get: { pendingDuplicateAddAnother != nil },
                    set: { presented in if !presented { pendingDuplicateAddAnother = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDuplicateAddAnother
            ) { addAnother in
                Button(String(localized: "Add anyway")) { performSave(addAnother: addAnother) }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: { _ in
                Text(String(localized: "A car with this casting and colorway is already in your garage. Add it anyway?"))
            }
            .onChange(of: libraryItem) { _, newItem in
                loadLibraryItem(newItem)
            }
            .onChange(of: model.capturedImage) { _, newImage in
                recognizeText(in: newImage)
                noSubjectFound = false
            }
            .task {
                // Open straight to the camera on first appearance.
                if CameraPicker.isCameraAvailable, model.capturedImage == nil {
                    showCamera = true
                }
            }
        }
    }

    // MARK: Sections

    @ViewBuilder private var photoSection: some View {
        Section {
            if let image = model.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            HStack(spacing: DesignTokens.spacingM) {
                Button {
                    showCamera = true
                } label: {
                    Label(String(localized: "Camera"), systemImage: "camera")
                }
                PhotosPicker(selection: $libraryItem, matching: .images) {
                    Label(String(localized: "Library"), systemImage: "photo.on.rectangle")
                }
                if model.capturedImage != nil {
                    Spacer()
                    Button(role: .destructive) {
                        model.capturedImage = nil
                    } label: {
                        Label(String(localized: "Remove"), systemImage: "trash")
                    }
                }
            }
            .buttonStyle(.borderless)
            .font(.subheadline)

            if model.capturedImage != nil {
                cleanupRow
            }
        }
    }

    /// "Clean up photo" affordance shown once a photo is set. While a run is in flight it shows a
    /// progress indicator; a nil result (no subject / failure) surfaces a brief inline note and keeps
    /// the original untouched.
    @ViewBuilder private var cleanupRow: some View {
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
                cleanUpPhoto()
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

    @ViewBuilder private var detailsSection: some View {
        Section(String(localized: "Details")) {
            AutocompleteField(
                title: String(localized: "Casting name"),
                text: $model.castingName,
                suggestions: distinctValues(\.castingName)
            )
            identifiedChips
            suggestionChips
            catalogChips
            Picker(String(localized: "Brand"), selection: $model.brand) {
                ForEach(Brand.allCases) { brand in
                    Text(brand.displayName).tag(brand)
                }
            }
            AutocompleteField(
                title: String(localized: "Colorway"),
                text: $model.colorway,
                suggestions: distinctValues(\.colorway)
            )
            AutocompleteField(
                title: String(localized: "Series"),
                text: $model.series,
                suggestions: distinctValues(\.series)
            )
            Picker(String(localized: "Hunt status"), selection: $model.huntStatus) {
                ForEach(HuntStatus.allCases) { status in
                    Text(status.displayName).tag(status)
                }
            }
            Picker(String(localized: "Condition"), selection: $model.condition) {
                ForEach(Condition.allCases) { condition in
                    Text(condition.displayName).tag(condition)
                }
            }
        }
    }

    /// OCR-suggested casting names shown directly under the casting-name field. Tapping a chip fills
    /// the field. A small progress indicator shows while recognition is in flight.
    @ViewBuilder private var suggestionChips: some View {
        if model.isRecognizingText {
            HStack(spacing: DesignTokens.spacingS) {
                ProgressView()
                    .controlSize(.small)
                Text(String(localized: "Reading card…"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        }
        if !model.nameCandidates.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                Text(String(localized: "Suggested"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.spacingS) {
                        ForEach(model.nameCandidates, id: \.self) { candidate in
                            Button {
                                model.castingName = candidate
                            } label: {
                                Text(candidate)
                                    .font(.subheadline)
                                    .foregroundStyle(DesignTokens.primaryText)
                                    .padding(.horizontal, DesignTokens.spacingM)
                                    .frame(minHeight: DesignTokens.minTapTarget)
                                    .background(
                                        Capsule().stroke(DesignTokens.hairline, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                Text(String(localized: "Use suggested name \(candidate)"))
                            )
                        }
                    }
                    .padding(.vertical, DesignTokens.spacingXS)
                }
            }
        }
    }

    /// Castings identified from the card photo by fusing OCR with the catalog (v2.2 step 2). Shown
    /// above the raw-text OCR suggestions because a full catalog hit is a stronger signal than a text
    /// line. Tapping fills name/brand/series + reference price.
    @ViewBuilder private var identifiedChips: some View {
        if !model.identifiedCatalogEntries.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                HStack(spacing: DesignTokens.spacingS) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .foregroundStyle(DesignTokens.secondaryText)
                    Text(String(localized: "Identified from card"))
                        .font(.caption)
                        .foregroundStyle(DesignTokens.secondaryText)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.spacingS) {
                        ForEach(model.identifiedCatalogEntries) { entry in
                            Button {
                                model.apply(entry)
                            } label: {
                                Text(entry.castingName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(DesignTokens.primaryText)
                                    .padding(.horizontal, DesignTokens.spacingM)
                                    .frame(minHeight: DesignTokens.minTapTarget)
                                    .background(
                                        Capsule().stroke(DesignTokens.hairline, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(String(localized: "Use identified casting \(entry.castingName)")))
                        }
                    }
                    .padding(.vertical, DesignTokens.spacingXS)
                }
            }
        }
    }

    /// Catalog matches for the typed casting name (bundled reference data). Tapping a chip fills
    /// name/brand/series and suggests a reference price. Excludes an exact match so an applied entry
    /// doesn't echo itself back as a chip.
    @ViewBuilder private var catalogChips: some View {
        let matches = CatalogStore.shared.search(model.castingName).filter {
            $0.castingName.compare(model.castingName, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame
        }
        if !matches.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                Text(String(localized: "In catalog"))
                    .font(.caption)
                    .foregroundStyle(DesignTokens.secondaryText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.spacingS) {
                        ForEach(matches) { entry in
                            Button {
                                model.apply(entry)
                            } label: {
                                Text(entry.castingName)
                                    .font(.subheadline)
                                    .foregroundStyle(DesignTokens.primaryText)
                                    .padding(.horizontal, DesignTokens.spacingM)
                                    .frame(minHeight: DesignTokens.minTapTarget)
                                    .background(
                                        Capsule().stroke(DesignTokens.hairline, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(String(localized: "Use catalog entry \(entry.castingName)")))
                        }
                    }
                    .padding(.vertical, DesignTokens.spacingXS)
                }
            }
        }
        if let summary = model.appliedCatalogSummary {
            Text(summary)
                .font(.caption)
                .foregroundStyle(DesignTokens.secondaryText)
        }
    }

    @ViewBuilder private var purchaseSection: some View {
        Section(String(localized: "Purchase")) {
            TextField(
                String(localized: "Price paid (₹)"),
                value: $model.pricePaid,
                format: .number.precision(.fractionLength(0...2))
            )
            .keyboardType(.decimalPad)
        }
    }

    @ViewBuilder private var addAnotherSection: some View {
        Section {
            Button {
                save(addAnother: true)
            } label: {
                Label(String(localized: "Save and add another"), systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!model.isValid)
        }
    }

    // MARK: Actions

    /// Entry point for both Save buttons. Warns (non-blocking) if an owned car with the same casting
    /// and colorway already exists; otherwise saves straight through. Collectors do own multiples, so
    /// this only confirms — it never blocks.
    private func save(addAnother: Bool) {
        guard model.isValid else { return }
        if DuplicateCarDetector.ownedDuplicateExists(
            castingName: model.castingName,
            colorway: model.colorway,
            in: allCars
        ) {
            pendingDuplicateAddAnother = addAnother
            return
        }
        performSave(addAnother: addAnother)
    }

    private func performSave(addAnother: Bool) {
        guard model.isValid else { return }

        var filenames: [String] = []
        if let image = model.capturedImage {
            do {
                filenames = [try photoStore.save(image)]
            } catch {
                logger.error("Photo save failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        let car = model.makeCar(photoFilenames: filenames)
        car.recomputeSearchKey()
        modelContext.insert(car)
        do {
            try modelContext.save()
        } catch {
            logger.error("Car save failed: \(error.localizedDescription, privacy: .public)")
            saveError = ErrorAlert(
                message: String(localized: "This car couldn’t be saved. Please try again.")
            )
            return
        }

        if addAnother {
            model.reset()
            if CameraPicker.isCameraAvailable {
                showCamera = true
            }
        } else {
            dismiss()
        }
    }

    /// Runs on-device cleanup for the current photo. A non-nil result opens the before/after preview;
    /// nil (no subject or failure) surfaces an inline note and leaves the original in place. Never
    /// blocks saving.
    private func cleanUpPhoto() {
        guard let image = model.capturedImage, !isCleaning else { return }
        isCleaning = true
        noSubjectFound = false
        Task {
            let result = await PhotoCleanup.cleaned(image)
            // Ignore stale results if the user changed/cleared the photo meanwhile.
            guard model.capturedImage === image else {
                isCleaning = false
                return
            }
            isCleaning = false
            if let result {
                cleanupPreview = CleanupPreview(original: image, cleaned: result)
            } else {
                noSubjectFound = true
                logger.info("Photo cleanup found no subject; keeping original.")
            }
        }
    }

    /// Runs on-device OCR for a newly set image and populates `nameCandidates`. Clears candidates
    /// when the image is removed. OCR is a hint, so failures simply yield no suggestions.
    private func recognizeText(in image: UIImage?) {
        guard let image else {
            model.nameCandidates = []
            model.isRecognizingText = false
            return
        }
        model.isRecognizingText = true
        model.nameCandidates = []
        model.identifiedCatalogEntries = []
        Task {
            let candidates = await recognizer.recognize(image)
            // Ignore stale results if the user changed/cleared the photo meanwhile.
            guard model.capturedImage === image else { return }
            model.nameCandidates = candidates
            // Fuse OCR with the catalog to identify the specific casting (v2.2 step 2).
            model.identifiedCatalogEntries = CatalogMatcher.matches(for: candidates, in: CatalogStore.shared)
            model.isRecognizingText = false
        }
    }

    private func loadLibraryItem(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            defer { libraryItem = nil }
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                model.capturedImage = image
            }
        }
    }

    /// Distinct, trimmed, non-empty values of a string field across the collection, case-folded for
    /// dedupe and sorted for stable suggestion order.
    private func distinctValues(_ keyPath: KeyPath<Car, String?>) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for car in allCars {
            guard let raw = car[keyPath: keyPath] else { continue }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, seen.insert(value.lowercased()).inserted else { continue }
            result.append(value)
        }
        return result.sorted()
    }

    private func distinctValues(_ keyPath: KeyPath<Car, String>) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for car in allCars {
            let value = car[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, seen.insert(value.lowercased()).inserted else { continue }
            result.append(value)
        }
        return result.sorted()
    }
}

/// Identifiable (original, cleaned) pair backing the cleanup preview sheet's `item:` binding.
private struct CleanupPreview: Identifiable {
    let id = UUID()
    let original: UIImage
    let cleaned: UIImage
}

#Preview {
    AddCarView()
        .modelContainer(.inMemory(seeded: true))
        .preferredColorScheme(.dark)
}
