# Blister — iOS v1 build plan (fan-out) + v2 plan

## Context

Empty repo, one file: `req.md` — a complete, locked v1 spec for a local-first 1:64 die-cast
collection tracker (SwiftUI, SwiftData, Swift 6 strict concurrency, iOS 18, zero third-party
deps). Solo dev, backend/DevOps background, new to Swift, weekend hours. Xcode 16+ confirmed
installed.

User asked to: (1) **fan out subagents to build MVP1 (full v1, M1–M5)** via the hybrid
strategy, and (2) **produce an MVP2 plan doc** for the deferred §11 features.

Spec §8 wants sequential milestone gates. Pure parallelism breaks that. Resolution: build the
**foundation + shared contracts sequentially**, fan out **independent features in parallel**
against frozen contracts, then **integrate + polish sequentially**. This honors the real
dependency graph while getting the parallelism the user asked for.

## Name decision

**Blister.** Folder `Blister/`, target `Blister`, bundle `com.<dev>.blister`. Rejected: Vitrine
(taken), Aisle (Indian dating app collision), Garage64 (Hunt64 collision), Casting (screencast
collision). Not brand-locked in code — a rename touches only the target/bundle, not source.

## Architecture (per spec §9 — group by feature, one type per file)

```
Blister.xcodeproj                    # Xcode 16 PBXFileSystemSynchronizedRootGroup → Blister/
Blister/
  BlisterApp.swift                   # @main, ModelContainer wiring
  RootView.swift                     # TabView shell: AisleCheck / Garage / Wishlist / Settings
  Model/
    Car.swift  Brand.swift  HuntStatus.swift  Condition.swift  CollectionStatus.swift
  Persistence/
    ModelContainer+Blister.swift     # container factory, in-memory variant for tests/previews
    SeedData.swift                   # ~30 sample cars for M1 + previews
  Search/                            # Agent 1
  Features/Garage/                   # Agent 2
  Features/AddCar/                   # Agent 3
  Features/AisleCheck/               # Agent 4
  Features/Wishlist/                 # Agent 5
  Features/CarDetail/                # Agent 3 (shares AddCar form)
  Features/Settings/                 # Agent 5
  Shared/
    DesignTokens.swift               # #1C1C1C bg, accent, tracking, spacing
    CurrencyFormat.swift             # Decimal + FormatStyle INR
    TypographicPlaceholder.swift     # no-photo card
    PhotoStore.swift                 # protocol + Documents impl (contract)
    SearchEngine.swift               # protocol (contract; impl in Search/)
BlisterTests/                        # Swift Testing
docs/superpowers/specs/
    2026-07-23-blister-v1-build-plan.md   # copy of this plan
    2026-07-23-blister-mvp2-plan.md       # the v2 deliverable
```

Xcode 16 **synchronized file-system groups** are the key enabler: files on disk in `Blister/`
are auto-included in the target with no per-file `.pbxproj` entries. Parallel agents just drop
`.swift` files into their feature folder — **zero `.pbxproj` contention, zero merge conflicts on
the project file.**

## Frozen contracts (built in Phase A, agents code against these)

- `Car` model + all enums — final, read-only for agents.
- `protocol SearchEngine { func search(_ query: String, in cars: [Car]) -> [Car] }` — Aisle Check
  (Agent 4) codes to this; Search (Agent 1) implements it.
- `protocol PhotoStore` — save HEIC + 400px thumb to `Documents/photos/`, return relative paths;
  AddCar (Agent 3) and Garage (Agent 2) render against it.
- `DesignTokens`, `CurrencyFormat`, `TypographicPlaceholder` — shared UI primitives, frozen so
  agents don't each invent their own.
- `RootView` TabView with **stub tab bodies**, so each agent fills exactly one tab, no shared-file
  edits at integration.

## Phase A — Foundation (sequential, main thread) — spec M1

1. Verify toolchain: `xcodebuild -version` (Xcode 16+), pick iOS 18 simulator.
2. Hand-generate `Blister.xcodeproj` with a single `PBXFileSystemSynchronizedRootGroup`, Swift 6 +
   strict concurrency, iOS 18 deployment target, HEIC photo capability, camera usage strings.
3. `Car` + enums (spec §4 exactly — every prop defaulted/optional, no `@Attribute(.unique)`, so
   CloudKit can switch on later without destructive migration; `Decimal` for money).
4. `ModelContainer+Blister` (+ in-memory variant), `SeedData`, `DesignTokens`, `CurrencyFormat`,
   `TypographicPlaceholder`, `SearchEngine`/`PhotoStore` protocol stubs, `RootView` stub tabs.
5. Garage grid rendering seeded data (M1 acceptance).
6. **GATE:** `xcodebuild build` succeeds AND app launches in simulator showing seeded grid. No
   fan-out until green.

## Phase B — Parallel fan-out (subagents, one disjoint folder each)

Dispatch after Phase A gate is green. Each agent gets: the frozen contracts, its folder, its slice
of the spec, and "Apple frameworks only, Swift 6 strict concurrency, no force-unwrap, `Logger` not
`print`, `String(localized:)` for all strings." Agents do **not** edit `RootView`, the model, or
`Shared/` — they consume them.

- **Agent 1 — Search** (`Search/`): normalization + `searchKey` (spec §5), 4-tier ranking
  (exact → token-prefix → all-tokens-present → Levenshtein ≤2), implements `SearchEngine`. Tests:
  the six `'67 Camaro` normalization queries + **5,000-row seed, assert < 50 ms**. Most isolated,
  pure logic — highest-confidence parallel unit.
- **Agent 2 — Garage** (`Features/Garage/`): 2-col square photo grid, typographic placeholder for
  no-photo, filter chips (brand/hunt/condition/series/year), sort (recent/name/year/value), header
  count + total INR spend. Renders `PhotoStore` thumbs.
- **Agent 3 — AddCar + CarDetail** (`Features/AddCar/`, `Features/CarDetail/`): camera-first flow
  (<15 s target), photo → Documents via `PhotoStore` + thumbnail, single optional-except-name form,
  "Save and add another" keeps camera, autocomplete from own collection; Detail = swipeable photos,
  inline edit, delete-with-confirm, "N variants" link.
- **Agent 4 — Aisle Check** (`Features/AisleCheck/`): bottom-pinned autofocused search field, live
  results via `SearchEngine`, giant IN/NOT IN COLLECTION verdict, all owned colorways of a match,
  one-tap Add-to-Garage / Add-to-Wishlist, `DataScannerViewController` barcode scan wrapped in
  `UIViewControllerRepresentable` (hint-not-proof caveat in UI).
- **Agent 5 — Wishlist + Settings/Export** (`Features/Wishlist/`, `Features/Settings/`): wishlist =
  `status == .wanted` grid, "Found it" status-flip → owned + price prompt (single tap), CSV + JSON
  export via share sheet, photo-storage size readout, app version.

## Phase C — Integration + polish (sequential, main thread) — spec M4/M5

1. Wire the five features into `RootView` tabs; resolve any contract drift.
2. `xcodebuild build` + full `xcodebuild test` green.
3. Empty states, Dynamic Type to XXL pass, VoiceOver labels + 44pt targets, iPad-no-crash /
   landscape-no-crash check, app icon.
4. Walk the §10 acceptance checklist; produce a TestFlight-ready archive config.

## MVP2 plan deliverable

Write `docs/superpowers/specs/2026-07-23-blister-mvp2-plan.md` covering §11, phased and sequenced
by dependency and value:

- **v2.1 Sync foundation:** enable CloudKit via SwiftData (model already sync-safe from Phase A),
  conflict handling, migration test.
- **v2.2 Vision ID:** on-device Vision/CoreML car identification from photo (the headline v2
  feature), fed into Add + Aisle Check.
- **v2.3 Catalog seeding:** Matchbox/Mini GT reference data, India price reference.
- **v2.4 Reach:** widgets (aisle-check quick entry), Apple Watch aisle check.
- **v2.5 Social:** shared/public collection pages, trade & want-list matching between users
  (this one implies a backend — flagged as the scope break that ends "local-first").

Each phase: goal, new/changed model fields, framework additions, risks, acceptance. No code in v2 —
plan only.

## Verification

- Phase gates: `xcodebuild -scheme Blister -destination 'platform=iOS Simulator,name=iPhone 16'
  build` after A and C; `xcodebuild test` after C.
- Search: `@Test` suite must pass the six normalization fixtures and the < 50 ms / 5,000-row perf
  assertion (spec §5, §10).
- Manual/simulator: seeded Garage renders (A); add-a-car < 15 s, force-quit mid-add loses ≤ the
  in-progress car, Aisle Check verdict < 1 s on 1,000 cars, CSV opens in Numbers with INR intact
  (§10).
- Guardrail: `otool -L` / build settings confirm **zero third-party deps** in the product.

## Risks

- **Hand-rolled `.pbxproj`** is the single riskiest artifact. Mitigation: Phase A gate refuses
  fan-out until the project opens in Xcode and `xcodebuild` is green.
- **Contract drift** between Agent 1 (`SearchEngine`) and Agent 4 (Aisle Check). Mitigation: freeze
  the protocol in Phase A; Agent 4 codes against the protocol, not the impl.
- Parallel agents can't compile against each other's in-flight code. Mitigation: disjoint folders +
  frozen contracts + build only on main thread in Phase C.
