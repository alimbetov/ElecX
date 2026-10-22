# P6 qualification status

Branch: `feat/project-structure-authoring`

## Current status

P6 implementation and hardening have landed through the production room-semantics wiring and ownership tests.

The final authored branch HEAD has passed the current executable qualification workflows:

- `dart format --output=none --set-exit-if-changed lib test`
- `flutter analyze`
- `flutter test`
- macOS analyze
- macOS test
- macOS debug build
- runtime `path_provider` smoke

Therefore P6 may be treated as:

```text
P6 domain/application: DONE + HARDENED
macOS qualification: PASS
```

## Cross-platform qualification policy

P6 closure does not mean that every native target has already been executable-qualified.

The branch is desktop-first, not desktop-specific. Windows, Linux, Android, iOS and iPadOS remain required product targets and must preserve the same canonical engineering semantics.

Their current qualification state is tracked independently:

```text
Windows qualification: PENDING
Linux qualification: PENDING
Android qualification: PENDING
iOS qualification: PENDING
iPadOS/tablet qualification: PENDING
```

These pending platform tracks do NOT block P6 closure and do NOT block starting P7, provided that P6 continues to satisfy the portability invariants defined in:

`docs/architecture/native-platform-authoring-qualification-v1.md`

A later platform-specific packaging, plugin, lifecycle or adaptive-layout defect blocks that target's qualification only.

A later defect that exposes platform-specific domain semantics, divergent persistence, device-specific canonical identity, or a platform-only mutation path reopens the responsible architecture stage as a regression and must be fixed at the source boundary.

## P6 portability invariants

Before hand-off to P7, P6 must continue to guarantee:

- one canonical project/domain model for all native platforms;
- the same `SpaceUsage`, adjacency, opening and overlay semantics on every target;
- semantic edits through shared application/domain mutation contracts;
- stable `SpaceId` across semantic edits;
- platform-independent version/undo semantics;
- persistence semantics independent from desktop/mobile presentation;
- no semantic action that requires hover, right click or a macOS-only key binding;
- no desktop-only layout state stored as engineering data;
- no durable `wallIndex` foreign key.

Desktop, tablet and phone may expose different interaction shells while invoking the same semantic commands.

## P6/P7 boundary remains unchanged

P6 owns `SpaceUsage`, openings, adjacency and overlay classifications.

Durable wall identity, `BoundaryEdgeId` lineage, wall-host migration, vertical topology and typical-floor lineage remain P7.

P7 is explicitly NOT blocked by waiting for Windows/Linux/Android/iOS/iPadOS qualification environments.

P7 may proceed from the current P6 baseline as long as stable topology identities and mutation semantics are platform-independent from their first implementation.
