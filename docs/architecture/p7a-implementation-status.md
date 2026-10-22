# P7A Stable Boundary Topology — implementation status

Branch: `feat/project-structure-authoring`

## Current status

**P7A: IN PROGRESS.**

P7A-1 domain foundation, P7A-2 canonical aggregate ownership and P7A-3 persistence are **DONE + HARDENED**. P7A-4 production editor cutover is now in progress: the strict canonical-to-legacy wall projection, stable `BoundaryEdgeId` selection adapter and production cutover resolver are implemented and Flutter-qualified. The existing Room Surface Navigator is not yet switched to those adapters, so P7A-4 is not marked complete.

## Landed

### P7A-1 domain foundation

Implemented:

- stable `BoundaryEdgeId` is the durable edge identity;
- platform-independent `BoundaryPointMm`;
- canonical `ProjectBoundaryEdge` scoped to exact `SpaceId`;
- ordered `SpaceBoundaryTopology` for one exterior loop;
- topology validation for ownership, continuity and closure;
- explicit edge lineage: `preserved`, `split`, `merged`, `created`, `removed`;
- fail-closed host remap decisions;
- duplicate source/result lineage rejection.

Primary implementation:

```text
lib/src/domain/boundary_topology.dart
```

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

- canonical document schema v4;
- exact `BoundaryEdgeId`, ordered membership and millimetre geometry persistence;
- durable `BoundaryEdgeIdentityRegistry` including tombstones;
- ownership survives commit -> undo/remove -> save -> close -> reopen;
- persistence is strict validation, not an identity mutation mechanism;
- save rejects active edges missing from the durable ledger or owned by another Space;
- canonical v1/v2/v3 migrate to v4 without inventing P7A topology;
- deterministic legacy polygon migration produces fixed-width opaque identities;
- deterministic migration seed uses unambiguous length-prefixed components;
- `BoundaryGeometryIntegrity` rejects zero-area, self-intersecting and overlapping/backtracking loops;
- corrupt schema-v4 geometry fails closed;
- no platform-specific topology/persistence forks.

Primary implementation:

```text
lib/src/domain/boundary_edge_identity_registry.dart
lib/src/domain/boundary_geometry_integrity.dart
lib/src/application/project/project_mutation.dart
lib/src/application/project/project_snapshot.dart
lib/src/serialization/project/canonical_project_document_codec.dart
lib/src/serialization/project/legacy_boundary_polygon_migration.dart
```

Qualification completed on hardened P7A-3 code HEAD `9632002a5e61deb68b179333d26430d5d8528df6`:

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

**IN PROGRESS.**

#### P7A-4.1 — strict canonical boundary projection

Implemented:

- `CanonicalRoomBoundaryProjection`;
- `CanonicalEditorWallProjection`;
- `BoundaryEdgeId <-> transient wall ordinal` lookup;
- exact canonical/legacy ordered geometry validation;
- >4-wall rooms supported;
- reordered/stale geometry fails closed;
- invalid canonical topology fails closed;
- invalid canonical geometry fails closed before entering editor cutover;
- no nearest-edge, label, rotation or direction guessing.

Primary implementation:

```text
lib/src/features/editor/canonical_room_boundary_projection.dart
```

#### P7A-4.2 — stable room-surface selection

Implemented:

- `CanonicalRoomSurfaceSelectionAdapter`;
- current legacy wall ordinal projects to stable `BoundaryEdgeId`;
- wall selection accepts `BoundaryEdgeId`;
- ordinal resolution happens only at `EditorController.showWall(int)` boundary;
- previous/next navigation rotates canonical `orderedEdgeIds`;
- unknown/stale edge id leaves editor state unchanged.

Primary implementation:

```text
lib/src/features/editor/canonical_room_surface_selection.dart
```

#### P7A-4.3 — production cutover resolver

Implemented:

- `CanonicalRoomSurfaceCutover.resolve(...)`;
- requires exact canonical Space;
- requires existing canonical P7A topology;
- requires explicit canonical -> legacy Space binding;
- requires exact selected legacy room;
- missing topology never falls back to durable wall-index semantics.

Primary implementation:

```text
lib/src/features/editor/canonical_room_surface_cutover.dart
```

Primary qualification:

```text
test/p7a4_canonical_room_boundary_projection_test.dart
test/p7a4_canonical_room_surface_selection_test.dart
test/p7a4_canonical_room_surface_cutover_test.dart
test/p7a4_projection_geometry_guard_test.dart
```

Flutter qualification on code HEAD `b4c58165910d4d349539911484c346886bde5e54`:

```text
dart format gate           PASS
flutter analyze            PASS
flutter test               PASS
```

macOS qualification for this exact P7A-4 code HEAD is tracked separately and must be green before the P7A-4 foundation is called fully qualified.

## Safety invariants

Durable wall identity is never:

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

P7A-4 compatibility boundary is explicit:

```text
BoundaryEdgeId
    |
    v
CanonicalRoomBoundaryProjection
    |
    v
transient wall ordinal
    |
    v
legacy EditorController.showWall(int)
```

The integer is discarded as identity immediately outside the legacy API call.

Hosted objects remain a separate P7A-5 concern:

```text
ArchitecturalOpening.hostWall
EngineeringSpace.wallProfiles
wall-hosted components
cable endpoints
route anchors
```

P7A-4 does not claim those hosts are migrated merely because navigation now has a stable-ID bridge.

## Remaining P7A slices

```text
P7A-1 domain foundation                 DONE + HARDENED
P7A-2 canonical aggregate ownership     DONE + HARDENED
P7A-3 persistence foundation            DONE + HARDENED
P7A-3 full legacy project migration     BLOCKED ON LOSSLESS DOMAIN COVERAGE
P7A-4.1 strict wall projection          IMPLEMENTED
P7A-4.2 stable selection adapter        IMPLEMENTED
P7A-4.3 production cutover resolver     IMPLEMENTED
P7A-4.4 Room Surface Navigator wiring   NEXT
P7A-4.5 canonical topology edit path    PENDING
P7A-5 hosted-object migration           PENDING
P7A-6 full hardening/qualification      PENDING
```

## Boundary with later stages

Not part of P7A:

- P7B vertical topology;
- P7C typical-floor lineage;
- P8 Wizard/generation;
- Windows/Linux/Android/iOS/iPadOS runner setup.

Pending platform runners do not block P7A development. Boundary identity, projection and mutation semantics remain platform-independent across macOS, Windows, Linux, Android, iOS and iPadOS.

## Next implementation target

Proceed with **P7A-4.4 Room Surface Navigator wiring**:

1. resolve the selected canonical room through `CanonicalRoomSurfaceCutover`;
2. make navigator wall targets carry `BoundaryEdgeId` rather than durable `wallIndex` meaning;
3. keep `W1`, `W2`, ... strictly presentation labels;
4. mouse/touch/keyboard wall navigation invokes the same stable-edge action;
5. stale/missing edge selection falls back to Plan;
6. surface navigation remains non-dirty;
7. do not migrate openings/wall profiles/routes until P7A-5 host-remap contracts are applied.
