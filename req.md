# Die-cast Collection Tracker — iOS v1 Spec

**Working name:** `Pegged` (alternatives: `Casting`, `Garage64`, `Aisle`)
**Platform:** iOS, native
**Audience for this doc:** Claude Code, building from an empty Xcode project
**Author context:** Solo developer, backend/DevOps background (Spring Boot, Kubernetes, React), new to Swift. Weekend hours only.

---

## 1. What this is

A collection tracker for 1:64 die-cast cars (Hot Wheels, Matchbox, Mini GT, Majorette, Tomica, Tarmac Works). Local-first, no account, no server.

**The one moment the app exists for:** standing in a shop aisle holding a car, needing to know in under three seconds whether it is already in the collection. Everything else is secondary and must not slow that down.

**Positioning vs. existing apps:** the market already has several trackers with large catalogs and AI photo identification. This app does not compete on catalog size. It competes on (a) search that actually works, (b) being built for Indian collectors — INR, local pricing, local availability — and (c) not looking like a toy.

---

## 2. Non-goals for v1

Do not build these. If a task seems to require one, stop and flag it instead.

- No user accounts, login, or authentication
- No backend, API, or server of any kind
- No AI/vision-based car identification (planned for v2)
- No market value scraping or price feeds
- No social/community feed, following, or sharing
- No iPad-optimised layout (must not crash on iPad, but phone layout is fine)
- No Android, no web
- No third-party dependencies — Apple frameworks only
- No analytics or crash reporting SDKs

---

## 3. Tech decisions (already made — do not re-litigate)

| Area | Decision |
|---|---|
| Language | Swift 6, strict concurrency enabled |
| UI | SwiftUI only, no UIKit except where wrapping is unavoidable |
| Minimum iOS | 18.0 |
| Persistence | SwiftData |
| Photos | Written to app Documents directory; SwiftData stores relative file paths, never image blobs |
| Barcode scanning | `VisionKit` / `DataScannerViewController`, wrapped in `UIViewControllerRepresentable` |
| Architecture | MV (Model + SwiftUI views with `@Observable` view models where state is non-trivial). No VIPER, no Clean Architecture, no Coordinator pattern. |
| Dependencies | None |
| Testing | Swift Testing (`@Test`) for model logic and search ranking. No UI tests in v1. |

Rationale for local-first: removes all ops work and makes v1 shippable in weekends. CloudKit sync via SwiftData's built-in support is a v2 concern — but design the model so it can be switched on without migration pain (see §4 notes).

---

## 4. Data model

```swift
@Model
final class Car {
    var id: UUID
    var castingName: String        // "'67 Camaro"
    var brand: Brand
    var series: String?            // "Car Culture: Japan Historics"
    var releaseYear: Int?
    var collectorNumber: String?   // "142/250"
    var colorway: String?          // "Spectraflame Blue"
    var wheelType: String?         // "RR", "5SP"
    var huntStatus: HuntStatus
    var condition: Condition
    var status: CollectionStatus   // owned or wanted
    var purchasePriceINR: Decimal?
    var purchaseDate: Date?
    var purchaseLocation: String?  // "Hamleys Phoenix Mall" / "Landmark" / seller handle
    var estimatedValueINR: Decimal?
    var notes: String?
    var barcode: String?
    var photoFilenames: [String]   // relative to Documents/photos/
    var tags: [String]
    var dateAdded: Date
    var dateModified: Date
    var searchKey: String          // see §5 — denormalised, recomputed on save
}

enum Brand: String, Codable, CaseIterable {
    case hotWheels, matchbox, miniGT, majorette, tomica, tarmacWorks, m2, greenlight, other
}

enum HuntStatus: String, Codable, CaseIterable {
    case none, treasureHunt, superTreasureHunt
}

enum Condition: String, Codable, CaseIterable {
    case mintOnCard, openedCard, loose, damaged
}

enum CollectionStatus: String, Codable {
    case owned, wanted
}
```

**Notes:**
- Every property needs a default value or optionality so CloudKit sync can be enabled later without a destructive migration. No `@Attribute(.unique)` — CloudKit rejects it.
- `Decimal` for money, never `Double`.
- Wishlist is not a separate entity. It is `status == .wanted`. Moving a car from wishlist to garage is a status flip plus optional purchase fields — this must be a single tap.

---

## 5. Search — the part that must be excellent

Existing competitor apps are consistently criticised for search that fails to match casting names and series. This is the main engineering differentiator. Treat it as a first-class feature, not a text filter.

**Normalisation.** Compute `searchKey` on every save: lowercase, strip apostrophes and punctuation, collapse whitespace, strip diacritics, and expand the leading-apostrophe year convention. Concatenate `castingName + series + colorway + collectorNumber + tags`.

The following queries must all match a car named `'67 Camaro` in series `Car Culture: Japan Historics`:

```
67 camaro
'67 camaro
camaro 67
1967 camaro
camaro
japan historics
```

**Matching strategy, in rank order:**
1. Exact match on normalised casting name
2. Prefix match on any token of the casting name
3. All query tokens present anywhere in `searchKey` (order-independent)
4. Fuzzy match — Levenshtein distance ≤ 2 on any single token, to survive typing on a phone one-handed

Results sort by tier, then by `dateAdded` descending.

**Performance:** must return results within one frame for a collection of 5,000 cars. Do the filtering in memory over a fetched array rather than repeated SwiftData predicates. Write a test that seeds 5,000 rows and asserts search completes under 50ms.

---

## 6. Screens

### 6.1 Aisle Check — the primary screen
Reachable in one tap from anywhere in the app. Optimised for one-handed use in a shop with bad lighting.

- Search field pinned at the **bottom** (thumb reach), autofocused, keyboard up on open
- Results appear live as you type
- The answer must be readable at arm's length: if a match is found, show **IN COLLECTION** in large type with the matching car's photo and colorway; if not, **NOT IN COLLECTION**
- Colorway is the critical disambiguator — a red and a blue casting are different items. Show all owned colorways of a matched casting.
- One-tap actions on a miss: *Add to Garage* or *Add to Wishlist*
- Barcode scan button as an alternative input. Note in the UI that barcodes are frequently shared across an assortment, so a scan is a hint, not proof.

### 6.2 Garage
- Photo grid, two columns, square crops
- Cars with no photo show a typographic placeholder using the casting name, not a generic icon
- Filter chips: brand, hunt status, condition, series, year
- Sort: recently added, casting name, year, value
- Header shows collection count and total spend in INR

### 6.3 Add Car
The flow that determines whether the app gets used. Target: under 15 seconds per car.

1. Opens straight to the camera
2. Shoot photo (or pick from library, or skip)
3. Single form screen: casting name (required), brand (defaults to Hot Wheels), colorway, series, hunt status, condition, price paid
4. Everything except casting name is optional
5. Save returns to the previous screen, not to the new car's detail view
6. "Save and add another" keeps the camera open — collectors buy in batches

Autocomplete casting name, series, and colorway from values already in the user's own collection.

### 6.4 Car Detail
Photos (swipeable), all fields, edit inline, delete with confirmation. Show a "you own N variants of this casting" link when applicable.

### 6.5 Wishlist
Same grid as Garage, filtered to `.wanted`. Primary action on each card: *Found it* → moves to owned, prompts for price paid.

### 6.6 Settings
- Export collection as CSV and as JSON (share sheet)
- Photo storage size and a way to see it
- App version

---

## 7. Visual direction

Deliberately not toy-like. The competitors are colourful and cluttered; this should read as a serious catalogue.

- Dark background `#1C1C1C`, near-white text
- System font (SF Pro), tight tracking on headings, generous line height on body
- Left-aligned everything; no centred text
- No gradients, no drop shadows, no rounded-corner-plus-border card styling
- One accent colour only, used for hunt status and destructive actions
- The car photographs are the only colour in the interface
- Large type for the Aisle Check verdict — this is the one place where scale is the whole point

Accessibility: support Dynamic Type up to XXL, VoiceOver labels on all controls, minimum 44pt tap targets.

---

## 8. Build order

Ship each milestone as a working build before starting the next. Do not build ahead.

**M1 — Foundation**
Xcode project, SwiftData stack, `Car` model, Garage grid rendering seeded sample data. No add flow yet.

**M2 — Capture**
Add Car flow, camera, photo storage to Documents, thumbnail generation, edit and delete. At the end of M2 the developer should be able to enter their real collection.

**M3 — Search & Aisle Check**
`searchKey` computation, ranking algorithm, tests including the 5,000-row performance test, Aisle Check screen.

**M4 — Wishlist & filters**
Status flip, wishlist grid, filter chips, sort options.

**M5 — Ship**
CSV/JSON export, empty states, Dynamic Type pass, VoiceOver pass, app icon, TestFlight build.

---

## 9. Conventions

- One type per file, filename matches type name
- Group by feature (`Features/AisleCheck/`, `Features/Garage/`) not by layer
- No force unwrapping outside tests
- No `print()` — use `Logger` from `os`
- Photos: `Documents/photos/<uuid>.heic`, thumbnails at `Documents/photos/thumbs/<uuid>.jpg`, 400px longest edge
- All user-facing strings through `String(localized:)` from day one, even though v1 ships English only
- Currency formatting via `Decimal` + `FormatStyle` with `INR`, never string interpolation

---

## 10. Acceptance criteria for v1

- [ ] Adding a car with a photo takes under 15 seconds start to finish
- [ ] Aisle Check returns a verdict within one second of the final keystroke on a 1,000-car collection
- [ ] All six normalisation queries in §5 match the `'67 Camaro` fixture
- [ ] App launches to usable state in under one second cold
- [ ] Force-quitting mid-add loses at most the in-progress car
- [ ] Export produces a CSV that opens correctly in Numbers with INR values intact
- [ ] No crash on iPad, no crash in landscape
- [ ] Zero third-party dependencies in the built product

---

## 11. Deferred to v2 — do not build now

Photo-based car identification via a vision model; CloudKit sync across devices; shared/public collection pages; India-specific price reference data; trade and want-list matching between users; Matchbox/Mini GT catalog seeding; widgets; Apple Watch aisle check.