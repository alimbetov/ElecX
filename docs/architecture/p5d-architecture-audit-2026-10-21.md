# P5D — Architecture Audit and Pre-implementation Gate

Date: 2026-10-21
Branch: `feat/p5d-opt-in-compass-design`

## Verdict

The original `p5d-opt-in-compass-v1.md` has a sound product boundary, but implementation must **not** start from P5D-A as originally written.

The repository already contains a legacy `ProjectNorth`, a compass overlay, direct editor mutation, true-north/daylight coupling, and a transitional persistence representation. Those existing contracts conflict with the new canonical P5D semantics.

Therefore the implementation sequence is hardened to:

```text
P5D-0  semantic reconciliation + mutation/persistence foundation
P5D-A  canonical orientation value contract
P5D-B  root-metadata mutation support + Project North commands
P5D-C  canonical codec migration + round-trip
P5D-D  shell visibility state
P5D-E  projection/widget migration
P5D-F  production wiring
P5D-G  qualification / closure
```

`P5D-0` is a merge blocker. No UI implementation is accepted before it is closed.

## Finding A1 — Existing ProjectNorth has different semantics

Current code already defines `ProjectNorth` in `site_orientation.dart` as a `double northAzimuthDegrees` describing the relation of the plan frame to **true north**. It defaults to `0` and also provides `toTrueAzimuth()`.

The P5D specification defines a different requirement: a canonical project-plan orientation which must not imply georeferencing, magnetic north, survey north, or verified true north.

These concepts must not share one ambiguous type.

### Required correction

P5D must establish two explicit concepts:

```text
ProjectNorth
  Canonical project engineering direction in the project XY frame.
  Does NOT assert a geospatial/true-north relationship.

TrueNorthReference / SiteTrueNorthReference
  Optional future/geospatial relation between the project frame and true north.
  Used only by capabilities that explicitly require geospatial semantics.
```

The exact second type name may be chosen during implementation, but ambiguity is forbidden.

The current legacy `ProjectNorth` type must not simply be reinterpreted in-place because `DaylightAssistEngine` currently calls `toTrueAzimuth()` and therefore depends on its true-north meaning.

### Migration rule

Before changing the old type, all consumers must be enumerated. Daylight/solar consumers must either:

1. migrate to the explicit true-north reference type; or
2. remain behind a compatibility adapter until that migration is complete.

The new P5D compass must consume canonical project engineering north, not the legacy true-north helper by accident.

## Finding A2 — Legacy ProjectSite fabricates 0 degrees

The transitional `ProjectSite` currently declares a non-null `projectNorth` and defaults it to `ProjectNorth()` which means `0°`.

The legacy editor JSON also serializes this value as `projectNorthDegrees`.

This means older/transitional project files cannot reliably distinguish:

```text
0° explicitly confirmed by an engineer
```

from:

```text
0° supplied by a historical default
```

### Required correction

The canonical P5D migration must be fail-closed:

```text
legacy/transitional projectNorthDegrees
without explicit provenance proving user confirmation
→ canonical ProjectNorth = unspecified
```

Do **not** promote a legacy `0°` value into canonical state merely because the old object is non-null.

If later a schema version gains explicit provenance such as `projectNorthConfirmed=true`, that proven value may be migrated. Existing schemas do not provide that proof.

The transitional legacy value may continue to exist temporarily for compatibility, but it is not canonical P5D authority.

## Finding A3 — Existing compass is always visible and directly coupled to legacy state

`UnifiedWorkspaceEditorScreen` currently inserts `ProjectCompassOverlay` whenever `planContext` is true. The overlay receives `workspace.site.site.projectNorth` directly and clicking it invokes `_editProjectNorth()`.

`_editProjectNorth()` calls `workspace.updateProjectNorth(...)` directly.

This violates P5D requirements in three ways:

```text
compass is visible by default
legacy workspace is treated as Project North authority
domain mutation bypasses P3 canonical mutation semantics
```

### Required correction

In P5D production mode:

- the existing always-visible compass insertion must be removed/replaced;
- visibility must come only from shell presentation state;
- editing must call a canonical application command;
- legacy workspace state may be a temporary projection only;
- no widget may call `workspace.updateProjectNorth()` as the authoritative edit path.

A non-P5D legacy fallback may remain temporarily only if it is explicitly isolated and cannot claim canonical persistence or canonical Project North authority.

## Finding A4 — ProjectAggregateRoot has no root metadata mutation channel

`ProjectAggregateRoot` currently contains:

```text
id
siteId
version
stores
index
```

The P3 command system also accepts `ProjectCommandCandidate(stores: ...)`, computes `ProjectEntityDiff` only from entity stores, and stores only before/after stores in `UndoRecord`.

Therefore adding `ProjectNorth` directly to the aggregate without first extending P3 would create a critical defect:

```text
root metadata changes
→ ProjectEntityDiff remains empty
→ ProjectChangeSet rejects the commit as empty
→ Undo/Redo cannot restore root metadata
```

### Required correction

P5D must first extend the canonical mutation boundary to support root-level project metadata.

Recommended shape:

```dart
final class ProjectRootMetadata {
  final ProjectNorth? projectNorth;
}

final class ProjectCommandCandidate {
  final ProjectRootMetadata metadata;
  final ProjectEntityStores stores;
}
```

or an equivalent immutable root-state contract.

The authoritative change set must distinguish entity changes from root metadata changes, conceptually:

```dart
ProjectChangeSet {
  ProjectEntityDiff entityDiff;
  ProjectMetadataDiff metadataDiff;
}
```

A committed change set is non-empty when either diff is non-empty.

Undo/Redo must snapshot/restore all canonical mutable project state participating in the command, not only entity stores.

### Non-negotiable tests

```text
metadata-only SetProjectNorth commits
metadata-only same-value SetProjectNorth is no-op
undo restores previous ProjectNorth
redo restores new ProjectNorth
entity-only commands retain existing behavior
mixed future candidate can diff both metadata and stores deterministically
```

Do not encode Project North as a fake Site/Building entity update merely to satisfy the existing entity diff machinery.

## Finding A5 — Canonical codec v1 cannot round-trip ProjectNorth

`CanonicalProjectDocumentCodec` currently uses strict schema version `1` and serializes metadata plus site/building/level/zone/space stores. There is no Project North field and decode rejects every schema version other than exactly `1`.

### Required correction

P5D must introduce an explicit canonical schema migration policy.

Recommended:

```text
canonical schema v1
→ canonical schema v2
→ projectNorthMilliDegrees = null
```

for old canonical documents.

New v2 documents may encode:

```json
"projectOrientation": {
  "projectNorthMilliDegrees": 32500
}
```

or `null` when unspecified.

Do not overload unrelated metadata fields and do not serialize a floating-point canonical angle.

The decoder must accept supported old versions through deterministic migration rather than changing the meaning of schema v1 in place.

### Semantic fingerprint

Every canonical semantic fingerprint/equality qualification used for round-trip tests must include Project North. A codec test that ignores root orientation is insufficient because loss of Project North could still appear as a successful round-trip.

## Finding A6 — Existing legacy JSON has orientation, but it is not the P5D persistence owner

`EditorProjectDocument` currently persists transitional `ProjectSite.projectNorth` as a floating-point `projectNorthDegrees` field.

That does not make it an acceptable P5D canonical persistence path.

### Required correction

P5D production editing must be enabled only when the canonical owner can persist the new root metadata through the canonical repository/codec boundary.

The screen must not solve durability by writing the new canonical Project North back through legacy `EditorProjectDocument` directly from a widget.

If canonical persistence ownership is unavailable:

```text
Compass visibility toggle  ENABLED
Project North read-only/not-set presentation  ENABLED
Set/Edit Project North  DISABLED
```

This mirrors the P5C fail-closed authoring ownership rule.

## Finding A7 — WorldCamera currently has no rotation

The current `WorldCamera` supports pan/zoom only. Its world/screen conversion is:

```text
project +X → screen right
project +Y → screen up
```

There is no viewport rotation state.

### Required correction

Current P5D implementation must use a deterministic direct projection and must **not** invent a viewport-rotation subsystem.

For the current camera:

```text
ProjectNorth 0°   → arrow screen up
ProjectNorth 90°  → arrow screen right
ProjectNorth 180° → arrow screen down
ProjectNorth 270° → arrow screen left
```

A future rotation input may be added behind a projection interface only when a real viewport rotation feature exists.

P5D tests must lock these four cardinal projections.

## Finding A8 — Existing compass widget is a prototype, not the P5D contract

`ProjectCompassOverlay` currently:

- requires non-null legacy `ProjectNorth`;
- always renders an arrow;
- cannot render `not set`;
- reads the old true-north-oriented type directly;
- has no explicit projection validity state;
- has no focus-mode suppression ownership;
- has no canonical persistence/editability state.

### Required correction

Reuse visual painter code only behind a new presentation input, for example:

```dart
sealed class CompassProjectionState {
  const CompassProjectionState();
}

final class CompassUnavailable extends CompassProjectionState {}
final class CompassNorthUnspecified extends CompassProjectionState {}
final class CompassNorthDefined extends CompassProjectionState {
  final int screenMilliDegreesClockwiseFromUp;
  final ProjectNorth canonicalNorth;
}
```

Exact API may differ. The important invariant is that the widget receives a resolved presentation state and does not infer canonical/geospatial semantics itself.

## Finding A9 — Shell state is the correct visibility owner

`EditorShellState` already owns transient UI visibility and focus mode. This is the correct P5D owner for requested compass visibility.

Add conceptually:

```dart
bool _compassRequestedVisible = false;
bool get compassRequestedVisible => _compassRequestedVisible;
bool get compassVisible => _compassRequestedVisible && !_focusMode;
```

### Focus-mode rule

The behavior must be explicit:

- entering focus mode suppresses effective compass visibility;
- it does not overwrite requested visibility;
- leaving focus mode restores effective visibility;
- changing the requested Compass toggle while focus mode is active is allowed and affects what happens after focus mode exits;
- no shell visibility operation dirties engineering state.

This differs intentionally from older panel toggles that simply ignore toggle requests during focus mode.

## Finding A10 — Terminology must not imply geospatial certainty

The P5D UI must avoid labels such as `True North`, `Geographic North`, `GPS North`, or `North from device` unless a future feature establishes those semantics.

Use:

```text
Project North
```

with help text that states it is the project engineering reference direction.

The editor may later relate Project North to true north through a separate explicit geospatial reference, but P5D does not infer that relation.

## Hardened domain contract

P5D canonical state should be modelled conceptually as:

```dart
final class ProjectNorth {
  const ProjectNorth._(this.milliDegreesClockwiseFromPositiveY);

  final int milliDegreesClockwiseFromPositiveY;

  static ProjectNorth fromMilliDegrees(int value);
  static ProjectNorth fromDegrees(double value); // UI/import boundary only

  double get degrees;
}

final class ProjectRootMetadata {
  const ProjectRootMetadata({this.projectNorth});
  final ProjectNorth? projectNorth;
}
```

Rules:

- canonical equality uses integer milli-degrees;
- input conversion rejects non-finite values before normalization;
- normalized storage is `[0, 360000)`;
- unspecified is represented by `null`, not `0`;
- `360000`, `-360000`, etc. normalize to `0` only after an explicit user/import value is supplied;
- no default constructor silently creates `0°`.

## Hardened persistence contract

```text
canonical aggregate root metadata
        ↓
ProjectSnapshot
        ↓
ProjectDocumentCodec v2+
        ↓
ProjectRepository
```

Legacy editor JSON remains a transitional compatibility representation and is not the canonical P5D owner.

The canonical codec migration must preserve:

```text
v1 missing orientation → unspecified
v2 null orientation    → unspecified
v2 integer orientation → exact ProjectNorth
```

Malformed/out-of-range persisted raw integers must fail closed with `FormatException`; they must not be silently coerced during decoding.

## Hardened implementation plan

### P5D-0 — reconciliation gate

- inventory all `ProjectNorth`, `toTrueAzimuth`, compass, daylight and legacy persistence consumers;
- split project engineering north from true/geospatial north semantics;
- define compatibility adapter for existing daylight/solar code;
- prove old default `0°` is not promoted as confirmed canonical orientation;
- finalize root metadata and P3 diff/undo contract;
- finalize canonical schema v2 migration.

### P5D-A — canonical value + root metadata

- implement integer `ProjectNorth` without implicit zero default;
- implement nullable/unspecified root metadata;
- add equality/hash/normalization tests;
- add invalid input tests.

### P5D-B — mutation engine extension + commands

- extend candidate/change set/undo/redo for root metadata;
- implement `SetProjectNorthCommand`;
- implement `ClearProjectNorthCommand` only if product UX exposes clearing;
- verify stale version behavior and no-op behavior.

### P5D-C — canonical persistence

- bump canonical document schema;
- add v1→v2 migration;
- round-trip specified and unspecified Project North;
- include orientation in semantic fingerprint/qualification;
- verify repository save/load.

### P5D-D — shell state

- hidden by default;
- requested/effective visibility;
- focus-mode suppression/restoration;
- visibility changes produce no engineering dirty state.

### P5D-E — projection and widget

- direct projection for current non-rotating camera;
- explicit unavailable/not-set/defined presentation states;
- plan-only support initially;
- safe-area overlay placement;
- pointer passthrough outside hit target;
- semantics/light/dark/focus/touch qualification.

### P5D-F — production wiring

- replace current always-visible legacy compass path;
- add discoverable desktop/mobile toggle;
- edit through canonical command only;
- enforce canonical persistence-owner gate;
- preserve P5C navigator/cutover invariants.

### P5D-G — closure qualification

- run domain, mutation, codec, repository and widget tests;
- run P5C regression suite;
- Flutter formatter/analyze/test green;
- macOS Desktop green;
- no P5E/P6/P7/P16 or viewport-rotation scope creep.

## Additional mandatory qualification scenarios

The original D01–D24 remain required. Add:

```text
D25 legacy default 0° does not become confirmed canonical ProjectNorth
D26 old true-north/daylight semantics remain explicit after type reconciliation
D27 metadata-only command creates non-empty canonical change set
D28 metadata-only undo/redo restores exact orientation
D29 canonical v1 document migrates to v2 with ProjectNorth unspecified
D30 canonical v2 malformed orientation fails closed
D31 semantic fingerprint changes when ProjectNorth changes
D32 current camera cardinal projection: 0/up, 90/right, 180/down, 270/left
D33 focus-mode toggle changes requested state without making overlay visible until exit
D34 no direct `workspace.updateProjectNorth()` remains in canonical P5D edit path
```

## Revised merge blockers

In addition to the original P5D blockers, merge is blocked if:

- the legacy true-north `ProjectNorth` is silently redefined without migrating daylight consumers;
- transitional `ProjectSite.projectNorth = 0°` is promoted as confirmed canonical state;
- Project North is encoded as a fake entity mutation;
- P3 metadata-only changes cannot create a valid `ProjectChangeSet`;
- Undo/Redo stores only entity stores after root metadata becomes mutable;
- canonical schema v1 meaning is silently changed in place without a migration contract;
- canonical semantic fingerprint ignores Project North;
- the existing always-visible legacy compass remains active in canonical P5D mode;
- a widget remains the authoritative writer of Project North;
- viewport rotation is introduced merely to support the compass.

## Readiness after this audit

The P5D product concept is accepted, but code implementation is gated by P5D-0.

Status:

```text
P5D specification concept       PASS
scope isolation                 PASS
existing-code reconciliation    REQUIRED
P3 root-metadata support        REQUIRED
canonical schema migration      REQUIRED
legacy default/provenance rule  REQUIRED
UI/pointer/a11y contract        PASS WITH HARDENING
implementation readiness        READY FOR P5D-0 ONLY
```

P5D-A and later must not begin until the P5D-0 decisions above are implemented or explicitly resolved in code-level contracts.