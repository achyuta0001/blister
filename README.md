# Blister

A native iOS app for tracking a **1:64 scale die-cast car collection** — Hot Wheels, Matchbox,
Mini GT, Tarmac Works and friends. Built entirely with Apple frameworks: SwiftUI + SwiftData, no
backend, no third-party dependencies.

Blister is aimed at the collector standing in a shop aisle: *do I already own this casting?* It
answers that in seconds, keeps a photographed collection, tracks a wishlist, and identifies castings
from a card photo on-device.

## Features

- **Aisle Check** — type or scan a casting; get a giant, arm's-length IN / NOT IN COLLECTION verdict,
  with owned colorways disambiguated. A miss shows a "known casting" hint (with a typical India price)
  from the bundled catalog.
- **Garage** — the owned collection as a photo grid, with search, sort and filters.
- **Wishlist** — castings you're hunting, with a one-tap "Found it" flow that moves an item into the
  Garage and captures where/when/how much.
- **Add Car** — camera-first entry (< 15s per car). On-device OCR reads the card and, fused with the
  catalog, surfaces **"Identified from card"** chips that fill name / brand / series / reference price.
- **Photo cleanup** — on-device Vision lifts the car off its cluttered background and composites it
  onto a clean studio backdrop (opt-in, with a before/after preview and a "keep original" fallback).
- **3D studio** — tap a car's photo to inspect it in a lit RealityKit studio; drag to orbit the
  camera, pinch to zoom.
- **Catalog + India price reference** — ~114 bundled known castings that power autocomplete,
  identification, and price suggestions.

## Hard constraints

These are non-negotiable and hold across the whole codebase:

- **Apple frameworks only** — zero third-party dependencies.
- **No backend / API / server**, no analytics or crash SDKs. Everything runs on-device.
- **Privacy** — photos are stored as files in the app container (relative paths in SwiftData, never
  image blobs). The catalog is bundled, not fetched.
- `Decimal` for money, never `Double`. All user-facing strings via `String(localized:)`.
- SwiftData schema is CloudKit-safe: every property defaulted/optional, no `@Attribute(.unique)`.
- `Logger` (os) instead of `print`; no force-unwrap outside tests.
- One type per file; group by feature.

## Build & run

Requires Xcode 26+ (iOS 26.5 SDK), targeting iOS 18+.

```sh
# Build
xcodebuild -scheme Blister -project Blister.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' build

# Test (Swift Testing)
xcodebuild -scheme Blister -project Blister.xcodeproj \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' test
```

The Xcode project uses an Xcode 16 **synchronized file-system group**, so new `.swift` files under
`Blister/` are picked up automatically — no per-file project edits.

## Architecture

```
Blister/
  Model/         SwiftData @Model Car + Codable enums (Brand, HuntStatus, Condition, …)
  Persistence/   ModelContainer factory (CloudKit-ready seam), photo store, seed/debug helpers
  Search/        SearchNormalizer (year canonicalisation) + LiveSearchEngine (4-tier ranking)
  Catalog/       Bundled read-only catalog (JSON → CatalogStore) + OCR×catalog CatalogMatcher
  Features/      One folder per feature: AisleCheck, Garage, Wishlist, AddCar, CarDetail,
                 Studio, PhotoCleanup, Settings
  Shared/        Design tokens and shared views
BlisterTests/    Swift Testing suites for the pure logic (search, catalog, parsing, geometry, …)
docs/            Design specs and build/roadmap plans
```

Key design decisions:

- **Search** filters an in-memory array (never a per-keystroke SwiftData predicate) and ranks matches
  exact → prefix → token-subset → fuzzy. A denormalised `searchKey`/`castingKey` is recomputed on save.
- **Catalog** is deliberately *not* a SwiftData model — it's bundled reference data loaded into an
  in-memory store, so it never syncs, never migrates, and stays license-clean.
- **On-device identification** fuses OCR text with the catalog (`CatalogMatcher`) instead of a trained
  classifier — no dataset needed, license-clean, and it covers every catalog entry.
- **CloudKit sync** is designed-in but off: the container factory takes a container id, and the model
  is already sync-safe. Flip it on with a paid developer account (see `docs/`).

## Roadmap status

- **v1** — core collection, Aisle Check, Garage, Wishlist, Add Car, search: shipped.
- **v2.1** — CloudKit sync foundation: prepped, off pending a paid Apple Developer account.
- **v2.2** — on-device identification: OCR (step 1) + OCR×catalog fusion (step 2): shipped.
- **v2.3** — catalog + India price reference: shipped.
- **v2.4** — widgets + Apple Watch: planned.
- **v2.5** — social / sharing (requires a backend): explicit scope break, deferred.

See `docs/superpowers/specs/` for the detailed specs and `req.md` for the original requirements.
