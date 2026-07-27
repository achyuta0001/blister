#if DEBUG
import Foundation
import SwiftData
import UIKit

/// Debug-only launch helpers for driving the app from the command line during manual testing.
/// Gated behind `#if DEBUG` and launch environment variables, so a shipping build never runs this.
enum DebugLaunch {
    /// Seeds ``SeedData/sampleCars`` into the on-disk store when launched with
    /// `BLISTER_SEED_IF_EMPTY=1` and the store currently has no cars. Idempotent: does nothing if
    /// any car already exists, so repeated launches don't duplicate.
    ///
    /// With `BLISTER_SEED_PHOTO=1` it also attaches a synthetic photo to the first owned car, so the
    /// real-image paths (tilt hero + studio viewer) can be exercised without the camera.
    @MainActor
    static func seedIfRequested(_ container: ModelContainer) {
        guard ProcessInfo.processInfo.environment["BLISTER_SEED_IF_EMPTY"] == "1" else { return }
        // Seed into the container's mainContext — the same context `@Query` reads — so freshly
        // inserted rows are visible on first render.
        let context = container.mainContext
        let existing = (try? context.fetchCount(FetchDescriptor<Car>())) ?? 0
        guard existing == 0 else { return }
        for car in SeedData.sampleCars() {
            context.insert(car)
        }
        try? context.save()

        if ProcessInfo.processInfo.environment["BLISTER_SEED_COMPOSITE"] == "1" {
            attachBundledPhoto(named: "cleanup_demo", in: context)
        } else if ProcessInfo.processInfo.environment["BLISTER_SEED_PHOTO"] == "1" {
            attachSyntheticPhoto(in: context)
        }
    }

    /// The photo `BLISTER_OPEN_STUDIO=1` should open straight into ``StudioView``: the first photo of
    /// the most recently added car that has one. `nil` when the flag is off or nothing is stored.
    ///
    /// The Studio is otherwise three taps deep (Garage → car → hero), and a headless `simctl` session
    /// has no way to tap — so without this the 3D scene cannot be screenshotted from the command line.
    @MainActor
    static func studioPhotoIfRequested(_ context: ModelContext) -> UIImage? {
        guard ProcessInfo.processInfo.environment["BLISTER_OPEN_STUDIO"] == "1" else { return nil }
        let descriptor = FetchDescriptor<Car>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        guard let car = (try? context.fetch(descriptor))?.first(where: { !$0.photoFilenames.isEmpty }),
              let filename = car.photoFilenames.first else { return nil }
        return DocumentsPhotoStore.shared.fullImage(for: filename)
    }

    /// Attaches a bundled PNG (from the app bundle) to the first owned car — used to preview the real
    /// photo-cleanup composite in the UI, since Vision inference can't run in the simulator.
    @MainActor
    private static func attachBundledPhoto(named name: String, in context: ModelContext) {
        let descriptor = FetchDescriptor<Car>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        guard let car = (try? context.fetch(descriptor))?.first(where: { $0.status == .owned }),
              let url = Bundle.main.url(forResource: name, withExtension: "png"),
              let image = UIImage(contentsOfFile: url.path),
              let filename = try? DocumentsPhotoStore.shared.save(image) else { return }
        car.photoFilenames = [filename]
        car.dateModified = Date()
        car.recomputeSearchKey()
        try? context.save()
    }

    /// Attaches a generated placeholder photo to the first owned car (debug only).
    @MainActor
    private static func attachSyntheticPhoto(in context: ModelContext) {
        let descriptor = FetchDescriptor<Car>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        guard let car = (try? context.fetch(descriptor))?.first(where: { $0.status == .owned }),
              let image = syntheticCarImage(title: car.castingName) else { return }
        guard let filename = try? DocumentsPhotoStore.shared.save(image) else { return }
        car.photoFilenames = [filename]
        car.dateModified = Date()
        car.recomputeSearchKey()
        try? context.save()
    }

    /// A synthetic "car photo": a warm gradient card with the casting name — enough to exercise the
    /// tilt/studio image paths visually.
    private static func syntheticCarImage(title: String) -> UIImage? {
        let size = CGSize(width: 1200, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor(red: 0.18, green: 0.20, blue: 0.26, alpha: 1).cgColor,
                          UIColor(red: 0.10, green: 0.11, blue: 0.14, alpha: 1).cgColor]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors as CFArray, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: .zero,
                                      end: CGPoint(x: size.width, y: size.height), options: [])
            }
            let accent = UIColor(red: 0.910, green: 0.361, blue: 0.251, alpha: 1)
            accent.setFill()
            UIBezierPath(roundedRect: CGRect(x: 120, y: 540, width: 200, height: 120),
                         cornerRadius: 16).fill()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 96, weight: .bold),
                .foregroundColor: UIColor(white: 0.96, alpha: 1)
            ]
            let text = title as NSString
            text.draw(in: CGRect(x: 120, y: 700, width: 960, height: 400), withAttributes: attrs)
        }
    }
}
#endif
