# P5D — Opt-in Compass v1

## Status

Hardened architecture and implementation specification for `feat/p5d-opt-in-compass-design`.

This document incorporates two repository-level architecture reviews performed on 2026-10-21. The second hard audit is authoritative for implementation readiness:

```text
docs/architecture/p5d-architecture-audit-v2-2026-10-21.md
```

P5D follows P5C and must preserve the P5C canonical-navigation, controlled-hybrid, persistence-owner and fail-closed invariants.

ElecX remains native-only:

- macOS
- Windows
- Linux
- Android
- iOS
- iPadOS

Web/browser runtime is out of scope.

---

## 1. Objective

Add a discoverable, opt-in compass that communicates the canonical engineering orientation of the project without becoming:

- a second navigation model;
- a viewport-transform owner;
- a geospatial/true-north subsystem;
- a widget-owned persistence path;
- a bypass around P3 canonical mutation semantics.

The compass is hidden by default and appears only after an explicit user action.

The overlay answers one question only:

```text
Where is canonical Project North relative to the current plan view?
```

It must not imply magnetic north, GPS heading, survey north, geographic north, device heading, or verified true north.

---

## 2. Non-negotiable architecture split

The repository already contains a legacy `ProjectNorth` whose semantics are tied to true-north/daylight calculations. P5D must not silently reinterpret that type.

P5D establishes two different concepts:

```text
Canonical Project North
  engineering reference direction inside canonical project XY
  no geospatial claim

True North Reference
  optional relation between project frame and geographic true north
  used only by explicit geospatial/daylight capabilities
```

Recommended end-state names:

```dart
final class ProjectNorth { ... }
final class TrueNorthReference { ... }
```

The exact migration may retain a compatibility adapter temporarily, but one type must never carry both meanings.

### 2.1 Exact TrueNorthReference sign convention

The current legacy behavior must be preserved explicitly rather than by name coincidence.

Define the geospatial compatibility value as:

```text
trueNorthClockwiseFromProjectPositiveY
```

with:

```text
0°   -> project +Y is true north
90°  -> true north lies toward project +X
```

For an existing plan-space clockwise azimuth `planAzimuth` measured from project `+Y`, the current daylight world azimuth relation is preserved as:

```text
trueAzimuth = normalize(planAzimuth - trueNorthClockwiseFromProjectPositiveY)
```

If implementation chooses a different internal sign convention, the adapter must preserve this observable behavior exactly and qualification must prove it.

### 2.2 Daylight compatibility invariant

`DaylightAssistEngine` currently depends on true-north semantics. P5D must preserve that behavior explicitly.

After reconciliation:

```text
DaylightAssistEngine
-> consumes TrueNorthReference or compatibility adapter
-> never consumes canonical ProjectNorth by accident
```

P5D compass projection:

```text
ProjectNorth
-> viewport projection
-> screen arrow
```

These are separate pipelines.

---

## 3. Canonical coordinate contract

The canonical plan plane is:

```text
+X -> project right
+Y -> project up
```

P5D defines `ProjectNorth` as clockwise angle from canonical project `+Y`.

```text
0°   -> +Y
90°  -> +X
180° -> -Y
270° -> -X
```

Flutter screen coordinates are not part of the domain model.

### 3.1 Canonical ProjectNorth value

Use integer milli-degrees and separate user/import normalization from persisted canonical decoding.

Conceptual API:

```dart
final class ProjectNorth {
  const ProjectNorth._(this.milliDegreesClockwiseFromPositiveY);

  final int milliDegreesClockwiseFromPositiveY;

  static ProjectNorth fromNormalizedMilliDegrees(int value);
  static ProjectNorth fromDegrees(double value);

  double get degrees;
}
```

Canonical normalized range:

```text
0 <= milliDegreesClockwiseFromPositiveY < 360000
```

Rules:

- canonical equality/hash use the integer value;
- `NaN` and `Infinity` are rejected before arithmetic;
- UI/import degrees are converted to nearest milli-degree, then normalized;
- persisted canonical milli-degrees are validated strictly and never normalized silently;
- unspecified Project North is **not** `0`;
- no default constructor may fabricate `0°`.

Deterministic conversion examples:

```text
32.5004°  -> 32500
32.5006°  -> 32501
359.9996° -> 0 after explicit-input rounding + normalization
-0.0006°  -> 359999
360°      -> 0
```

Exact tie behavior must follow Dart's chosen integer rounding primitive and be locked by tests; do not implement two different rounding policies across UI/import paths.

### 3.2 Unspecified state

Canonical root metadata uses nullable Project North:

```dart
final class ProjectEngineeringMetadata {
  const ProjectEngineeringMetadata({this.projectNorth});

  final ProjectNorth? projectNorth;
}
```

`ProjectEngineeringMetadata` is intentionally named differently from `ProjectSnapshot` envelope metadata (`name`, `createdAt`, `updatedAt`).

Semantics:

```text
null = engineer has not established Project North
0°   = engineer explicitly established North along +Y
```

These states are not interchangeable.

The metadata value object requires deterministic equality/hash semantics.

---

## 4. Legacy migration and provenance

The transitional legacy `ProjectSite` currently defaults orientation to `0°` and legacy editor JSON persists `projectNorthDegrees` without provenance proving user confirmation.

Therefore canonical migration is fail-closed:

```text
legacy/transitional projectNorthDegrees
without explicit confirmation provenance
-> canonical projectNorth = null
```

This rule applies even when the legacy numeric value is non-zero. The historical field is not treated as canonical authority unless a schema explicitly proves user confirmation.

P5D must never promote historical default `0°` into a confirmed canonical orientation.

If a future compatibility schema adds explicit provenance, for example:

```json
{
  "projectNorthConfirmed": true,
  "projectNorthDegrees": 32.5
}
```

only then may compatibility migration promote it into canonical `ProjectNorth`.

---

## 5. Canonical root ownership

Project North is project-level canonical engineering metadata.

Required root shape:

```dart
final class ProjectAggregateRoot {
  final ProjectId id;
  final SiteId siteId;
  final LocalProjectVersion version;
  final ProjectEngineeringMetadata engineeringMetadata;
  final ProjectEntityStores stores;
  final ProjectIndex index;
}
```

Project North is not owned by:

- `ProjectSnapshot` envelope metadata;
- `EditorController`;
- `EditorBuildingWorkspace`;
- Level;
- Zone;
- Room/Space;
- `ProjectNavigationState`;
- compass widget;
- viewport camera.

---

## 6. P3 mutation model extension

P5D cannot be implemented correctly while P3 changes only `ProjectEntityStores`.

The mutation boundary must represent all mutable canonical root state.

Recommended immutable state contract:

```dart
final class ProjectMutableState {
  final ProjectEngineeringMetadata engineeringMetadata;
  final ProjectEntityStores stores;
}
```

Then:

```dart
final class ProjectCommandCandidate {
  final ProjectMutableState state;
  final Set<EntityId> declaredAffectedEntityIds;
}
```

Equivalent APIs are acceptable if the same invariants hold.

`ProjectId`, root `SiteId` and `LocalProjectVersion` are not command-mutable fields inside `ProjectMutableState`.

### 6.1 Authoritative metadata diff

Do not model metadata change as a single opaque boolean. The diff must preserve before/after values for diagnostics, tests and future incremental publication.

Conceptual shape:

```dart
final class ProjectEngineeringMetadataDiff {
  const ProjectEngineeringMetadataDiff({
    required this.beforeProjectNorth,
    required this.afterProjectNorth,
  });

  final ProjectNorth? beforeProjectNorth;
  final ProjectNorth? afterProjectNorth;

  bool get projectNorthChanged => beforeProjectNorth != afterProjectNorth;
  bool get isEmpty => !projectNorthChanged;
}
```

`ProjectChangeSet`:

```dart
final class ProjectChangeSet {
  final ProjectEntityDiff entityDiff;
  final ProjectEngineeringMetadataDiff engineeringMetadataDiff;
}
```

Commit is non-empty when:

```text
entityDiff is non-empty
OR
engineeringMetadataDiff is non-empty
```

A metadata-only mutation is a valid first-class commit.

`affectedEntityIds` remains entity-only. Root metadata changes must not fabricate an `EntityId`. Consumers needing root invalidation inspect `engineeringMetadataDiff` explicitly.

### 6.2 Undo/Redo

Undo history must snapshot all canonical mutable state participating in a command:

```dart
final class UndoRecord {
  final ProjectMutableState beforeState;
  final ProjectMutableState afterState;
}
```

Storing only `beforeStores/afterStores` becomes invalid once Project North is mutable.

Undo/Redo invariants:

- restore exact engineering metadata + entity state;
- LocalProjectVersion remains monotonic;
- one semantic command -> one UndoRecord;
- no-op creates no record;
- entity-only commands preserve current behavior;
- impossible empty undo/redo state is treated as invariant corruption rather than a successful no-op.

### 6.3 Commands

P5D commands:

```dart
SetProjectNorthCommand(ProjectNorth north)
ClearProjectNorthCommand()
```

`ClearProjectNorthCommand` is implemented only if product UX exposes clearing, but the architecture must support `null` engineering metadata.

Required Set semantics:

```text
validate request
-> verify expected LocalProjectVersion
-> build immutable candidate root state
-> candidate graph/root validation
-> compute entity + engineering-metadata diff
-> no-op if both diffs empty
-> atomic in-memory commit
-> LocalProjectVersion + 1 exactly once
-> one publication
-> one UndoRecord
```

Same normalized Project North is a no-op.

Compass visibility never enters this command path.

---

## 7. Candidate validation

Candidate validation must remain fail-closed.

For P5D metadata this means:

- `ProjectNorth` is normalized/validated by its value type;
- persisted corruption uses the strict constructor and is rejected before aggregate construction;
- entity graph validation remains unchanged;
- metadata validation does not fabricate defaults;
- candidate construction cannot mutate the live root before validation succeeds;
- candidate keeps the same `ProjectId` and root `SiteId` as current state.

No fake Site/Building entity mutation may be used merely to force a non-empty `ProjectEntityDiff`.

---

## 8. Canonical persistence contract

Persistence path:

```text
ProjectAggregateRoot.engineeringMetadata
        ↓
ProjectSnapshot.aggregate
        ↓
CanonicalProjectDocumentCodec
        ↓
ProjectRepository
```

P5D does not require Drift/SQLite and must not pull P16 forward.

### 8.1 Canonical codec schema v2

Current canonical schema v1 contains no orientation. P5D introduces an explicit schema migration.

New schema:

```json
{
  "schemaVersion": 2,
  "metadata": { ... },
  "projectOrientation": {
    "projectNorthMilliDegrees": 32500
  },
  "sites": [ ... ],
  "buildings": [ ... ],
  "levels": [ ... ],
  "zones": [ ... ],
  "spaces": [ ... ]
}
```

Unspecified:

```json
"projectOrientation": {
  "projectNorthMilliDegrees": null
}
```

### 8.2 Migration

Canonical v1 decoding must migrate deterministically:

```text
v1 missing projectOrientation
-> v2 projectNorth = null
```

Do not silently change the semantic meaning of schema v1 in place.

Decoder rules:

```text
v1 -> migrate to v2 -> decode
v2 null -> unspecified
v2 integer in [0,359999] -> ProjectNorth.fromNormalizedMilliDegrees
v2 malformed/non-integer/out-of-range -> FormatException
future unsupported version -> fail closed
```

The canonical codec should use an explicit migration step/function rather than scattered version conditionals throughout entity decoding.

### 8.3 Semantic fingerprint

Every canonical semantic fingerprint/equality qualification must include engineering root metadata.

Projects differing only by Project North must have different semantic fingerprints.

### 8.4 Sync/export boundary

The current `ProjectSyncGateway` transports `EditorProjectDocument`, not the canonical `ProjectSnapshot`/codec. Therefore it cannot be claimed to preserve P5D canonical orientation.

P5D does not redesign backend sync, but silent data loss is forbidden:

```text
legacy sync/export path
-> may remain operational for legacy editor state
-> must not claim canonical ProjectNorth preservation
```

If a production workflow enables canonical Project North editing and also advertises cross-device/remote sync of that canonical state, the sync contract must be extended to carry the canonical v2 representation before that claim is valid.

Remote sync integration itself is outside P5D closure only if the product path does not promise remote preservation of P5D metadata.

---

## 9. Transitional legacy persistence and ownership transfer

`EditorProjectDocument` may continue to contain historical `projectNorthDegrees` for compatibility.

It is **not** the P5D canonical persistence owner.

Production editing rule:

```text
canonical ownership-transfer boundary available
-> Project North edit enabled

canonical ownership-transfer boundary unavailable
-> visibility toggle enabled
-> read-only/not-set presentation enabled
-> edit disabled
```

P5C already models synchronous ownership acceptance through `CanonicalAuthoringOwnershipReceipt`. P5D should reuse the same ownership principle rather than inventing a second durability model.

Important distinction:

```text
mutation commit accepted by host != durable disk/backend save completed
```

P5D must not claim transactional disk durability from the synchronous receipt. After commit, durable save may happen through the canonical repository workflow. A later save failure means the canonical project remains modified/unpersisted; it is not silently rolled back to legacy state.

No widget may solve durability by writing canonical Project North directly into `EditorProjectDocument`.

No canonical value may be inferred back from legacy `projectNorthDegrees` without explicit provenance.

---

## 10. Runtime identity affinity

Project North is root-scoped. Therefore production edit capability must be bound to the exact canonical project represented by the current screen runtime.

Before enabling edit, runtime resolution must prove:

```text
screen/document project identity
== canonical session ProjectId
== persistence owner project identity
```

A stale runtime/binding left over from open/recovery/project replacement must never be allowed to mutate a different canonical project.

The P5C resolver lifecycle remains authoritative: replacement of the concrete legacy workspace must cause canonical runtime re-resolution before Project North edit can become enabled again.

---

## 11. Shell visibility state

Compass visibility is transient editor-shell state.

Required shape:

```dart
final class EditorShellState extends ChangeNotifier {
  bool _compassRequestedVisible = false;

  bool get compassRequestedVisible => _compassRequestedVisible;
  bool get compassVisible => _compassRequestedVisible && !_focusMode;

  void toggleCompass();
}
```

Rules:

- initial hidden;
- toggling does not mutate canonical project;
- no `ProjectChangeSet`;
- no LocalProjectVersion change;
- no legacy dirty flag;
- entering Focus Mode suppresses effective visibility but preserves requested visibility;
- leaving Focus Mode restores it;
- changing requested visibility while Focus Mode is active is allowed and only affects post-focus state.

Compass visibility is not persisted in engineering project files in P5D.

---

## 12. Projection contract

Current `WorldCamera` has pan/zoom but no rotation.

Therefore P5D v1 uses direct projection:

```text
ProjectNorth 0°   -> screen up
ProjectNorth 90°  -> screen right
ProjectNorth 180° -> screen down
ProjectNorth 270° -> screen left
```

P5D must not invent viewport rotation solely for compass rendering.

Define a presentation projection boundary so future camera rotation can be added without changing domain semantics.

Recommended state:

```dart
sealed class CompassProjectionState {}

final class CompassUnavailable extends CompassProjectionState {}

final class CompassNorthUnspecified extends CompassProjectionState {}

final class CompassNorthDefined extends CompassProjectionState {
  final ProjectNorth canonicalNorth;
  final int screenMilliDegreesClockwiseFromUp;
}
```

The widget consumes this resolved state; it must not read canonical aggregate or legacy workspace directly.

---

## 13. Supported editor modes

P5D v1 projection policy:

- Plan view: supported.
- Room world view: hidden.
- Wall/floor/ceiling surface view: hidden.
- Site/outdoor: hidden in P5D v1 unless a later explicit contract proves the exact same canonical frame.
- blocked P5C materialization state: fail closed; no stale or misleading compass over stale canvas.

Unsupported projection returns `CompassUnavailable`.

---

## 14. UI contract

### 14.1 Existing legacy compass path

Current always-visible `ProjectCompassOverlay(workspace.site.site.projectNorth)` is transitional behavior and must not survive in canonical P5D mode.

The production P5D path must be:

```text
canonical root engineering metadata
-> projection adapter
-> CompassProjectionState
-> ProjectCompassOverlay
```

The authoritative edit path must never call `workspace.updateProjectNorth()`.

### 14.2 Application edit port

The widget must not construct `ProjectMutationRequest` directly.

Production wiring should expose a narrow application capability, conceptually:

```dart
abstract interface class ProjectNorthEditingPort {
  ProjectNorth? get currentProjectNorth;
  bool get canEdit;

  CanonicalAuthoringOwnershipReceipt setProjectNorth(ProjectNorth value);
  CanonicalAuthoringOwnershipReceipt clearProjectNorth();
}
```

Exact signatures may carry typed results/change sets, but the invariant is:

```text
widget -> application edit port -> P3 session -> ownership transfer
```

not:

```text
widget -> raw stores/workspace mutation
```

### 14.3 Desktop control

Provide a discoverable View/app-bar/menu control:

```text
[✓] Compass
```

Requirements:

- visible label or tooltip;
- keyboard reachable;
- semantic checked state;
- no gesture-only hidden activation.

### 14.4 Mobile/tablet

Expose the same semantic toggle in an adaptive menu/sheet.

Touch target must be at least practical platform minimum and no smaller than existing editor control policy.

### 14.5 Overlay placement

Overlay belongs to viewport-safe overlay layout, not raw screen coordinates.

Must account for:

- app bar;
- navigator/drawer;
- inspector;
- context bar;
- floating authoring controls;
- safe area/notches;
- P5C blocked-state UI.

Only the compass hit target may consume pointer events. The remaining overlay layer must pass gestures to the canvas.

---

## 15. Edit flow

When canonical editing is enabled:

```text
Project North
Angle: [ 32.500° ]

[ Cancel ] [ Apply ]
```

Apply:

```text
parse finite input
-> ProjectNorth.fromDegrees
-> ProjectNorthEditingPort
-> P3 SetProjectNorthCommand
-> host ownership receipt
-> canonical persistence workflow marks/queues durable save
-> projection refresh
```

Cancel:

```text
no mutation
no version change
no dirty state
```

If ownership transfer fails after in-memory commit, the failure must be surfaced as a committed-but-not-owned/persisted fault. The UI must not pretend the command was rolled back unless an explicit compensating mutation actually occurs.

The editor dialog itself is not the state owner.

---

## 16. Accessibility

Defined orientation semantics:

```text
Compass, Project North 32.5 degrees clockwise from project up
```

Unspecified:

```text
Compass, Project North not set
```

Requirements:

- visible `N` marker only when orientation is defined;
- text/semantic not-set state when undefined;
- keyboard focus and Enter/Space activation on desktop;
- screen-reader state;
- focus indication not color-only;
- sufficient contrast in light and dark themes;
- no color-only direction communication;
- no inaccessible tiny hit target.

---

## 17. Error handling

User/import input:

```text
empty/unparsable -> validation error
NaN/Infinity     -> validation error
same normalized  -> no-op
```

Persisted canonical corruption:

```text
wrong type
negative raw milli-degrees
>= 360000 raw milli-degrees
malformed object
-> FormatException
```

Projection failure:

```text
-> CompassUnavailable
-> no project mutation
-> no canvas rotation
-> optional diagnostic
```

Ownership/persistence failure:

```text
-> never mutate legacy Project North as fallback
-> never fabricate successful durability
-> preserve exact committed canonical state
-> expose modified/unpersisted/error state through host workflow
```

---

## 18. P5C compatibility invariants

P5D must not weaken P5C.

Specifically:

- no new navigation source of truth;
- no `levelNumber` identity use;
- no direct structural mutation in widgets;
- no bypass of `CanonicalEditorRuntimeCutoverCoordinator` for structural navigation;
- no new legacy persistence ownership claim;
- no synthetic Room geometry;
- no compass action may change Building/Level/Zone/Space navigation;
- blocked canonical target must not reveal stale legacy canvas merely to host the compass;
- open/recovery/project replacement must invalidate stale P5D edit capability together with stale P5C runtime binding.

Project North is orthogonal to `ProjectNavigationState`.

---

## 19. Hardened implementation sequence

### P5D-0 — semantic reconciliation gate

- inventory all current `ProjectNorth`, `toTrueAzimuth`, compass, daylight, legacy persistence consumers;
- split canonical Project North from true/geospatial north semantics;
- lock exact compatibility sign convention;
- define compatibility path for daylight/solar;
- lock legacy provenance rule;
- finalize root engineering metadata mutation state contract;
- finalize canonical codec v1→v2 migration contract;
- define runtime identity-affinity and ownership-transfer contract.

### P5D-A — canonical orientation value + root metadata

- strict normalized milli-degree constructor;
- explicit user/import degree normalization constructor;
- nullable `ProjectEngineeringMetadata.projectNorth`;
- aggregate root field;
- equality/hash/normalization tests;
- invalid input tests.

### P5D-B — P3 root-metadata mutation support

- full `ProjectMutableState` or equivalent candidate state;
- before/after `ProjectEngineeringMetadataDiff`;
- metadata-aware `ProjectChangeSet`;
- metadata-aware Undo/Redo;
- `SetProjectNorthCommand`;
- `ClearProjectNorthCommand` if exposed;
- no-op/stale version/invariant-corruption tests.

### P5D-C — canonical persistence

- canonical schema v2;
- dedicated v1→v2 migration step;
- exact specified/unspecified round-trip;
- repository save/load;
- semantic fingerprint includes engineering root metadata;
- explicit statement that legacy sync does not preserve canonical P5D metadata.

### P5D-D — shell presentation state

- hidden by default;
- requested/effective visibility;
- focus-mode suppression/restoration;
- no engineering dirty state.

### P5D-E — projection + widget

- explicit unavailable/not-set/defined projection states;
- cardinal projection qualification;
- plan-only fail-closed support;
- safe layout;
- pointer passthrough;
- light/dark/focus/touch/accessibility qualification.

### P5D-F — production wiring

- replace current always-visible legacy compass in canonical mode;
- desktop/mobile toggle;
- narrow `ProjectNorthEditingPort` or equivalent;
- canonical ownership-transfer gate;
- exact project identity affinity;
- no `workspace.updateProjectNorth()` in canonical path;
- P5C regression qualification.

### P5D-G — closure

- domain/mutation/codec/repository/widget tests;
- P5C regression suite;
- formatter/analyze/test green;
- macOS Desktop green;
- no P5E/P6/P7/P16/viewport-rotation scope creep.

---

## 20. Qualification matrix

Mandatory scenarios:

```text
D01 new session starts with compass hidden
D02 show compass does not increment LocalProjectVersion
D03 show compass does not mark legacy document Modified
D04 hide compass does not mutate ProjectNorth
D05 focus mode suppresses visible compass
D06 leaving focus mode restores requested visibility
D07 unspecified ProjectNorth shows explicit not-set state
D08 explicit 0° points North along +Y / screen up
D09 explicit 90° points North along +X / screen right
D10 180° points screen down
D11 270° points screen left
D12 user angle normalization is deterministic
D13 strict persisted constructor rejects out-of-range milli-degrees
D14 NaN/Infinity/unparsable values are rejected
D15 same normalized SetProjectNorth is a no-op
D16 metadata-only SetProjectNorth creates one valid ProjectChangeSet
D17 metadata-only commit advances LocalProjectVersion exactly once
D18 metadata-only commit creates one UndoRecord
D19 metadata diff exposes exact before/after ProjectNorth
D20 undo restores previous ProjectNorth exactly
D21 redo restores edited ProjectNorth exactly
D22 entity-only commands retain existing P3 behavior
D23 mixed metadata+entity diff is deterministic
D24 canonical schema v1 migrates to v2 with ProjectNorth unspecified
D25 canonical v2 null round-trips as unspecified
D26 canonical v2 integer round-trips exactly
D27 canonical malformed orientation fails closed
D28 canonical semantic fingerprint changes with ProjectNorth
D29 repository save/load preserves ProjectNorth
D30 legacy default 0° does not become confirmed canonical ProjectNorth
D31 legacy non-zero projectNorthDegrees without provenance also remains unconfirmed
D32 daylight true-north compatibility preserves old sign/azimuth behavior
D33 canonical ProjectNorth does not feed true-north/daylight conversion implicitly
D34 compass absent in unsupported editor projection modes
D35 compass toggle keyboard accessible
D36 screen-reader semantics expose orientation/not-set state
D37 compass hit target does not intercept unrelated canvas gestures
D38 overlay does not cover primary authoring controls
D39 focus-mode toggle may change requested state while overlay remains suppressed
D40 P5C navigator/cutover behavior remains unchanged
D41 same-number Levels in different Buildings have no effect on compass identity
D42 canonical P5D edit path contains no workspace.updateProjectNorth()
D43 project replacement/recovery invalidates stale ProjectNorth edit capability
D44 runtime refuses edit when screen/canonical/persistence project identities differ
D45 ownership receipt is not reported as durable save completion
D46 legacy ProjectSyncGateway is not claimed to preserve canonical ProjectNorth
D47 no fake EntityId is added for root metadata invalidation
D48 no Web/browser implementation or dependency introduced
```

---

## 21. Merge blockers

P5D is not complete if any condition below is true:

- compass is visible by default;
- visibility dirties engineering state;
- legacy `ProjectNorth` true-north semantics are silently redefined;
- exact existing daylight azimuth sign behavior is not preserved or intentionally migrated with proof;
- daylight consumes canonical engineering Project North as though it were geographic true north;
- transitional legacy orientation is promoted without provenance;
- unspecified is represented as `0°`;
- persisted corruption is silently modulo-normalized;
- Project North is stored only in widget/controller state;
- Project North is encoded as a fake entity mutation;
- metadata diff omits before/after values;
- metadata-only changes cannot create valid `ProjectChangeSet`;
- Undo/Redo still snapshots only entity stores after metadata becomes mutable;
- canonical schema v1 meaning is changed in place;
- canonical codec does not migrate v1→v2 explicitly;
- semantic fingerprint ignores Project North;
- production widget constructs raw root/store mutation directly instead of using an application edit boundary;
- production edit bypasses P3;
- production edit lacks canonical ownership transfer;
- runtime cannot prove exact project identity affinity;
- canonical path calls `workspace.updateProjectNorth()`;
- legacy sync is advertised as preserving P5D canonical orientation when it cannot;
- unsupported modes show a misleading compass;
- overlay intercepts unrelated gestures;
- focus mode loses requested visibility;
- accessibility exposes only an unlabeled arrow/icon;
- viewport rotation is introduced solely for the compass;
- P5D introduces device sensors, GPS/georeferencing, P5E, P6, P7, P16 or web scope.

---

## 22. Closure definition

P5D may be marked `CLOSED` only when:

```text
- ProjectNorth and TrueNorthReference semantics are unambiguous
- old daylight azimuth behavior is explicitly preserved/qualified
- legacy orientation provenance is handled fail-closed
- root engineering metadata participates in P3 diff/commit/undo/redo
- canonical schema v2 migrates and round-trips orientation safely
- runtime project identity affinity is proven before edit
- ownership transfer is explicit and not confused with durable save
- compass is opt-in and hidden by default
- shell visibility remains presentation-only
- projection is fail-closed and does not invent viewport rotation
- production editing uses application command boundary + ownership owner
- pointer/keyboard/accessibility behavior is qualified
- P5C regressions remain green
- Flutter and macOS Desktop gates are green
```

Expected closure statement:

```text
P5D CLOSED

Included:
- canonical integer ProjectNorth
- explicit separation from true/geospatial north
- exact daylight compatibility contract
- root engineering metadata mutation support
- metadata-aware Undo/Redo
- canonical schema v2 migration
- opt-in compass overlay
- desktop/mobile toggle
- focus-mode suppression
- canonical Project North edit application port
- runtime identity-affinity gate
- accessibility/pointer qualification

Deferred:
- viewport rotation feature
- device compass / magnetometer
- GPS/georeferencing / magnetic declination
- backend sync transport of canonical P5D metadata unless separately implemented
- per-building transforms
- P5E Room Surface Navigator
- P6/P7 model expansion
- P16 Drift/SQLite
```
