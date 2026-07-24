# Blister — v2 plan

Planning doc only. No code here. Sequenced so each phase ships independently and de-risks the next.
Source of truth for scope is `req.md` §11 (deferred). v1 already made the two decisions that make
v2 cheap: the SwiftData model is sync-safe (all properties defaulted/optional, no
`@Attribute(.unique)`), and search/normalisation is isolated behind `SearchNormalizer` /
`SearchEngine`.

## Ordering rationale

CloudKit sync comes first because it is pure infrastructure with the highest "regret cost" if
deferred — every later feature (vision IDs, catalog links, shared pages) wants to sync its data,
and retrofitting sync after those ship means migrating their schemas too. Vision ID is the headline
user feature and comes second. Catalog + price reference feed both search and vision. Reach
(widgets, watch) is leaf work. Social is last because it breaks the local-first premise and needs a
backend — the biggest architectural change, isolated at the end.

---

## v2.1 — CloudKit sync foundation

> **Status (2026-07-23):** account-independent prep **done**. The container seam
> (`ModelContainer.blister(cloudKitContainerID:)`), readiness guard tests
> (`BlisterTests/CloudKitReadinessTests.swift`), and the enablement runbook
> (`blister-v2.1-cloudkit-enablement.md`) are in place. CloudKit itself is **OFF** pending a paid
> Apple Developer account. **Photo decision made: device-local, metadata-only** — no CloudKit assets.

**Goal:** the same collection on iPhone + iPad, offline-first, no account UI beyond the system
iCloud toggle.

- Switch the container to `ModelConfiguration(... cloudKitDatabase: .automatic)`; add the iCloud +
  CloudKit capability and a container identifier. No model changes expected (v1 designed for this).
- Handle merge semantics: last-writer-wins per field is acceptable for a single user's devices;
  verify photo-file references reconcile (images sync via the CloudKit asset store, not the blob —
  decide: sync full images, or thumbnails only + regenerate).
- **Photos — DECIDED: option (b), device-local.** SwiftData syncs the relative filename, not the
  file; a second device shows the `TypographicPlaceholder` (already the fallback everywhere). No
  CloudKit assets, no image blobs. Options (a) synced assets / (c) manual mirroring are explicitly
  deferred unless this is revisited.
- **Migration test:** seed a v1 store, enable sync, assert no data loss and stable `id`s.
- **Risk:** CloudKit rejects unique constraints and requires all-optional/defaulted schema — already
  satisfied, but any new v2 model must keep that discipline.
- **Acceptance:** add a car on device A, appears on device B within seconds; airplane-mode edits
  reconcile on reconnect.

## v2.2 — On-device photo identification (headline feature)

> **Status (2026-07-24):** **step 1 (OCR) shipped.** On-device Vision text recognition
> (`CardTextRecognizer`, iOS 18 async `RecognizeTextRequest`) + a pure, unit-tested ranker
> (`CardTextParser`, 7 tests) surface tappable casting-name candidate chips in the Add Car form
> after a photo is captured. Also fixed a latent v1 gap: Add Car had **no UI entry point** — added a
> "+" button in Garage presenting `AddCarView`. Step 2 (CoreML classifier) still pending, blocked on
> the v2.3 catalog for labels. Build + all tests green; OCR chips not screenshot-verifiable
> headlessly (needs a real card photo + tap).
>
> **Step 2 (2026-07-24): shipped — as OCR × catalog fusion, not a trained CNN.** A trained CoreML
> classifier was ruled out: no license-clean training images, no dataset, and it would cover only
> trained classes (spec's brand-imagery licensing bar). Instead `Blister/Catalog/CatalogMatcher.swift`
> fuses the step-1 OCR candidates with the v2.3 `CatalogStore` to identify the specific casting,
> surfaced as tappable "Identified from card" chips in Add Car that fill name/brand/series + reference
> price (via `AddCarModel.apply`). On device, no dataset, license-clean, covers every catalog entry.
> `CatalogMatcherTests` (5 tests); build + all 57 tests green. Fusion runs on captured/library photos;
> not headless-tappable — eyeball on device.

- On-device only (no server, preserves the privacy/no-ops stance): Vision for text/logo detection on
  the blister card first (cheap, high-precision — most cards print the casting name), then a
  CoreML image classifier as a second signal.
- Feeds two seams already built in v1: the Add form's autocomplete and Aisle Check's query. The
  classifier output becomes a pre-filled, editable query — never an unverified write.
- **Data dependency:** a labelled model needs a catalog (v2.3). Ship v2.2 in two steps: (1) OCR the
  card text into the name field (works with zero catalog), (2) add the trained classifier once
  catalog data exists.
- **Risk:** model size vs app size; training data licensing for brand imagery. Keep the classifier
  optional and downloadable, or bundle a small high-frequency-casting model.
- **Acceptance:** OCR fills the casting name correctly for a set of common Hot Wheels/Matchbox cards;
  classifier top-3 includes the right casting for a held-out test set.

## v2.3 — Catalog + India price reference

> **Status (2026-07-24):** **shipped.** Bundled read-only catalog (`Blister/Catalog/catalog.json`,
> ~43 real castings across Hot Wheels/Matchbox/Mini GT/Tarmac/Tomica/Majorette/Greenlight/M2) loaded
> into an in-memory `CatalogStore` (`Bundle(for:)`, reuses `SearchNormalizer`; deliberately **not**
> SwiftData, so it never syncs/migrates). Wired: Add Car shows "In catalog" chips that fill
> name/brand/series and suggest a reference `estimatedValueINR` (never overwrites a user value); Aisle
> Check misses show a "Known casting · brand/series · typical ≈ ₹X" hint (`AisleVerdict.notInCollection`
> now carries a `catalogHint`). Prices are static India approximations. Build + all 52 tests green
> (incl. `CatalogStoreTests`), zero third-party deps. UI chips/hint not headless-screenshot-verifiable
> (need typing) — state wiring unit-tested; eyeball on device/sim. Unblocks the v2.2 step-2 classifier
> (labels now exist).

**Goal:** seed known castings (Matchbox, Mini GT to start) so search suggests real names and the
classifier has labels; add an India-specific price reference so `estimatedValueINR` can be
suggested.

- Bundle a read-only catalog store (separate from the user's `Car` store) shipped in the app.
- Wire catalog into Add autocomplete and Aisle Check ranking as a fallback tier below the user's own
  collection.
- Price reference: static bundled reference first (no scraping — v1 non-goal stays), refreshed per
  app update. A live feed is explicitly out of scope until there is a backend (v2.5).
- **Acceptance:** typing a known casting suggests the catalog entry; a bundled price shows as a
  suggestion (never overwrites user-entered value).

## v2.4 — Reach: widgets + Apple Watch

**Goal:** make Aisle Check reachable without opening the app.

- Home-screen / Lock-screen widget: quick-entry into Aisle Check; optional "collection count" glance.
- Apple Watch app: a stripped Aisle Check — voice/scribble a casting name, get the IN / NOT IN
  verdict on the wrist while standing at the peg. Reads the synced store (depends on v2.1).
- **Risk:** Watch reads need the synced dataset available on the watch; confirm SwiftData +
  CloudKit reach the watch target, else ship a WatchConnectivity snapshot.
- **Acceptance:** widget opens Aisle Check in one tap; watch returns a verdict for a synced
  collection offline.

## v2.5 — Social (scope break: ends local-first)

**Goal:** shared/public collection pages and trade / want-list matching between users.

- This is the one v2 item that requires a backend and accounts — it breaks the v1 "no server, no
  account" premise. Treat it as a separate product decision, not a milestone bolted onto the app.
- Minimum surface: opt-in public read-only collection page (export the local collection to a hosted
  page), then want-list matching (needs a shared index of who-wants-what → a real service).
- **Decision gate before building:** are we willing to run and pay for a backend, handle auth,
  privacy, and moderation? If not, stop at public export via a static share.
- **Acceptance:** deferred until the backend decision is made.

---

## Not in v2 either

Market value scraping / live price feeds (still a non-goal without a backend and legal review),
Android/web. Revisit only after v2.5's backend decision.
