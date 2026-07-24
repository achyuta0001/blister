# Blister v2.1 — enabling CloudKit sync (account-gated)

The app is built **sync-ready but with CloudKit OFF**. The `Car` model is CloudKit-safe (all
properties defaulted/optional, no `@Attribute(.unique)`, enums as raw scalars, `[String]` arrays,
`Decimal` money) and `ModelContainer.blister(cloudKitContainerID:)` already has the seam. Flipping it
on requires a **paid Apple Developer account** and signing configured in Xcode — do the steps below
once that exists. Nothing here changes data, so no migration is needed.

## Design recap

- **Scope:** one user's own devices (iPhone + iPad), offline-first, no account UI beyond the system
  iCloud toggle.
- **Photos are device-local (metadata-only sync).** SwiftData syncs `photoFilenames` (strings), not
  image files. On a second device the files are absent, so `GarageCard` / `WishlistCard` /
  `CarDetailView` fall back to `TypographicPlaceholder` — which is the intended behaviour, already
  in place. Do **not** move images into CloudKit assets unless the photo-sync decision is revisited.

## Enablement steps

1. **Signing:** select the target → Signing & Capabilities → set your Team; let Xcode manage signing.
2. **Add capabilities** (Signing & Capabilities → `+`):
   - **iCloud** → check **CloudKit** → add container **`iCloud.com.blister.app`**.
   - **Background Modes** → check **Remote notifications** (so the store receives push updates).
   This creates `Blister.entitlements` with `com.apple.developer.icloud-services = CloudKit`,
   `icloud-container-identifiers = [iCloud.com.blister.app]`, and
   `aps-environment`. Set `CODE_SIGN_ENTITLEMENTS` if Xcode doesn't wire it automatically.
3. **Flip the container** in `Blister/BlisterApp.swift`:
   ```swift
   let container = ModelContainer.blister(cloudKitContainerID: "iCloud.com.blister.app")
   ```
   (Currently `ModelContainer.blister()` — local.)
4. **Initialise the CloudKit dev schema:** run once on a signed-in device/simulator; SwiftData
   creates the record types in the CloudKit **Development** environment on first launch. Verify the
   `CD_Car` record type appears in the CloudKit Console, then **Deploy Schema to Production** before
   shipping.
5. **Verify:** sign the same iCloud account into two devices, add a car on one, confirm it appears on
   the other within seconds; test airplane-mode edits reconciling on reconnect. (Requires two devices
   + iCloud login — can't be done from a single simulator.)

## Guardrails already in place

`BlisterTests/CloudKitReadinessTests.swift` asserts the schema builds and that a fully-populated
`Car` round-trips through an on-disk store with no field loss — a regression net so a future model
change can't silently break sync-compatibility.

## Not doing

Photo-asset syncing (chose device-local), shared/public collections, and any backend — those are
later v2 phases in `2026-07-23-blister-mvp2-plan.md`.
