import Foundation
import SwiftData

extension ModelContainer {
    /// The app's on-disk container.
    ///
    /// `cloudKitContainerID` is the seam for CloudKit sync (v2.1). It is `nil` today, giving a
    /// purely local store, so the app builds and runs without an iCloud entitlement. When an
    /// account is available, pass the container id (e.g. `"iCloud.com.blister.app"`) here from
    /// `BlisterApp` and add the iCloud + CloudKit capability — see
    /// `docs/superpowers/specs/blister-v2.1-cloudkit-enablement.md`. The `Car` model is already
    /// CloudKit-safe (all properties defaulted/optional, no `@Attribute(.unique)`), so no data
    /// migration is needed to flip this on. Photos stay device-local (only filenames sync).
    static func blister(cloudKitContainerID: String? = nil) -> ModelContainer {
        let schema = Schema([Car.self])
        let config: ModelConfiguration
        if let cloudKitContainerID {
            config = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
        } else {
            config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // A container that cannot be created means the app cannot function; there is no safe
            // partial state to continue from, so fail loudly rather than force-unwrap elsewhere.
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// An in-memory container for tests and SwiftUI previews. Pass `seeded: true` to populate it
    /// with ``SeedData/sampleCars``.
    static func inMemory(seeded: Bool = false) -> ModelContainer {
        let schema = Schema([Car.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            if seeded {
                let context = ModelContext(container)
                for car in SeedData.sampleCars() {
                    context.insert(car)
                }
                try context.save()
            }
            return container
        } catch {
            fatalError("Failed to create in-memory ModelContainer: \(error)")
        }
    }
}
