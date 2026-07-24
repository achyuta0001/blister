# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Blister** — a native iOS die-cast (1:64) collection tracker. SwiftUI + SwiftData, Apple frameworks
only. Original requirements in `req.md`; design specs and roadmap in `docs/superpowers/specs/`.

## Commands

```sh
# Build (iPhone 17 sim, iOS 26.5)
xcodebuild -scheme Blister -project Blister.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build build

# Test — Swift Testing; results show as "✔ Suite … passed", not "Executed N tests"
xcodebuild -scheme Blister -project Blister.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -derivedDataPath build test

# Quick typecheck without a simulator
SIMSDK=$(xcrun --sdk iphonesimulator26.5 --show-sdk-path)
xcrun swiftc -typecheck -sdk "$SIMSDK" -target arm64-apple-ios18.0-simulator \
  -swift-version 6 -strict-concurrency=complete $(find Blister -name '*.swift')
```

The Xcode project uses an Xcode 16 **`PBXFileSystemSynchronizedRootGroup`**, so new `.swift` files
(and resources like `catalog.json`) under `Blister/` / `BlisterTests/` are auto-included — no
per-file `project.pbxproj` edits needed.

## Hard constraints (must always hold)

- Apple frameworks only — **zero third-party dependencies**; **no backend / API / server**; no
  analytics/crash SDKs.
- `Decimal` for money, never `Double`. All user-facing strings via `String(localized:)`.
- Photos stored as **relative file paths**, never image blobs in SwiftData.
- SwiftData schema stays CloudKit-safe: every property defaulted/optional, **no `@Attribute(.unique)`**.
- `Logger` (os) not `print`; no force-unwrap outside tests.
- One type per file; group by feature.

## Architecture notes

- **Search** (`Blister/Search/`): `LiveSearchEngine` filters an in-memory `[Car]` (never a
  per-keystroke predicate) and ranks exact → prefix → token-subset → fuzzy (Levenshtein ≤ 2).
  `SearchNormalizer` canonicalises text and the `'67`/`67`/`1967` year convention. Cars carry a
  denormalised `searchKey`/`castingKey`, recomputed on save via `recomputeSearchKey()`.
- **Catalog** (`Blister/Catalog/`): bundled `catalog.json` → in-memory `CatalogStore` (`static shared`,
  loads via `Bundle(for:)`, reuses `SearchNormalizer`; has a testable `init(entries:)`). **Not**
  SwiftData — never syncs/migrates. `CatalogEntry` uses `priceINR: Int` (whole rupees) → `Decimal`.
  `CatalogMatcher` fuses OCR candidates with the catalog to identify specific castings.
- **Persistence** (`Blister/Persistence/`): `ModelContainer.blister(cloudKitContainerID:)` — pass an
  id to enable CloudKit `.private` sync (off today); `.inMemory(seeded:)` for tests/previews.

## Gotchas (learned the hard way)

- **SwiftData enum-in-predicate trap:** a `#Predicate`/`@Query` filtering on a `Codable` enum property
  crashes (`$0.status.rawValue == x`) or silently matches nothing (`$0.status == x`). Fix: fetch all,
  filter the enum in memory. GarageView/WishlistView do this.
- **Simulator runtime:** if builds fail with "no destinations" / actool "No simulator runtime", run
  `xcodebuild -downloadPlatform iOS`. `xcodebuild test` on a cold sim can fail SwiftData with
  "sandbox access denied" — boot + launch the app once first.
- **Decimal init ambiguity:** `optionalInt.map(Decimal.init)` is ambiguous — use `.map { Decimal($0) }`.
- **Vision in the simulator:** `VNGenerateForegroundInstanceMaskRequest` (photo cleanup) can't build
  an inference context in the sim (returns nil → keeps original, by design); verify lift quality on a
  real device or the Mac host. Text recognition (`RecognizeTextRequest`) does work in the sim.
- **Studio is a billboard:** the 3D studio shows a lit photo cutout (camera orbits it on a clamped
  arc), not a real mesh — single-photo → true 3D isn't possible Apple-only. Object Capture is the only
  real-3D path and is not built.

## Debug launch aids (DEBUG only)

Launch env vars (prefix `SIMCTL_CHILD_` when using `simctl launch`): `BLISTER_SEED_IF_EMPTY=1` seeds
sample cars; `BLISTER_START_TAB=aisle|garage|wishlist|settings`; `BLISTER_SEED_PHOTO=1` attaches a
synthetic photo to the first owned car; `BLISTER_SEED_COMPOSITE=1` attaches a bundled demo cleanup
composite. See `Blister/Persistence/DebugLaunch.swift`.
