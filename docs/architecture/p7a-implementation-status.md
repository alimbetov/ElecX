# P7A Stable Boundary Topology — implementation status

Branch: `feat/project-structure-authoring`

## Current status

**P7A: IN PROGRESS.**

P7A-1 domain foundation, P7A-2 canonical aggregate ownership and P7A-3 persistence are **DONE + HARDENED**. P7A-4.1 through P7A-4.4 are **DONE + HARDENED + QUALIFIED**, including production Room Surface Navigator cutover and stable room-surface resume. The P7A-4.5 canonical topology-editing core is now implemented, production-wired and qualified; its remaining closure item is canonical production history/undo ownership and rematerialization. Hosted-object migration remains P7A-5 and is deliberately not bypassed by P7A-4.5.

## Landed

### P7A-1 domain foundation

**DONE + HARDENED.**

Implemented:

- stable `BoundaryEdgeId` is the durable edge identity;
- platform-independent `BoundaryPointMm`;
- canonical `ProjectBoundaryEdge` scoped to exact `SpaceId`;
- ordered `SpaceBoundaryTopology` for one exterior loop;
- topology validation for ownership, continuity and closure;
- explicit edge lineage: `preserved`, `split`, `merged`, `created`, `removed`;
- fail-closed host remap decisions;
- duplicate source/result lineage rejection.

### P7A-2 canonical aggregate ownership

**DONE + HARDENED.**

Implemented:

- `ProjectEntityStores.boundaries` is authoritative canonical state keyed by `SpaceId`;
- aggregate validation rejects dangling boundary owners and store-key/owner mismatches;
- duplicate active `BoundaryEdgeId` ownership across spaces is rejected;
- `ProjectIndex` exposes `boundary(SpaceId)`, `boundaryEdge(BoundaryEdgeId)` and `spaceByBoundaryEdgeId`;
- boundary geometry/order participates in canonical diff;
- undo/redo restores topology atomically;
- invalid candidates fail before authoritative state changes;
- removing a Space atomically removes its owned topology;
- legacy/P6 commands cannot accidentally erase boundary state;
- one `BoundaryEdgeId` cannot change historical owning `SpaceId` across mutations.

### P7A-3 persistence foundation

**DONE + HARDENED.**

Implemented:

- canonical project document schema v4;
- exact `BoundaryEdgeId`, ordered membership and millimetre geometry persistence;
- durable `BoundaryEdgeIdentityRegistry` including tombstones;
- ownership survives commit -> undo/remove -> save -> close -> reopen;
- persistence is strict validation, not an identity mutation mechanism;
- deterministic legacy polygon migration produces opaque stable identities;
- corrupt topology/geometry fails closed;
- no platform-specific topology or persistence fork.

Qualification on hardened P7A-3 code HEAD `9632002a5e61deb68b179333d26430d5d8528df6`:

```text
dart format gate           PASS
flutter analyze            PASS
flutter test               PASS
macOS analyze              PASS
macOS test                 PASS
macOS debug build          PASS
runtime path_provider      PASS
```

### P7A-4 production editor cutover

**IN PROGRESS — topology-editing core qualified; canonical production history/undo closure remains.**

#### P7A-4.1 — strict canonical boundary projection

**DONE + HARDENED.**

Implemented:

- `CanonicalRoomBoundaryProjection`;
- `CanonicalEditorWallProjection`;
- `BoundaryEdgeId <-> transient wall ordinal` lookup;
- exact canonical/legacy ordered geometry validation;
- >4-wall rooms supported;
- reordered/stale geometry fails closed;
- invalid canonical topology/geometry fails before editor cutover;
- no nearest-edge, label, rotation or direction guessing.

#### P7A-4.2 — stable room-surface selection

**DONE + HARDENED.**

Implemented:

- `CanonicalRoomSurfaceSelectionAdapter`;
- current legacy wall ordinal projects to stable `BoundaryEdgeId`;
- wall selection accepts `BoundaryEdgeId`;
- ordinal resolution occurs only at the legacy `EditorController.showWall(int)` boundary;
- previous/next navigation rotates canonical `orderedEdgeIds`;
- unknown/stale edge identity fails closed;
- stale materialization can explicitly reconcile the legacy canvas back to Plan;
- successful stable selection verifies its post-condition after the legacy call.

#### P7A-4.3 — production cutover resolver

**DONE + HARDENED.**

`CanonicalRoomSurfaceCutover.resolve(...)` proves the complete ownership chain before projecting a wall:

```text
canonical SpaceId
    -> canonical LevelId
    -> canonical BuildingId
    -> explicit cutover binding
    -> actual legacy Building
    -> active legacy Level
    -> EditorController Level
    -> selected legacy Space
    -> exact boundary materialization
```

Missing topology or identity affinity never falls back to durable ordinal semantics.

#### P7A-4.4 — production Room Surface Navigator wiring

**DONE + HARDENED + QUALIFIED.**

Production wall navigation uses one stable action path:

```text
wall button
mini-view mouse/touch
keyboard Left/Right
previous/next controls
        |
        v
BoundaryEdgeId
        |
        v
fresh CanonicalRoomSurfaceSelectionAdapter
        |
        v
validated transient wall ordinal
        |
        v
legacy EditorController
```

Implemented:

- production `RoomSurfaceNavigator` resolves the selected canonical Room through the P7A cutover runtime;
- wall targets carry `BoundaryEdgeId` in canonical mode;
- `W1`, `W2`, ... remain presentation labels only;
- mouse/touch/keyboard wall actions converge on the same stable-ID selection path;
- canonical mode never falls back to ordinal wall identity when topology/binding is missing;
- stale materialization fails closed and reconciles to Plan;
- standalone pre-cutover/legacy workspaces retain an explicitly named legacy ordinal projection path;
- navigation/collapse remains non-dirty.

Primary implementation:

```text
lib/src/features/editor/room_surface_navigator.dart
lib/src/features/editor/canonical_room_surface_runtime_registry.dart
lib/src/features/editor/canonical_editor_screen_cutover_binding.dart
```

#### P7A-4 stable room-surface resume

**DONE + HARDENED + QUALIFIED.**

The editor resume schema is v5 and adds a canonical surface contract:

```text
CanonicalRoomSurfaceResume
  SpaceId
  kind = plan | floor | ceiling | wall
  BoundaryEdgeId?   // required only for wall
```

Canonical-runtime Save behavior:

- `resume.activeSurface` is written as `null`;
- wall selection is persisted as `SpaceId + BoundaryEdgeId`;
- no `wallIndex` is written into canonical surface resume;
- reopen initially remains at Plan;
- stable resume is applied only after canonical workspace materialization;
- missing/deleted/reowned edge fails closed to Plan.

Backward compatibility:

- schema v4 documents may still contain legacy `activeSurface.wallIndex`;
- v4 -> v5 migration never invents a `BoundaryEdgeId` from that ordinal;
- when such a legacy document enters canonical runtime without a stable resume, the old wall ordinal is discarded and the editor falls back to Plan;
- subsequent canonical saves use the stable v5 contract.

Primary implementation:

```text
lib/src/features/editor/canonical_room_surface_resume.dart
lib/src/features/editor/canonical_room_surface_runtime_registry.dart
lib/src/features/editor/editor_project_document.dart
lib/src/features/editor/project_schema_migrator.dart
```

#### Version-aware projection reconstruction

The runtime registry stores the exact canonical cutover coordinator, **not** a cached wall projection. Every stable wall resolve reads the current `session.project` and rebuilds the projection. Therefore a `LocalProjectVersion N -> N+1` transition cannot reuse an old `BoundaryEdgeId <-> ordinal` mapping as authoritative state.

Qualification includes a real P3 version transition through Project North editing and verifies that a fresh adapter is produced while the stable `BoundaryEdgeId` selection remains coherent.

Qualification completed on code HEAD `c657b707ef1819cca96699705958858ae10d643a`:

```text
dart format gate           PASS
flutter analyze            PASS
flutter full test          PASS
macOS analyze              PASS
macOS full test            PASS
macOS debug build          PASS
runtime path_provider      PASS
```

#### P7A-4.5 — canonical topology edit path

**CORE IMPLEMENTED + HARDENED + QUALIFIED; production history/undo closure remains.**

Application contract:

```text
begin(spaceId, expectedVersion N)
        |
        v
preview stable vertex/edge edit
        |
        v
validate topology + geometry + minimum edge length
        |
        v
BoundaryTopologyChangeSet / preserved lineage
        |
        v
compare current version == N
        |
        v
ProjectMutationSession.commit
        |
        v
version N+1 + ProjectChangeSet + UndoRecord
```

Production cutover path:

```text
mouse / touch / stylus drag
keyboard / external-wall gizmo
        |
        v
legacy MmPolygon preview candidate
        |
        v
classify exact single vertex or parallel edge edit
        |
        v
version-aware BoundaryEdgeId projection
        |
        v
CanonicalBoundaryTopologyEditSession
        |
        v
canonical P3 commit
        |
        v
legacy canvas rematerialization
```

Implemented:

- new `ProjectBoundaryTopologyEditingPort` backed by the same `ProjectMutationSession` as structure authoring, Project North and P6 semantics;
- one canonical transaction lifecycle: `begin -> preview -> validate -> commit/cancel`;
- vertex editing addresses the outgoing stable `BoundaryEdgeId`, not a durable vertex/wall ordinal;
- edge-normal editing addresses exact `BoundaryEdgeId`;
- stale `expectedVersion` fails before authoritative mutation;
- topology continuity/closure and `BoundaryGeometryIntegrity` are revalidated for every preview;
- minimum 300 mm edge-length guard remains enforced before commit;
- successful geometry commit increments canonical version exactly once and creates one canonical undo record;
- unchanged/cancelled preview leaves canonical state and undo depth unchanged;
- existing mouse/touch/stylus drag and keyboard/gizmo paths converge at `commitSelectedBoundary(...)`, which now becomes a canonical gateway whenever canonical runtime is attached;
- canonical runtime never falls back to direct legacy polygon mutation if the stable edit cannot be proven;
- legacy-only workspaces keep the transitional direct geometry path until their cutover;
- successful canonical commit is followed by exact legacy materialization, and materialization failure after commit is treated as an invariant violation.

P7A-5 boundary is intentionally strict:

- P7A-4.5 commits only topology-preserving geometry edits with preserved edge identities;
- split/merge/create/remove identity changes are rejected until hosted-object migration is available;
- a wall edit is blocked when it affects legacy `wallProfiles`, openings, wall-hosted components or cable/route segments;
- floor/ceiling hosted engineering geometry in the edited room is conservatively blocked because room footprint changes can invalidate it;
- shared/internal wall edits are blocked rather than silently propagating only the legacy polygon and diverging from canonical neighboring topology.

Primary implementation:

```text
lib/src/application/project/project_boundary_topology_editing.dart
lib/src/application/project/project_structure_authoring.dart
lib/src/features/editor/canonical_boundary_topology_editing_runtime.dart
lib/src/features/editor/canonical_room_surface_runtime_registry.dart
lib/src/features/editor/plan_geometry_editor_actions.dart
```

Qualification:

```text
test/p7a45_canonical_topology_editing_test.dart
test/p7a45_production_topology_editing_test.dart
```

Qualified code HEAD `6598afba591322bb078699e54f0746bed54911ef`:

```text
dart format gate           PASS
flutter analyze            PASS
flutter full test          PASS
macOS analyze              PASS
macOS full test            PASS
macOS debug build          PASS
runtime path_provider      PASS
```

##### Remaining P7A-4.5 closure

The canonical mutation engine already owns the correct `UndoRecord`, but the current production toolbar still invokes the legacy/P2 `undo/redo` controls. Before P7A-4.5 is marked completely DONE, production history must consume the shared canonical mutation timeline and rematerialize the restored canonical boundary after undo/redo. This must be solved as one document-history contract; blindly wiring all canonical undo into the existing P2 toolbar would mix unrelated structural, metadata, semantic and electrical histories incorrectly.

A production topology commit also needs an explicit ownership/publication boundary equivalent to the existing Project North/P6 production callbacks before canonical persistence ownership is considered fully cut over.

## Safety invariants

Durable navigation/resume/edit wall identity is never:

```text
wallIndex
array position
UI label W1/W2/W3
screen position
pointer id
```

It is:

```text
BoundaryEdgeId
```

For canonical room-surface navigation/resume/editing, `wallIndex` now exists only as a transient compatibility/presentation ordinal at the legacy canvas boundary.

This statement does **not** claim that every legacy wall-index reference in the repository has been removed. Hosted engineering objects remain P7A-5 work:

```text
ArchitecturalOpening.hostWall
EngineeringSpace.wallProfiles
wall-hosted components
cable endpoints
route anchors
```

Those hosts must migrate under explicit lineage/remap rules; P7A-4 does not silently reinterpret their ordinals as stable identity.

## Qualification coverage

Primary P7A-4 tests include:

```text
test/p7a4_canonical_room_boundary_projection_test.dart
test/p7a4_canonical_room_surface_selection_test.dart
test/p7a4_canonical_room_surface_cutover_test.dart
test/p7a4_projection_geometry_guard_test.dart
test/room_surface_navigator_production_wiring_test.dart
test/p7a4_stable_surface_resume_test.dart
test/p7a45_canonical_topology_editing_test.dart
test/p7a45_production_topology_editing_test.dart
```

The hardened matrix covers:

- exact stable edge selection;
- stale geometry/materialization;
- real out-of-range legacy ordinal;
- Building/Level/Space ownership mismatch;
- mouse/touch/button and keyboard stable-ID navigation;
- non-dirty surface navigation;
- schema-v5 stable resume serialization;
- save -> JSON -> close -> reopen -> canonical materialization;
- missing stable resume edge -> Plan;
- schema-v4 ordinal migration without identity invention;
- projection reconstruction after canonical project version change;
- stable vertex and edge geometry editing;
- stale topology-edit session rejection;
- invalid/short geometry rejection before commit;
- one canonical version increment and undo boundary;
- canonical commit followed by legacy rematerialization;
- host-dependent edit blocking until P7A-5;
- legacy-only geometry compatibility path.

## Remaining P7A slices

```text
P7A-1 domain foundation                 DONE + HARDENED
P7A-2 canonical aggregate ownership     DONE + HARDENED
P7A-3 persistence foundation            DONE + HARDENED
P7A-3 full legacy project migration     BLOCKED ON LOSSLESS DOMAIN COVERAGE
P7A-4.1 strict wall projection          DONE + HARDENED
P7A-4.2 stable selection adapter        DONE + HARDENED
P7A-4.3 production cutover resolver     DONE + HARDENED
P7A-4.4 Room Surface Navigator wiring   DONE + HARDENED + QUALIFIED
P7A-4 stable surface resume             DONE + HARDENED + QUALIFIED
P7A-4.5 topology edit core              IMPLEMENTED + HARDENED + QUALIFIED
P7A-4.5 production history/ownership    NEXT
P7A-5 hosted-object migration           PENDING
P7A-6 full hardening/qualification      PENDING
```

## Boundary with later stages

Not part of P7A:

- P7B vertical topology;
- P7C typical-floor lineage;
- P8 Wizard/generation;
- Windows/Linux/Android/iOS/iPadOS runner setup.

Pending platform runners do not alter P7A semantics. Boundary identity, projection, resume and mutation rules remain platform-independent across macOS, Windows, Linux, Android, iOS and iPadOS.

## Next implementation target

Close **P7A-4.5 production history/ownership** before entering P7A-5:

1. extend the production document-history contract to represent canonical P3 commits alongside legacy electrical history without creating two competing undo timelines;
2. route canonical topology undo/redo through the same expected-version rules and restore the exact stable `BoundaryEdgeId` topology;
3. rematerialize the legacy room polygon from restored canonical topology after undo/redo;
4. suppress duplicate legacy architecture-history entries caused only by canonical rematerialization;
5. add an explicit production topology-commit ownership callback/publication boundary for canonical persistence;
6. qualify chronology: topology edit -> electrical edit -> topology edit -> undo/redo in exact document order;
7. only after this closure begin **P7A-5 hosted-object migration**, then enable split/merge/create/remove lineage with atomic host remap.
