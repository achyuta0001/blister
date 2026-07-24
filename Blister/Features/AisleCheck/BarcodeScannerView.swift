import SwiftUI
import VisionKit
import os

/// Wraps VisionKit's `DataScannerViewController` for barcode input in Aisle Check (spec §6.1).
/// Owned by Agent 4.
///
/// A scan is an *alternative input*, not a source of truth: barcodes are frequently shared across an
/// entire assortment, so the caller surfaces the result as a hint. Present this only after checking
/// ``isSupported`` — the hardware/simulator may not support live scanning.
struct BarcodeScannerView: UIViewControllerRepresentable {
    /// Called on the main actor with the decoded barcode payload.
    let onScan: (String) -> Void

    /// Whether this device can present the scanner at all. Feature-detect before showing the button.
    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        do {
            try scanner.startScanning()
        } catch {
            context.coordinator.logger.error("startScanning failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        let logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "Blister",
            category: "AisleCheckScanner"
        )
        private var hasReported = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            report(from: addedItems)
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didTapOn item: RecognizedItem
        ) {
            report(from: [item])
        }

        private func report(from items: [RecognizedItem]) {
            guard !hasReported else { return }
            for item in items {
                if case let .barcode(barcode) = item,
                   let payload = barcode.payloadStringValue,
                   !payload.isEmpty {
                    hasReported = true
                    onScan(payload)
                    return
                }
            }
        }
    }
}
